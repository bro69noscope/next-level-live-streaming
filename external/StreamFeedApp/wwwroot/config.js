const STREAMERBOT_INSTANCES = [
  { name: "Production", host: "127.0.0.1", port: 52000 },
  { name: "Ftp", host: "127.0.0.1", port: 52001 },
];

const TWITCH_SBOT_EVENTS = ["Follow", "Sub", "ReSub", "GiftSub"];
const UNVERIFIED_SBOT_EVENTS = new Set(["Twitch.GiftBomb"]);

// Shared DOM refs, used across filters.js / render.js / websocket.js
const feedEl = document.getElementById("feed");
const statusEl = document.getElementById("status");
const filtersEl = document.getElementById("filters");

const state = {};
STREAMERBOT_INSTANCES.forEach((inst) => (state[inst.name] = "connecting"));

let activeFilter = "all";

const twitchFollowToggle = {
  btn: document.getElementById("toggleTwitchFollowsBtn"),
  shown: true,
  labels: {
    whenShown: "Hide Follows", // click to hide follows
    whenHidden: "Show Follows", // click to reveal follows
  },
};
