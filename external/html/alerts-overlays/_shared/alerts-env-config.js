function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("failed to load " + src));
    document.head.appendChild(script);
  });
}

function getWsPortForEnv(ports, env) {
  const envEntry = ports.streamerbot?.[env];
  if (!envEntry) {
    return {
      port: null,
      error: `no entry found at ports.streamerbot.${env} in ports.json5`,
    };
  }
  const port = envEntry.streamerbot_ws?.port;
  if (!port) {
    return {
      port: null,
      error: `ports.streamerbot.${env}.streamerbot_ws.port is missing in ports.json5`,
    };
  }
  return { port, error: null };
}

async function loadEnvOverrides() {
  const env = new URLSearchParams(window.location.search).get("env");
  if (!env) {
    const msg =
      "no ?env= param on this overlay's URL — refusing to guess a WS port";
    fatalOverlayError(msg);
    throw new Error(msg);
  }

  try {
    await loadScript(
      OVERLAY_CONFIG.REPO_ROOT + "node_modules/json5/dist/index.min.js",
    );
  } catch (err) {
    fatalOverlayError("failed to load json5 library: " + err.message);
    throw err;
  }

  try {
    const res = await fetch(OVERLAY_CONFIG.REPO_ROOT + "config/ports.json5");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const raw = await res.text();
    const ports = JSON5.parse(raw);
    const { port: wsPort, error } = getWsPortForEnv(ports, env);
    if (error) throw new Error(error);
    OVERLAY_CONFIG.WS_PORT = wsPort;
  } catch (err) {
    fatalOverlayError("failed to read/parse ports.json5: " + err.message);
    throw err;
  }
}
