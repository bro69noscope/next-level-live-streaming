let STREAMERBOT_INSTANCES = [];

const REPO_ROOT = "https://repo.local/";

async function loadStreamerbotInstances() {
  const envKeys = ["production", "ftp"];
  const instances = [];

  for (const envKey of envKeys) {
    const { value: port, error } = await getPortConfigValue(
      REPO_ROOT,
      `streamerbot.${envKey}.streamerbot_ws.port`,
    );
    if (error) {
      console.error(
        `StreamFeedApp: failed to load port for ${envKey}: ${error}`,
      );
      continue;
    }
    instances.push({ name: envKey, host: "127.0.0.1", port });
  }
  return instances;
}

const TWITCH_STREAMERBOT_EVENTS = ["Follow", "Sub", "ReSub", "GiftSub"];
const UNVERIFIED_STREAMERBOT_EVENTS = new Set(["Twitch.GiftBomb"]);

const feedEl = document.getElementById("feed");
const statusEl = document.getElementById("status");
const filtersEl = document.getElementById("filters");

const state = {};
let activeFilter = "all";

const twitchFollowToggle = {
  btn: document.getElementById("toggleTwitchFollowsBtn"),
  shown: true,
  labels: {
    whenShown: "Hide Follows",
    whenHidden: "Show Follows",
  },
};
