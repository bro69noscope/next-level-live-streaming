export let activeFilter = "all";

export const twitchFollowToggle = {
  btn: document.getElementById("toggleTwitchFollowsBtn") as HTMLButtonElement,
  shown: true,
  labels: {
    whenShown: "Hide Follows",
    whenHidden: "Show Follows",
  },
};

const filtersEl = document.getElementById("filters")!;

export function applyTwitchFollowToggleState(): void {
  twitchFollowToggle.btn.classList.toggle(
    "filters__btn--active",
    twitchFollowToggle.shown,
  );
  twitchFollowToggle.btn.textContent = twitchFollowToggle.shown
    ? twitchFollowToggle.labels.whenShown
    : twitchFollowToggle.labels.whenHidden;
}

export function applyFilter(): void {
  document
    .querySelectorAll<HTMLButtonElement>("#filters .filters__btn[data-filter]")
    .forEach((b) =>
      b.classList.toggle(
        "filters__btn--active",
        b.dataset.filter === activeFilter,
      ),
    );
  document.querySelectorAll<HTMLElement>(".feed__entry").forEach((row) => {
    const instanceMismatch =
      activeFilter !== "all" && row.dataset.instance !== activeFilter;
    const twitchFollowHidden =
      !twitchFollowToggle.shown && row.dataset.type === "Twitch.Follow";
    row.classList.toggle(
      "feed__entry--hidden",
      instanceMismatch || twitchFollowHidden,
    );
  });
}

filtersEl
  .querySelectorAll<HTMLButtonElement>(".filters__btn[data-filter]")
  .forEach((btn) => {
    btn.onclick = () => {
      activeFilter = btn.dataset.filter ?? "all";
      applyFilter();
    };
  });

twitchFollowToggle.btn.onclick = () => {
  twitchFollowToggle.shown = !twitchFollowToggle.shown;
  applyTwitchFollowToggleState();
  applyFilter();
};

applyTwitchFollowToggleState(); // starts activated

document.getElementById("toggleRawBtn")!.addEventListener("click", (e) => {
  document.body.classList.toggle("body--hide-raw");
  const showing = !document.body.classList.contains("body--hide-raw");
  const target = e.target as HTMLElement;
  target.classList.toggle("filters__btn--active", showing);
  target.textContent = showing ? "Hide JSON" : "Show JSON";
});
