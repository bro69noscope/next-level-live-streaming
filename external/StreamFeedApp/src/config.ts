import { getPortsConfig } from "https://repo.local/external/common/helpers/js/dist/get-ports/get-ports.js";

export const BUILTIN_STREAMERBOT_TWITCH_EVENTS = [
  "Follow",
  "Sub",
  "ReSub",
  "GiftSub",
  "GiftBomb",
];

export interface StreamerbotInstance {
  name: string;
  host: string;
  port: number;
}

export let STREAMERBOT_INSTANCES: StreamerbotInstance[] = [];

export async function loadStreamerbotInstances(): Promise<
  StreamerbotInstance[]
> {
  const envKeys = ["production", "ftp"] as const;
  const instances: StreamerbotInstance[] = [];

  let config;
  try {
    config = await getPortsConfig("https://repo.local/config/ports.json5");
  } catch (err) {
    console.error(
      `StreamFeedApp: failed to load ports.json5: ${(err as Error).message}`,
    );
    return instances;
  }

  for (const envKey of envKeys) {
    const envConfig = config.streamerbot[envKey];
    if (!envConfig) {
      console.error(`StreamFeedApp: no streamerbot config found for ${envKey}`);
      continue;
    }
    instances.push({
      name: envKey,
      host: envConfig.streamerbot_ws.host,
      port: envConfig.streamerbot_ws.port,
    });
  }

  return instances;
}
