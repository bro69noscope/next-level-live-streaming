import { STREAMERBOT_INSTANCES, StreamerbotInstance } from "./config.js";
import { activeFilter, twitchFollowToggle } from "./filters.js";
import { EVENT_MAP, FormattedEvent } from "./event-formatters.js";

export const statusEl = document.getElementById("status")!;
export const feedEl = document.getElementById("feed")!;
export const state: Record<string, ConnState> = {};
export const UNVERIFIED_STREAMERBOT_EVENTS = new Set(["Twitch.GiftBomb"]);
export type ConnState = "connecting" | "connected" | "disconnected";

const entryTemplate = document.getElementById(
  "feed-entry-template",
) as HTMLTemplateElement;

export function renderStatus(): void {
  statusEl.innerHTML = STREAMERBOT_INSTANCES.map((inst) => {
    const s = state[inst.name];
    const modifier =
      s === "connected" ? "status__item--ok" : "status__item--bad";
    return `<span class="status__item ${modifier}">${inst.name}: ${s}</span>`;
  }).join("  ·  ");
}

function logUnverified(
  eventType: string,
  instanceName: string,
  data: unknown,
): void {
  if (window.chrome?.webview) {
    window.chrome.webview.postMessage(
      JSON.stringify({
        eventType,
        instance: instanceName,
        data,
        loggedAt: new Date().toISOString(),
      }),
    );
  }
}

export function addEntry(
  inst: StreamerbotInstance,
  eventType: string,
  data: any,
): void {
  const mapper = EVENT_MAP[eventType];
  const mapped: FormattedEvent & { unknown?: boolean } = mapper
    ? mapper(data)
    : { icon: "❔", label: eventType, user: "", detail: "", unknown: true };

  if (mapped.unknown || UNVERIFIED_STREAMERBOT_EVENTS.has(eventType)) {
    logUnverified(eventType, inst.name, data);
  }

  const clone = entryTemplate.content.cloneNode(true) as DocumentFragment;
  const row = clone.querySelector(".feed__entry") as HTMLElement;

  row.className =
    "feed__entry" + (mapped.unknown ? " feed__entry--unknown" : "");
  row.dataset.instance = inst.name;
  row.dataset.type = eventType;

  const instanceMismatch = activeFilter !== "all" && activeFilter !== inst.name;
  const twitchFollowHidden =
    !twitchFollowToggle.shown && row.dataset.type === "Twitch.Follow";
  if (instanceMismatch || twitchFollowHidden) {
    row.classList.add("feed__entry--hidden");
  }

  (row.querySelector(".feed__entry-icon") as HTMLElement).textContent =
    mapped.icon;
  (row.querySelector(".feed__entry-instance") as HTMLElement).textContent =
    `[${inst.name}]`;
  (row.querySelector(".feed__entry-timestamp") as HTMLElement).textContent =
    new Date().toLocaleTimeString();
  (row.querySelector(".feed__entry-user") as HTMLElement).textContent =
    mapped.user || "?";
  (row.querySelector(".feed__entry-label") as HTMLElement).textContent =
    mapped.label;
  (row.querySelector(".feed__entry-detail") as HTMLElement).textContent =
    mapped.detail || "";
  (row.querySelector(".feed__entry-raw") as HTMLElement).textContent =
    JSON.stringify(data);

  const messageEl = row.querySelector(".feed__entry-message") as HTMLElement;
  if (mapped.message) {
    messageEl.textContent = mapped.message;
  } else {
    messageEl.remove();
  }

  feedEl.prepend(row);
}
