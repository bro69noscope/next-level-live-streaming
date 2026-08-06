const log = new Log();

(function () {
  const DEFAULT_LOCK_TIMEOUT_MS = 15000;
  const LOCK_TIMEOUT_MS =
    (typeof OVERLAY_CONFIG !== "undefined" && OVERLAY_CONFIG.LOCK_TIMEOUT_MS) ||
    DEFAULT_LOCK_TIMEOUT_MS;

  let locked = false;
  let lockTimeoutId = null;
  const waiting = [];

  window.addEventListener("message", (evt) => {
    const data = evt.data;

    if (!data) {
      log.warn("Received message with no data", evt);
      return;
    }

    if (!data.type) {
      log.warn("Message missing type property", data);
      return;
    }

    if (data.type === "alert-lock-request") {
      waiting.push(evt.source);
      grantNext();
    } else if (data.type === "alert-lock-release") {
      clearTimeout(lockTimeoutId);
      locked = false;
      grantNext();
    } else {
      log.warn("Unknown message type:", data.type, data);
    }
  });

  function grantNext() {
    if (locked || waiting.length === 0) return;
    locked = true;
    const source = waiting.shift();
    source.postMessage({ type: "alert-lock-granted" }, "*");

    clearTimeout(lockTimeoutId);
    lockTimeoutId = setTimeout(() => {
      log.info("Lock timed out, auto-releasing");
      locked = false;
      grantNext();
    }, LOCK_TIMEOUT_MS);
  }
})();
