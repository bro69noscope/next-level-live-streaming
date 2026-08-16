async function loadEnvOverrides() {
  const env = new URLSearchParams(window.location.search).get("env");
  if (!env) {
    const msg =
      "no ?env= param on this overlay's URL — refusing to guess a WS port";
    fatalOverlayError(msg);
    throw new Error(msg);
  }

  const { getPortConfigValue } = await import("/js_helpers/dist/get-ports.js");

  const { value: wsPort, error } = await getPortConfigValue(
    OVERLAY_CONFIG.REPO_ROOT,
    `streamerbot.${env}.streamerbot_ws.port`,
  );
  if (error) {
    fatalOverlayError("failed to load ports.json5: " + error);
    throw new Error(error);
  }
  OVERLAY_CONFIG.WS_PORT = wsPort;
}
