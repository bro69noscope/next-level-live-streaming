import { STREAMERBOT_INSTANCES, StreamerbotInstance } from "./config.js";
import {
  activeSbotInstanceFilter,
  ENTRY_INSTANCE_ATTR,
  ENTRY_TYPE_ATTR,
  twitchFollowToggle,
} from "./filters.js";
import { EVENT_MAP, FormattedEvent } from "./event-formatters.js";
import { sendHistoryEntry, sendHistoryStatus } from "./history.js";
import { replayAlert } from "./replay.js";
import type { AlertStatus } from "@helpers/alert-status/alert-status.types.js";

export const statusEl = document.getElementById("status")!;
export const feedEl = document.getElementById("feed")!;

const ENTRY_ID_ATTR = "data-entry-id";
export const state: Record<string, ConnState> = {};
export const UNVERIFIED_STREAMERBOT_EVENTS = new Set(["Twitch.giftbomb"]);
export type ConnState = "connecting" | "connected" | "disconnected";

const entryTemplate = document.getElementById(
  "feed-entry-template",
) as HTMLTemplateElement;

export function clearFeed(): void {
  feedEl.innerHTML = "";
}

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
        type: "unverifiedEvent",
        payload: {
          eventType,
          instance: instanceName,
          data,
          loggedAt: new Date().toISOString(),
        },
      }),
    );
  }
}

function formatEntryTimestamp(ts?: string): string {
  const date = ts ? new Date(ts) : new Date();
  const now = new Date();

  const isToday =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();

  if (isToday) {
    return date.toLocaleTimeString();
  }

  const dayName = date.toLocaleDateString(undefined, { weekday: "short" });
  return `${dayName} ${date.toLocaleTimeString()}`;
}

const REPLAY_STATUS_CLASSES = {
  queued: "feed__entry--replay-queued",
  played: "feed__entry--replayed",
} as const;

function applyStatus(el: HTMLElement, status: AlertStatus): void {
  el.classList.add("feed__entry--missed");
  el.classList.toggle(REPLAY_STATUS_CLASSES.queued, status === "queued");
  el.classList.toggle(REPLAY_STATUS_CLASSES.played, status === "played");
}

export function setAlertStatus(
  inst: StreamerbotInstance,
  alert: { alertId?: string },
  status: AlertStatus,
): void {
  const entry = alert.alertId
    ? feedEl.querySelector<HTMLElement>(
        `.feed__entry[${ENTRY_ID_ATTR}="${CSS.escape(alert.alertId)}"]`,
      )
    : null;
  if (!entry) {
    console.debug(`[${inst.name}] no feed entry for ${status} alert`, alert);
    return;
  }

  applyStatus(entry, status);
  sendHistoryStatus(alert.alertId!, status);
}

export function addEntry(
  inst: StreamerbotInstance,
  eventType: string,
  data: any,
  options: {
    isReplay?: boolean;
    isReplayEcho?: boolean;
    timestamp?: string;
    status?: AlertStatus | null;
  } = {},
): void {
  const { isReplay = false, isReplayEcho = false, timestamp, status } = options;

  if (isReplayEcho) return;

  const id: string | undefined = data?.alertId;
  if (!id) {
    console.error(
      `[${inst.name}] ${eventType} has no alertId, dropping entry`,
      data,
    );
    return;
  }

  const mapper = EVENT_MAP[eventType];
  const mapped: FormattedEvent & { unknown?: boolean } = mapper
    ? mapper(data)
    : { icon: "❔", label: eventType, user: "", detail: "", unknown: true };

  if (mapped.unknown || UNVERIFIED_STREAMERBOT_EVENTS.has(eventType)) {
    logUnverified(eventType, inst.name, data);
  }

  if (!isReplay) {
    sendHistoryEntry({
      inst: inst.name,
      eventType,
      data,
      timestamp: new Date().toISOString(),
    });
  }

  const clone = entryTemplate.content.cloneNode(true) as DocumentFragment;
  const row = clone.querySelector(".feed__entry") as HTMLElement;

  const replayBtn = row.querySelector(
    ".feed__entry-replay",
  ) as HTMLButtonElement;

  if (eventType.startsWith("Kofi.") || eventType.startsWith("Twitch.")) {
    row.dataset.overlayPayload = JSON.stringify(data);
  } else {
    replayBtn.disabled = true;
    replayBtn.title = "replay not available for this entry";
  }

  replayBtn.onclick = () => {
    const raw = row.dataset.overlayPayload;
    if (!raw) return;
    replayAlert(inst.name, JSON.parse(raw));
  };

  row.className =
    "feed__entry" + (mapped.unknown ? " feed__entry--unknown" : "");
  row.setAttribute(ENTRY_ID_ATTR, id);
  row.setAttribute(ENTRY_INSTANCE_ATTR, inst.name);
  row.setAttribute(ENTRY_TYPE_ATTR, eventType);

  if (status) applyStatus(row, status);

  const instanceMismatch =
    activeSbotInstanceFilter !== "all" &&
    activeSbotInstanceFilter !== inst.name;

  const twitchFollowHidden =
    !twitchFollowToggle.shown &&
    row.getAttribute(ENTRY_TYPE_ATTR) === "Twitch.Follow";

  if (instanceMismatch || twitchFollowHidden) {
    row.classList.add("feed__entry--hidden");
  }

  (row.querySelector(".feed__entry-icon") as HTMLElement).textContent =
    mapped.icon;
  (row.querySelector(".feed__entry-instance") as HTMLElement).textContent =
    `[${inst.name}]`;
  (row.querySelector(".feed__entry-timestamp") as HTMLElement).textContent =
    formatEntryTimestamp(timestamp);
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
