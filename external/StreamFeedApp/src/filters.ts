export let activeSbotInstanceFilter = "all";

const INSTANCE_FILTER_ATTR = "data-sbot-instance-filter";
export const ENTRY_INSTANCE_ATTR = "data-instance";
export const ENTRY_TYPE_ATTR = "data-type";

export const twitchFollowToggle = {
  btn: document.getElementById("toggleTwitchFollowsBtn") as HTMLButtonElement,
  shown: true,
  labels: {
    whenShown: "Hide Follows",
    whenHidden: "Show Follows",
  },
};

const filterBarEl = document.getElementById("streamFeedFilterBar")!;

export function applyTwitchFollowToggleState(): void {
  twitchFollowToggle.btn.classList.toggle(
    "filterBar__btn--active",
    twitchFollowToggle.shown,
  );
  twitchFollowToggle.btn.textContent = twitchFollowToggle.shown
    ? twitchFollowToggle.labels.whenShown
    : twitchFollowToggle.labels.whenHidden;
}

export function applyFilter(): void {
  document
    .querySelectorAll<HTMLButtonElement>(
      `#streamFeedFilterBar .filterBar__btn[${INSTANCE_FILTER_ATTR}]`,
    )
    .forEach((b) =>
      b.classList.toggle(
        "filterBar__btn--active",
        b.getAttribute(INSTANCE_FILTER_ATTR) === activeSbotInstanceFilter,
      ),
    );
  document.querySelectorAll<HTMLElement>(".feed__entry").forEach((row) => {
    const instanceMismatch =
      activeSbotInstanceFilter !== "all" &&
      row.getAttribute(ENTRY_INSTANCE_ATTR) !== activeSbotInstanceFilter;
    const twitchFollowHidden =
      !twitchFollowToggle.shown &&
      row.getAttribute(ENTRY_TYPE_ATTR) === "Twitch.Follow";
    row.classList.toggle(
      "feed__entry--hidden",
      instanceMismatch || twitchFollowHidden,
    );
  });
}

filterBarEl
  .querySelectorAll<HTMLButtonElement>(
    `.filterBar__btn[${INSTANCE_FILTER_ATTR}]`,
  )
  .forEach((btn) => {
    btn.onclick = () => {
      activeSbotInstanceFilter =
        btn.getAttribute(INSTANCE_FILTER_ATTR) ?? "all";
      applyFilter();
    };
  });

twitchFollowToggle.btn.onclick = () => {
  twitchFollowToggle.shown = !twitchFollowToggle.shown;
  applyFilter();
  applyTwitchFollowToggleState();
};

document.getElementById("toggleRawBtn")!.addEventListener("click", (e) => {
  document.body.classList.toggle("body--hide-raw");
  const showing = !document.body.classList.contains("body--hide-raw");
  const target = e.target as HTMLElement;
  target.classList.toggle("filterBar__btn--active", showing);
  target.textContent = showing ? "Hide JSON" : "Show JSON";
});

applyFilter();
applyTwitchFollowToggleState();
