function loadScript(src, callback) {
  const script = document.createElement("script");
  script.src = src;
  script.onload = () => callback(null);
  script.onerror = () => callback(new Error("failed to load " + src));
  document.head.appendChild(script);
}

function getWsPortForEnv(ports, env) {
  const entry = ports.streamerbot[env];
  return entry ? entry.streamerbot_ws.port : null;
}

function loadEnvOverrides(callback) {
  const env = new URLSearchParams(window.location.search).get("env");

  if (!env) {
    fatalOverlayError(
      "no ?env= param on this overlay's URL — refusing to guess a WS port",
    );
    callback();
    return;
  }

  loadScript(
    OVERLAY_CONFIG.REPO_ROOT + "node_modules/json5/dist/index.min.js",
    (err) => {
      if (err) {
        fatalOverlayError("failed to load json5 library: " + err.message);
        callback();
        return;
      }

      fetch(OVERLAY_CONFIG.REPO_ROOT + "config/ports.json5")
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.text();
        })
        .then((raw) => {
          const ports = JSON5.parse(raw);
          const wsPort = getWsPortForEnv(ports, env);
          if (!wsPort) {
            fatalOverlayError(
              `no ws port mapping for env "${env}" in ports.json5`,
            );
          }
          OVERLAY_CONFIG.WS_PORT = wsPort;
          callback();
        })
        .catch((err) => {
          fatalOverlayError("failed to read/parse ports.json5: " + err.message);
          callback();
        });
    },
  );
}
