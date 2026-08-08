let _portsConfigCache = null;

async function loadPortsConfig(repoRoot) {
  if (_portsConfigCache) return _portsConfigCache;

  await loadScript(repoRoot + "node_modules/json5/dist/index.min.js");

  const res = await fetch(repoRoot + "config/ports.json5");
  if (!res.ok) throw new Error(`HTTP ${res.status} loading ports.json5`);

  const raw = await res.text();
  _portsConfigCache = JSON5.parse(raw);
  return _portsConfigCache;
}

async function getPortConfigValue(repoRoot, path) {
  let ports;
  try {
    ports = await loadPortsConfig(repoRoot);
  } catch (err) {
    return { value: null, error: `failed to load ports.json5: ${err.message}` };
  }

  const keys = path.split(".");
  let current = ports;
  for (const key of keys) {
    if (!current || typeof current !== "object") {
      return { value: null, error: `path ${path} not found in ports config` };
    }
    current = current[key];
  }

  if (current === null || current === undefined) {
    return { value: null, error: `path ${path} is empty in ports config` };
  }

  return { value: current, error: null };
}
