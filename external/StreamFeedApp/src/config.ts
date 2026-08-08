interface StreamerbotInstance {
  name: string;
  host: string;
  port: number;
}

let STREAMERBOT_INSTANCES: StreamerbotInstance[] = [];

const REPO_ROOT = "https://repo.local/";

async function loadStreamerbotInstances(): Promise<StreamerbotInstance[]> {
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

const TWITCH_STREAMERBOT_EVENTS = ["Follow", "Sub", "ReSub", "GiftSub"];
const UNVERIFIED_STREAMERBOT_EVENTS = new Set(["Twitch.GiftBomb"]);

const feedEl = document.getElementById("feed")!;
const statusEl = document.getElementById("status")!;
const filtersEl = document.getElementById("filters")!;

type ConnState = "connecting" | "connected" | "disconnected";
const state: Record<string, ConnState> = {};

let activeFilter = "all";

const twitchFollowToggle = {
  btn: document.getElementById("toggleTwitchFollowsBtn") as HTMLButtonElement,
  shown: true,
  labels: {
    whenShown: "Hide Follows",
    whenHidden: "Show Follows",
  },
};
