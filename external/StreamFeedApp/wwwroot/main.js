async function init() {
  STREAMERBOT_INSTANCES = await loadStreamerbotInstances();
  STREAMERBOT_INSTANCES.forEach((inst) => (state[inst.name] = "connecting"));
  renderStatus();
  STREAMERBOT_INSTANCES.forEach(connectSbotInstance);
}

init();
