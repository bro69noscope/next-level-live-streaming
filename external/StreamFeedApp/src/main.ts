import { STREAMERBOT_INSTANCES, loadStreamerbotInstances } from "./config.js";
import { state, renderStatus, clearFeed } from "./render.js";
import { connectStreamerbotInstance } from "./ws-client.js";
import { loadHistoryIntoFeed } from "./history/history-loader.js";

(window as any).clearFeed = clearFeed;
(window as any).loadHistoryIntoFeed = loadHistoryIntoFeed;

document.getElementById("clearFeedBtn")!.onclick = () => {
  clearFeed();
};

async function init(): Promise<void> {
  await loadHistoryIntoFeed();

  const instances = await loadStreamerbotInstances();
  STREAMERBOT_INSTANCES.push(...instances);
  STREAMERBOT_INSTANCES.forEach((inst) => (state[inst.name] = "connecting"));
  renderStatus();
  STREAMERBOT_INSTANCES.forEach(connectStreamerbotInstance);
}

init();
