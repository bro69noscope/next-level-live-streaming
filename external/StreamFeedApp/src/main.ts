async function init(): Promise<void> {
  STREAMERBOT_INSTANCES = await loadStreamerbotInstances();
  STREAMERBOT_INSTANCES.forEach((inst) => (state[inst.name] = "connecting"));
  renderStatus();
  STREAMERBOT_INSTANCES.forEach(connectStreamerbotInstance);
}

init();
