import { OVERLAY_CONFIG } from "./alerts-constants.js";
import { fatalOverlayError } from "./alerts-utils.js";

const { getPortConfigValue } = await import("mounted_js_helpers/get-ports.js");

export async function loadEnvOverrides(): Promise<void> {
  const env = new URLSearchParams(window.location.search).get("env");
  if (!env) {
    const msg =
      "no ?env= param on this overlay's URL — refusing to guess a WS port";
    fatalOverlayError(msg);
  }

  const { value: wsPort, error } = await getPortConfigValue(
    OVERLAY_CONFIG.SITE_ROOT,
    `streamerbot.${env}.streamerbot_ws.port`,
  );
  if (error) {
    fatalOverlayError("failed to load ports.json5: " + error);
  }
  OVERLAY_CONFIG.WS_PORT = wsPort as number;
}
