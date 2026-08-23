import JSON5 from "json5";

export type PortLookupResult<T> =
  { value: T; error: null } | { value: null; error: string };

let _portsConfigCache: unknown | null = null;

async function loadPortsConfig(portsConfigUrl: string): Promise<unknown> {
  if (_portsConfigCache) return _portsConfigCache;
  const res = await fetch(portsConfigUrl);
  if (!res.ok) throw new Error(`HTTP ${res.status} loading ports.json5`);
  const raw = await res.text();
  _portsConfigCache = JSON5.parse(raw);
  return _portsConfigCache;
}

export async function getPortConfigValue(
  portsConfigUrl: string,
  path: string,
): Promise<PortLookupResult<unknown>> {
  let ports: unknown;
  try {
    ports = await loadPortsConfig(portsConfigUrl);
  } catch (err) {
    return {
      value: null,
      error: `failed to load ports.json5: ${(err as Error).message}`,
    };
  }
  const keys = path.split(".");
  let current: unknown = ports;
  for (const key of keys) {
    if (!current || typeof current !== "object") {
      return { value: null, error: `path ${path} not found in ports config` };
    }
    current = (current as Record<string, unknown>)[key];
  }
  if (current === null || current === undefined) {
    return { value: null, error: `path ${path} is empty in ports config` };
  }
  return { value: current, error: null };
}
