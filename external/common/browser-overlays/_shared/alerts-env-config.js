function loadEnvOverrides(callback) {
  const env = new URLSearchParams(window.location.search).get("env");

  if (!env) {
    console.log(
      "[alerts-env-config] no ?env= param on this overlay's URL, using alerts-constants.js's default WS_PORT",
    );
    callback();
    return;
  }

  loadScript(
    OVERLAY_CONFIG.REPO_ROOT + "node_modules/json5/dist/index.min.js",
    (err) => {
      if (err) {
        console.log(
          "[alerts-env-config] failed to load json5 library, using default WS_PORT:",
          err,
        );
        callback();
        return;
      }

      fetch(OVERLAY_CONFIG.REPO_ROOT + "config/ports.json5")
        .then((res) => res.text())
        .then((raw) => {
          const ports = JSON5.parse(raw);
          const wsPort = getWsPortForEnv(ports, env);
          if (wsPort) {
            OVERLAY_CONFIG.WS_PORT = wsPort;
          } else {
            console.log(
              `[alerts-env-config] no known ws port mapping for env "${env}", using default WS_PORT`,
            );
          }
          callback();
        })
        .catch((err) => {
          console.log(
            "[alerts-env-config] failed to read/parse ports.json5, using default WS_PORT:",
            err,
          );
          callback();
        });
    },
  );
}

function getWsPortForEnv(ports, env) {
  const entry = ports.streamerbot[env];
  return entry ? entry.streamerbot_ws.port : null;
}

function loadScript(src, callback) {
  const script = document.createElement("script");
  script.src = src;
  script.onload = () => callback(null);
  script.onerror = () => callback(new Error("failed to load " + src));
  document.head.appendChild(script);
}
