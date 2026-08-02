function applyFilter() {
  document
    .querySelectorAll("#filters button[data-filter]")
    .forEach((b) =>
      b.classList.toggle("active", b.dataset.filter === activeFilter),
    );

  document.querySelectorAll(".entry").forEach((row) => {
    const instanceMismatch =
      activeFilter !== "all" && row.dataset.instance !== activeFilter;
    const followHidden = hideFollows && row.dataset.type === "Twitch.Follow";
    row.classList.toggle("hidden", instanceMismatch || followHidden);
  });
}

filtersEl.querySelectorAll("button[data-filter]").forEach((btn) => {
  btn.onclick = () => {
    activeFilter = btn.dataset.filter;
    applyFilter();
  };
});

document.getElementById("hideFollowsBtn").onclick = (e) => {
  hideFollows = !hideFollows;
  e.target.classList.toggle("active", hideFollows);
  applyFilter();
};

document.getElementById("toggleRawBtn").onclick = (e) => {
  document.body.classList.toggle("hide-raw");
  const showing = !document.body.classList.contains("hide-raw");
  e.target.classList.toggle("active", showing);
  e.target.textContent = showing ? "Hide JSON" : "Show JSON";
};
