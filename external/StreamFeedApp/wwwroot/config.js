// Streamer.bot instances to connect to. Add more entries here if you
// ever run a third instance -- nothing else needs to change.
const INSTANCES = [
  { name: "Production", host: "127.0.0.1", port: 52000 },
  { name: "Ftp", host: "127.0.0.1", port: 52001 },
];

// Subscribed Twitch event types. "Sub" fields are confirmed from a real
// payload. ReSub/GiftSub/Follow are confirmed too (see event-formatters.js
// comments). GiftBomb is still best-guess -- see UNVERIFIED_TYPES below.
const SUBSCRIBE_EVENTS = ["Follow", "Sub", "ReSub", "GiftSub", "GiftBomb"];

// Event types without a confirmed real payload yet. Entries logged to
// disk (via the WebView2 bridge) so a real occurrence isn't missed even
// if you're not watching the window when it fires.
const UNVERIFIED_TYPES = new Set(["Twitch.GiftBomb"]);

// Shared DOM refs, used across filters.js / render.js / websocket.js
const feedEl = document.getElementById("feed");
const statusEl = document.getElementById("status");
const filtersEl = document.getElementById("filters");

// Per-instance connection state, keyed by instance name
const state = {};
INSTANCES.forEach((inst) => (state[inst.name] = "connecting"));

// Filter state, mutated by filters.js, read by render.js
let activeFilter = "all";
let hideFollows = false;
