import { OVERLAY_CONFIG } from "./alerts-constants.js";
import { log } from "./alerts-utils.js";

const LOCK_TIMEOUT_MS = OVERLAY_CONFIG.LOCK_TIMEOUT_MS || 15000;

let locked = false;
let lockTimeoutId: ReturnType<typeof setTimeout> | undefined;
const waiting: MessageEventSource[] = [];

window.addEventListener("message", (evt: MessageEvent) => {
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
    if (!evt.source) {
      log.warn("Lock request with no message source", evt);
      return;
    }
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

function grantNext(): void {
  if (locked || waiting.length === 0) return;
  locked = true;
  const source = waiting.shift()!;
  source.postMessage({ type: "alert-lock-granted" }, { targetOrigin: "*" });

  clearTimeout(lockTimeoutId);
  lockTimeoutId = setTimeout(() => {
    log.info("Lock timed out, auto-releasing");
    locked = false;
    grantNext();
  }, LOCK_TIMEOUT_MS);
}
