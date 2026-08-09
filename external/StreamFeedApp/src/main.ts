import { STREAMERBOT_INSTANCES, loadStreamerbotInstances } from "./config.js";
import { state, renderStatus } from "./render.js";
import { connectStreamerbotInstance } from "./ws-client.js";

async function init(): Promise<void> {
  const instances = await loadStreamerbotInstances();
  STREAMERBOT_INSTANCES.push(...instances);
  STREAMERBOT_INSTANCES.forEach((inst) => (state[inst.name] = "connecting"));
  renderStatus();
  STREAMERBOT_INSTANCES.forEach(connectStreamerbotInstance);
}

init();
