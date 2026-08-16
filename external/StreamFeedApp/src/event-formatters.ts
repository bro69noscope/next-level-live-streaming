export interface FormattedEvent {
  icon: string;
  label: string;
  user: string;
  detail: string;
  message?: string;
}

function tierLabel(raw: string | undefined): string {
  return raw && raw.trim() !== "" ? raw : "GOD KNOWS HOW MANY";
}

export const EVENT_MAP: Record<string, (d: any) => FormattedEvent> = {
  "Twitch.follow": (d) => ({
    icon: "👾➕",
    label: "Twitch Follow",
    user: d.user || "?",
    detail: "",
  }),
  "Twitch.sub": (d) => ({
    icon: "👾⭐",
    label: "Twitch Sub",
    user: d.user || "?",
    detail: `Tier ${tierLabel(d.tier)}`,
  }),
  "Twitch.resub": (d) => ({
    icon: "👾🔁",
    label: "Twitch Resub",
    user: d.user || "?",
    message: d.message || "",
    detail: `Tier ${tierLabel(d.tier)} · ${d.months || "?"} months`,
  }),
  "Twitch.giftsub": (d) => ({
    icon: "👾🎁",
    label: "Twitch Gift sub",
    user: d.user || "?",
    detail: `to ${d.recipient || "?"} · Tier ${tierLabel(d.tier)}`,
  }),
  "Twitch.giftbomb": (d) => ({
    icon: "👾🎉",
    label: "Twitch Gift bomb",
    user: d.user || "?",
    detail: `${d.giftCount || "?"} subs · Tier ${tierLabel(d.tier)}`,
  }),

  "Kofi.kofitip": (d) => ({
    icon: "☕💵",
    label: "Ko-fi Tip",
    user: d.user || "?",
    message: d.message || "",
    detail: `${d.amount} ${d.currency}`,
  }),
  "Kofi.kofisub": (d) => ({
    icon: "☕⭐",
    label: "Ko-fi Sub",
    user: d.user || "?",
    message: d.message || "",
    detail: `${d.amount} ${d.currency}`,
  }),
  "Kofi.kofiresub": (d) => ({
    icon: "☕🔁",
    label: "Ko-fi Resub",
    user: d.user || "?",
    message: d.message || "",
    detail: `${d.amount} ${d.currency}`,
  }),
};
