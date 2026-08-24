import { OVERLAY_CONFIG } from "./alerts-constants.js";
import { fatalOverlayError } from "./alerts-utils.js";

const { getPortsConfig } =
  await import("/mounted_js_helpers/get-ports/get-ports.js");

export async function loadEnvOverrides(): Promise<void> {
  const env = new URLSearchParams(window.location.search).get("env");
  if (!env) {
    fatalOverlayError(
      "no ?env= param on this overlay's URL — refusing to guess a WS port",
    );
  }

  let config;
  try {
    config = await getPortsConfig("/mounted_config/ports.json5");
  } catch (err) {
    fatalOverlayError("failed to load ports.json5: " + (err as Error).message);
  }

  const envConfig = config.streamerbot[env];
  if (!envConfig) {
    fatalOverlayError(`unknown env "${env}" — not found in streamerbot config`);
  }

  OVERLAY_CONFIG.WS_PORT = envConfig.streamerbot_ws.port;
}
