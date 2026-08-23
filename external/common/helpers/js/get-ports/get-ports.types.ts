export type Consumer = "obs" | "streamdeck" | "streamerbot";
export type ScopeKeys = Partial<Record<Consumer | "default", string>>;

export interface TokenBlock {
  token: string;
  scope_keys?: ScopeKeys;
}

export interface RepositoryResource {
  host: string;
  port: number;
  protocol: "websocket" | "http";
  base_url: string;
  served_paths?: Record<string, string>;
  tokens: Record<string, TokenBlock>;
}

export interface ObsServer {
  host: string;
  port: number;
  protocol: "websocket";
  token: string;
  scope_keys: ScopeKeys;
}

export interface SubprocessEntry {
  port: number;
  token: string;
}

export interface StreamerbotEnv {
  streamerbot_ws: SubprocessEntry & { host: string; protocol: "websocket" };
  streamerbot_http?: SubprocessEntry & { host: string; protocol: "websocket" };
  integrations: {
    streamdeck: SubprocessEntry & { host: string; protocol: "websocket" };
  };
}

export interface PortsConfig {
  repository: Record<string, RepositoryResource>;
  obs: Record<string, ObsServer>;
  streamerbot: Record<string, StreamerbotEnv>;
  subprocesses: Record<string, SubprocessEntry>;
}
