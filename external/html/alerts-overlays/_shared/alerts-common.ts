import { OVERLAY_CONFIG } from "./alerts-constants.js";
import { log, fatalOverlayError } from "./alerts-utils.js";

interface AlertItem {
  kind: string;
  event: string;
  user?: string;
  message?: string;
  tier?: number;
  months?: number;
  recipient?: string;
  giftCount?: number;
  amount?: number | string;
  currency?: string;
}

interface AlertDef {
  kind: string;
  sound: string;
  headline: (item: AlertItem) => string;
}

interface CreateAlertOverlayOptions {
  name: string;
  subscribedEvents: string[];
  alerts: AlertDef[];
  kindChance?: Record<string, number>;
}

interface StreamerBotMessage {
  event?: { source?: string; type?: string };
  data?: unknown;
}

function createSoundElement(id: string, src: string): HTMLAudioElement {
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

function checkSoundAvailable(el: HTMLAudioElement): void {
  const controller = new AbortController();
  const timeoutId = setTimeout(
    () => controller.abort(),
    OVERLAY_CONFIG.SOUND_CHECK_TIMEOUT_MS,
  );

  fetch(el.dataset.relSrc!, { method: "HEAD", signal: controller.signal })
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

function handleSoundCheckFailure(el: HTMLAudioElement, reason: string): void {
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

export function createAlertOverlay(opts: CreateAlertOverlayOptions): void {
  const { name, subscribedEvents, alerts, kindChance = {} } = opts;

  const alertsByKind = new Map<
    string,
    { soundEl: HTMLAudioElement; headline: (item: AlertItem) => string }
  >();
  const ownSounds: HTMLAudioElement[] = [];
  alerts.forEach((alert) => {
    const soundEl = createSoundElement(
      `alert-sound-${alert.kind}`,
      alert.sound,
    );
    ownSounds.push(soundEl);
    alertsByKind.set(alert.kind, { soundEl, headline: alert.headline });
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
  let pendingMessage: string | null = null;
  let onSpeechDone: (() => void) | null = null;
  let activeSoundEl: HTMLAudioElement | null = null;
  let activeFinish: ((delayMs?: number) => void) | null = null;

  function onSoundEnded(): void {
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

  function getAlertDisplay(
    item: AlertItem,
  ): { headline: string; soundEl: HTMLAudioElement } | null {
    const alertConfig = alertsByKind.get(item.kind);
    if (!alertConfig) return null;
    return {
      headline: alertConfig.headline(item),
      soundEl: alertConfig.soundEl,
    };
  }

  const alertBox = document.querySelector(".alert-box")!;
  const userEl = document.querySelector(".alert-box__username")!;
  const msgEl = document.querySelector(".alert-box__message")!;
  const headlineText = document.querySelector(".alert-box__headline-text")!;

  let queue: AlertItem[] = [];
  let playing = false;

  // no parent to broker a lock with — just show immediately in that case.
  const isEmbedded = window.parent !== window;

  function requestLockThenShow(item: AlertItem): void {
    log.debug("lock requested for", item.kind);
    if (!isEmbedded) {
      showAlert(item);
      return;
    }
    function checkLockGrant(evt: MessageEvent): void {
      if (
        evt.source === window.parent &&
        evt.data &&
        evt.data.type === "alert-lock-granted"
      ) {
        window.removeEventListener("message", checkLockGrant);
        log.debug("lock granted for", item.kind);
        showAlert(item);
      }
    }
    window.addEventListener("message", checkLockGrant);
    window.parent.postMessage({ type: "alert-lock-request", name }, "*");
  }

  function connect(): void {
    if (!OVERLAY_CONFIG.WS_PORT) {
      fatalOverlayError(`no WS_PORT configured, refusing to connect`);
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

    ws.onmessage = (evt: MessageEvent) => {
      let msg: StreamerBotMessage | undefined;
      try {
        msg = JSON.parse(evt.data);
      } catch (e) {
        log.warn(
          "Failed to parse WebSocket message:",
          evt.data,
          (e as Error).message,
        );
        return;
      }
      if (
        !msg ||
        !msg.event ||
        msg.event.source !== "General" ||
        msg.event.type !== "Custom"
      ) {
        log.debug("Ignoring non 'Custom'/'General' event:", msg?.event);
        return;
      }
      let payload: AlertItem | undefined;
      try {
        payload =
          typeof msg.data === "string"
            ? JSON.parse(msg.data)
            : (msg.data as AlertItem);
      } catch (e) {
        log.warn(
          "Failed to parse WebSocket message data:",
          msg.data,
          (e as Error).message,
        );
        return;
      }

      if (!payload) {
        log.debug("Ignoring payload with msg:", msg.data);
        return;
      }

      if (payload.event === "SkipCurrentAlert") {
        skipCurrentAlert();
        return;
      }

      if (!subscribedEvents.includes(payload.event)) {
        log.debug(
          `Ignoring event: ${payload.event}, not in subscribedEvents: ${subscribedEvents}`,
        );
        return;
      }

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

    ws.onclose = (evt: CloseEvent) => {
      const dur = 3000;
      log.info("WebSocket closed with code", evt.code, "reason", evt.reason);
      log.info("Trying reconnect in " + dur + "ms...");
      setTimeout(connect, dur);
    };

    ws.onerror = () => ws.close();
  }

  function processQueue(): void {
    if (playing || queue.length === 0) return;
    playing = true;
    const item = queue.shift()!;
    log.debug(
      `Processing alert:`,
      { kind: item.kind, event: item.event },
      `Queue remaining: ${queue.length}`,
      queue,
    );
    requestLockThenShow(item);
  }

  function skipCurrentAlert(): void {
    if (!playing || !activeFinish) return;
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

  window.skipCurrentAlert = skipCurrentAlert;

  function showAlert(item: AlertItem): void {
    userEl.textContent =
      item.user || "Some guy or gal (this shouldn't show, xd)";
    msgEl.textContent = item.message || "";

    const display = getAlertDisplay(item);
    headlineText.textContent =
      display?.headline || "triggered an alert I've improperly coded XD";
    let soundEl = display?.soundEl || soundUnknownEl;

    alertBox.classList.add("alert-box--show");

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

    function finish(delayMs?: number): void {
      if (hidden) return;
      hidden = true;
      activeSoundEl = null;
      activeFinish = null;
      alertBox.classList.remove("alert-box--show");
      setTimeout(() => {
        playing = false;
        if (isEmbedded) {
          log.debug("lock released for", item.kind);
          window.parent.postMessage({ type: "alert-lock-release", name }, "*");
        }
        processQueue();
      }, delayMs ?? 700);
    }

    function maybeHide(): void {
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
    }, OVERLAY_CONFIG.ALERT_BASE_DISPLAY_MS);
  }

  function speak(text: string): void {
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
