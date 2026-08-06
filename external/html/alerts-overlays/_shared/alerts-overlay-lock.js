const DEBUG = window.DEBUG_ALERT_LOCK === true || window.DEBUG_ALL === true;

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
      console.warn("[Alert Lock] Received message with no data", evt);
      return;
    }

    if (!data.type) {
      console.warn("[Alert Lock] Message missing type property", data);
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
      console.warn("[Alert Lock] Unknown message type:", data.type, data);
    }
  });

  function grantNext() {
    if (locked || waiting.length === 0) return;
    locked = true;
    const source = waiting.shift();
    source.postMessage({ type: "alert-lock-granted" }, "*");

    clearTimeout(lockTimeoutId);
    lockTimeoutId = setTimeout(() => {
      console.log(`"[alerts-overlay] ${ts()} lock timed out, auto-releasing"`);
      locked = false;
      grantNext();
    }, LOCK_TIMEOUT_MS);
  }
})();
