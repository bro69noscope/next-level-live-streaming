import { getPortConfigValue } from "../../common/helpers/js/dist/get-ports.js";

export interface StreamerbotInstance {
  name: string;
  host: string;
  port: number;
}

export let STREAMERBOT_INSTANCES: StreamerbotInstance[] = [];

const REPO_ROOT = "https://repo.local/";

export async function loadStreamerbotInstances(): Promise<
  StreamerbotInstance[]
> {
  const envKeys = ["production", "ftp"];
  const instances: StreamerbotInstance[] = [];

  for (const envKey of envKeys) {
    const { value: port, error } = await getPortConfigValue(
      REPO_ROOT,
      `streamerbot.${envKey}.streamerbot_ws.port`,
    );
    if (error || port === null) {
      console.error(
        `StreamFeedApp: failed to load port for ${envKey}: ${error}`,
      );
      continue;
    }
    instances.push({ name: envKey, host: "127.0.0.1", port: port as number });
  }
  return instances;
}

export const TWITCH_STREAMERBOT_EVENTS = ["Follow", "Sub", "ReSub", "GiftSub"];
