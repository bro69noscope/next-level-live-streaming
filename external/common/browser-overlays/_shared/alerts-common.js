function createSoundElement(id, src) {
  const el = document.createElement("audio");
  el.id = id;
  el.src = src;
  el.preload = "auto";
  el.dataset.retries = "0";
  el.dataset.relSrc = src;
  el.dataset.origSrc = src;
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

  fetch(el.dataset.origSrc, { method: "HEAD", signal: controller.signal })
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
    console.log(
      `[overlay] ${ts()} sound check failed (${reason}), retrying (${retries + 1}/${OVERLAY_CONFIG.SOUND_RETRY_MAX}): ${relPath}`,
      el.src,
    );
    setTimeout(
      () => checkSoundAvailable(el),
      OVERLAY_CONFIG.SOUND_RETRY_DELAY_MS,
    );
  } else {
    console.log(
      `[overlay] ${ts()} sound permanently failed after ${retries} retries: ${relPath}`,
      el.src,
    );
    el.dataset.failed = "true";
  }
}

function createAlertOverlay(opts) {
  const { name, subscribedEvents, alerts } = opts;

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

  function onSoundEnded() {
    if (pendingMessage) {
      speak(pendingMessage);
      pendingMessage = null;
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
        console.log(
          `[${name}-overlay] ${ts()} audio "${evtName}" on ${el.dataset.relSrc} (currentTime=${el.currentTime.toFixed(2)})`,
        );
      });
    });

    el.addEventListener("ended", onSoundEnded);
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
    console.log(`[${name}-overlay] ${ts()} lock requested for`, item.kind);
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
        console.log(`[${name}-overlay] ${ts()} lock granted for`, item.kind);
        showAlert(item);
      }
    }
    window.addEventListener("message", onGrant);
    window.parent.postMessage({ type: "alert-lock-request", name }, "*");
  }

  function connect() {
    if (!OVERLAY_CONFIG.WS_PORT) {
      fatalOverlayError(
        `[${name}-overlay] no WS_PORT configured, refusing to connect`,
      );
      return;
    }
    const ws = new WebSocket(
      `ws://${OVERLAY_CONFIG.WS_HOST}:${OVERLAY_CONFIG.WS_PORT}${OVERLAY_CONFIG.WS_ENDPOINT}`,
    );

    ws.onopen = () => {
      console.log(
        `[${name}-overlay] ${ts()} connected to Streamer.bot, subscribing...`,
      );
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
      if (!payload || !subscribedEvents.includes(payload.event)) return; // not ours, let another overlay handle it

      queue.push(payload);
      processQueue();
    };

    ws.onclose = () => {
      console.log(`[${name}-overlay] ${ts()} disconnected, retrying in 3s`);
      setTimeout(connect, 3000);
    };

    ws.onerror = () => ws.close();
  }

  function processQueue() {
    if (playing || queue.length === 0) return;
    playing = true;
    const item = queue.shift();
    requestLockThenShow(item);
  }

  function showAlert(item) {
    userEl.textContent = item.user || "Someone";
    msgEl.textContent = item.message || "";

    const display = getAlertDisplay(item) || {};
    headlineText.textContent =
      display.headline || "triggered an alert I've improperly coded XD";
    let soundEl = display.soundEl || soundUnknownEl;

    alertBox.classList.add("show");

    if (soundEl.dataset.failed === "true" && soundEl !== soundErrorEl) {
      console.log(
        `[${name}-overlay] ${ts()} sound failed to load previously, using error sound instead: ${soundEl.dataset.relSrc}`,
        soundEl.src,
      );
      soundEl = soundErrorEl;
    }

    soundEl.currentTime = 0;
    console.log(
      `[${name}-overlay] ${ts()} play() called for`,
      soundEl.dataset.relSrc,
    );
    soundEl
      .play()
      .then(() =>
        console.log(
          `[${name}-overlay] ${ts()} play() resolved for`,
          soundEl.dataset.relSrc,
        ),
      )
      .catch((err) =>
        console.log(
          `[${name}-overlay] ${ts()} play() rejected for`,
          soundEl.dataset.relSrc,
          err.message,
        ),
      );
    pendingMessage = item.message || null;

    setTimeout(() => {
      alertBox.classList.remove("show");
      setTimeout(() => {
        playing = false;
        if (isEmbedded) {
          console.log(`[${name}-overlay] ${ts()} lock released for`, item.kind);
          window.parent.postMessage({ type: "alert-lock-release", name }, "*");
        }
        processQueue();
      }, 700);
    }, OVERLAY_CONFIG.ALERT_DISPLAY_MS);
  }

  function speak(text) {
    if (!("speechSynthesis" in window)) return;
    const utter = new SpeechSynthesisUtterance(text);
    utter.volume = OVERLAY_CONFIG.TTS_VOLUME;
    utter.rate = OVERLAY_CONFIG.TTS_RATE;
    window.speechSynthesis.speak(utter);
  }

  connect();
}
