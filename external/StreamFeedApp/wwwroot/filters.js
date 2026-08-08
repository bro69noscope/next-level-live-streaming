function applyTwitchFollowToggleState() {
  twitchFollowToggle.btn.classList.toggle("active", twitchFollowToggle.shown);
  twitchFollowToggle.btn.textContent = twitchFollowToggle.shown
    ? twitchFollowToggle.labels.whenShown
    : twitchFollowToggle.labels.whenHidden;
}

function applyFilter() {
  document
    .querySelectorAll("#filters button[data-filter]")
    .forEach((b) =>
      b.classList.toggle("active", b.dataset.filter === activeFilter),
    );
  document.querySelectorAll(".entry").forEach((row) => {
    const instanceMismatch =
      activeFilter !== "all" && row.dataset.instance !== activeFilter;
    const twitchFollowHidden =
      !twitchFollowToggle.shown && row.dataset.type === "Twitch.Follow";
    row.classList.toggle("hidden", instanceMismatch || twitchFollowHidden);
  });
}

filtersEl.querySelectorAll("button[data-filter]").forEach((btn) => {
  btn.onclick = () => {
    activeFilter = btn.dataset.filter;
    applyFilter();
  };
});

twitchFollowToggle.btn.onclick = () => {
  twitchFollowToggle.shown = !twitchFollowToggle.shown;
  applyTwitchFollowToggleState();
  applyFilter();
};

applyTwitchFollowToggleState(); // starts activated

document.getElementById("toggleRawBtn").onclick = (e) => {
  document.body.classList.toggle("hide-raw");
  const showing = !document.body.classList.contains("hide-raw");
  e.target.classList.toggle("active", showing);
  e.target.textContent = showing ? "Hide JSON" : "Show JSON";
};
