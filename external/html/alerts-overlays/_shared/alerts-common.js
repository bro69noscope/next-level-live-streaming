const log = new Log();

function createSoundElement(id, src) {
  const el = document.createElement("audio");
  el.id = id;
  el.src = src;
  el.preload = "auto";
  el.dataset.retries = "0";
  el.dataset.relSrc = src;
  document.body.appendChild(el);
  checkSoundAvailable(el);
  return el;
}

function checkSoundAvailable(el) {
  const controller = new AbortController();
  const timeoutId = setTimeout(
    () => controller.abort(),
    OVERLAY_CONFIG.SOUND_CHECK_TIMEOUT_MS,
  );

  fetch(el.dataset.relSrc, { method: "HEAD", signal: controller.signal })
    .then((res) => {
      clearTimeout(timeoutId);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
    })
    .catch((err) => {
      clearTimeout(timeoutId);
      const reason = err.name === "AbortError" ? "timed out" : err.message;
      handleSoundCheckFailure(el, reason);
    });
}

function handleSoundCheckFailure(el, reason) {
  const retries = Number(el.dataset.retries);
  const relPath = el.dataset.relSrc;
  if (retries < OVERLAY_CONFIG.SOUND_RETRY_MAX) {
    el.dataset.retries = String(retries + 1);
    log.warn(
      `sound check failed (${reason}), retrying (${retries + 1}/${OVERLAY_CONFIG.SOUND_RETRY_MAX}): ${relPath}`,
      el.src,
    );
    setTimeout(
      () => checkSoundAvailable(el),
      OVERLAY_CONFIG.SOUND_RETRY_DELAY_MS,
    );
  } else {
    log.warn(
      `sound permanently failed after ${retries} retries: ${relPath}`,
      el.src,
    );
    el.dataset.failed = "true";
  }
}

function createAlertOverlay(opts) {
  const { name, subscribedEvents, alerts, kindChance = {} } = opts;

  const alertsByKind = new Map();
  const ownSounds = [];
  alerts.forEach((def) => {
    const soundEl = createSoundElement(`alert-sound-${def.kind}`, def.sound);
    ownSounds.push(soundEl);
    alertsByKind.set(def.kind, { soundEl, headline: def.headline });
  });

  const soundErrorEl = createSoundElement(
    "alert-sound-error",
    OVERLAY_CONFIG.SOUND_FILES.common.error,
  );
  const soundUnknownEl = createSoundElement(
    "alert-sound-unknown",
    OVERLAY_CONFIG.SOUND_FILES.common.unknown,
  );

  const allSounds = ownSounds.concat([soundErrorEl, soundUnknownEl]);
  let pendingMessage = null;
  let onSpeechDone = null;
  let activeSoundEl = null;
  let activeFinish = null;

  function onSoundEnded() {
    if (pendingMessage) {
      const text = pendingMessage;
      pendingMessage = null;
      speak(text);
    } else if (onSpeechDone) {
      const done = onSpeechDone;
      onSpeechDone = null;
      done();
    }
  }

  allSounds.forEach((el) => {
    el.volume = OVERLAY_CONFIG.SOUND_VOLUME;
    el.addEventListener("ended", onSoundEnded);
    [
      "play",
      "playing",
      "pause",
      "waiting",
      "stalled",
      "suspend",
      "abort",
    ].forEach((evtName) => {
      el.addEventListener(evtName, () => {
        log.debug(
          `audio "${evtName}" on ${el.dataset.relSrc} (currentTime=${el.currentTime.toFixed(2)})`,
        );
      });
    });
  });

  function getAlertDisplay(item) {
    const def = alertsByKind.get(item.kind);
    if (!def) return null; // unrecognized kind -> shared unknown fallback
    return { headline: def.headline(item), soundEl: def.soundEl };
  }

  const alertBox = document.getElementById("alert-box");
  const userEl = document.getElementById("alert-user");
  const msgEl = document.getElementById("alert-message");
  const headlineText = document.getElementById("headline-text");

  let queue = [];
  let playing = false;

  // If loaded standalone (not inside alerts-overlay.html's iframes), there's
  // no parent to broker a lock with — just show immediately in that case.
  const isEmbedded = window.parent !== window;

  function requestLockThenShow(item) {
    log.debug("lock requested for", item.kind);
    if (!isEmbedded) {
      showAlert(item);
      return;
    }
    function onGrant(evt) {
      if (
        evt.source === window.parent &&
        evt.data &&
        evt.data.type === "alert-lock-granted"
      ) {
        window.removeEventListener("message", onGrant);
        log.debug("lock granted for", item.kind);
        showAlert(item);
      }
    }
    window.addEventListener("message", onGrant);
    window.parent.postMessage({ type: "alert-lock-request", name }, "*");
  }

  function connect() {
    if (!OVERLAY_CONFIG.WS_PORT) {
      fatalOverlayError(`no WS_PORT configured, refusing to connect`);
      return;
    }
    const ws = new WebSocket(
      `ws://${OVERLAY_CONFIG.WS_HOST}:${OVERLAY_CONFIG.WS_PORT}${OVERLAY_CONFIG.WS_ENDPOINT}`,
    );

    ws.onopen = () => {
      log.info("connected to Streamer.bot, subscribing...");
      ws.send(
        JSON.stringify({
          request: "Subscribe",
          id: `${name}-alert-overlay`,
          events: { General: ["Custom"] },
        }),
      );
    };

    ws.onmessage = (evt) => {
      let msg;
      try {
        msg = JSON.parse(evt.data);
      } catch (e) {
        return; // not JSON, ignore
      }
      if (
        !msg.event ||
        msg.event.source !== "General" ||
        msg.event.type !== "Custom"
      ) {
        return;
      }
      let payload;
      try {
        payload =
          typeof msg.data === "string" ? JSON.parse(msg.data) : msg.data;
      } catch (e) {
        return;
      }

      if (!payload) return;

      if (payload.event === "SkipCurrentAlert") {
        skipCurrentAlert();
        return;
      }

      if (!subscribedEvents.includes(payload.event)) return; // not ours, let another overlay handle it
      log.debug(
        `Alert received:`,
        { kind: payload.kind, event: payload.event },
        payload,
      );

      const chance = payload.kind in kindChance ? kindChance[payload.kind] : 1;
      if (Math.random() >= chance) {
        log.info(`Dropped by chance roll (chance=${chance}):`, payload.kind);
        return;
      }

      queue.push(payload);
      log.debug(`Queued. Queue length: ${queue.length}`, queue);
      processQueue();
    };

    ws.onclose = () => {
      log.info("Disconnected, retrying in 3s");
      setTimeout(connect, 3000);
    };

    ws.onerror = () => ws.close();
  }

  function processQueue() {
    if (playing || queue.length === 0) return;
    playing = true;
    const item = queue.shift();
    log.debug(
      `Processing alert:`,
      { kind: item.kind, event: item.event },
      `Queue remaining: ${queue.length}`,
      queue,
    );
    requestLockThenShow(item);
  }

  function skipCurrentAlert() {
    if (!playing || !activeFinish) return; // nothing showing on this overlay right now
    log.info("Skip requested, stopping current alert");
    if ("speechSynthesis" in window) window.speechSynthesis.cancel();
    pendingMessage = null;
    onSpeechDone = null;
    if (activeSoundEl) {
      activeSoundEl.pause();
      activeSoundEl.currentTime = 0;
    }
    activeFinish(OVERLAY_CONFIG.SKIP_SILENCE_MS);
  }

  window.skipCurrentAlert = skipCurrentAlert; // manual trigger from devtools / a hotkey binding

  function showAlert(item) {
    userEl.textContent = item.user || "Some guy or gal";
    msgEl.textContent = item.message || "";

    const display = getAlertDisplay(item) || {};
    headlineText.textContent =
      display.headline || "triggered an alert I've improperly coded XD";
    let soundEl = display.soundEl || soundUnknownEl;

    alertBox.classList.add("show");

    if (soundEl.dataset.failed === "true" && soundEl !== soundErrorEl) {
      log.warn(
        `Sound failed to load previously, using error sound instead: ${soundEl.dataset.relSrc}`,
        soundEl.src,
      );
      soundEl = soundErrorEl;
    }

    soundEl.currentTime = 0;
    log.debug("play() called for", soundEl.dataset.relSrc);
    soundEl
      .play()
      .then(() => log.debug("play() resolved for", soundEl.dataset.relSrc))
      .catch((err) =>
        log.error("play() rejected for", soundEl.dataset.relSrc, err.message),
      );

    activeSoundEl = soundEl;
    pendingMessage = item.message || null;
    let ttsDone = false;
    let minTimeElapsed = false;
    let hidden = false;

    function finish(delayMs) {
      if (hidden) return;
      hidden = true;
      activeSoundEl = null;
      activeFinish = null;
      alertBox.classList.remove("show");
      setTimeout(() => {
        playing = false;
        if (isEmbedded) {
          log.debug("lock released for", item.kind);
          window.parent.postMessage({ type: "alert-lock-release", name }, "*");
        }
        processQueue();
      }, delayMs ?? 700);
    }

    function maybeHide() {
      if (!ttsDone || !minTimeElapsed) return;
      finish();
    }

    activeFinish = finish;

    onSpeechDone = () => {
      ttsDone = true;
      maybeHide();
    };

    setTimeout(() => {
      minTimeElapsed = true;
      maybeHide();
    }, OVERLAY_CONFIG.ALERT_DISPLAY_MS);
  }

  function speak(text) {
    if (!("speechSynthesis" in window)) {
      if (onSpeechDone) {
        const done = onSpeechDone;
        onSpeechDone = null;
        done();
      }
      return;
    }
    const utter = new SpeechSynthesisUtterance(text);
    utter.volume = OVERLAY_CONFIG.TTS_VOLUME;
    utter.rate = OVERLAY_CONFIG.TTS_RATE;
    utter.onend = () => {
      if (onSpeechDone) {
        const done = onSpeechDone;
        onSpeechDone = null;
        done();
      }
    };
    utter.onerror = utter.onend; // don't let a TTS error hang the lock
    window.speechSynthesis.speak(utter);
  }

  connect();
}
