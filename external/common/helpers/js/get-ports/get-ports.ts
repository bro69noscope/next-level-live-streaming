import JSON5 from "json5";
import type { PortsConfig } from "./get-ports.types.ts";

export type PortLookupResult<T> =
  { value: T; error: null } | { value: null; error: string };

let _portsConfigCache: PortsConfig | null = null;

export async function getPortsConfig(
  portsConfigUrl: string,
): Promise<PortsConfig> {
  if (_portsConfigCache) return _portsConfigCache;
  const res = await fetch(portsConfigUrl);
  if (!res.ok) throw new Error(`HTTP ${res.status} loading ports.json5`);
  const raw = await res.text();
  _portsConfigCache = JSON5.parse<PortsConfig>(raw);
  return _portsConfigCache;
}
