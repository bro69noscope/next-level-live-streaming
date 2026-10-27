export type AlertStatus = "missed" | "queued" | "played";

// Overlay -> StreamFeedApp, relayed by the "replay alert" streamerbot action.
export interface AlertStatusMessage<TAlert = unknown> {
  event: "AlertStatusChanged";
  status: AlertStatus;
  alert: TAlert;
}
