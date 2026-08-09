function tierLabel(raw: number | string | undefined): number | string {
  if (!raw) return "?";
  const n = Number(raw);
  return Number.isFinite(n) ? n / 1000 : raw;
}

function userName(u: any): string {
  return (u && (u.name || u.login)) || "?";
}

export interface FormattedEvent {
  icon: string;
  label: string;
  user: string;
  detail: string;
  message?: string;
}

export const EVENT_MAP: Record<string, (d: any) => FormattedEvent> = {
  "Twitch.Follow": (d) => ({
    icon: "👾➕",
    label: "Twitch Follow",
    user: d.user_name || d.user_login || "?",
    detail: "",
  }),
  "Twitch.Sub": (d) => ({
    icon: "👾⭐",
    label: "Twitch Sub",
    user: userName(d.user),
    detail: `Tier ${tierLabel(d.sub_tier)}`,
  }),
  "Twitch.ReSub": (d) => ({
    icon: "👾🔁",
    label: "Twitch Resub",
    user: userName(d.user),
    message: d.text || "",
    detail: `Tier ${tierLabel(d.subTier)} · ${d.cumulativeMonths ?? "?"} months`,
  }),
  "Twitch.GiftSub": (d) => ({
    icon: "👾🎁",
    label: "Twitch Gift sub",
    user: userName(d.user),
    detail: `to ${userName(d.recipient)} · Tier ${tierLabel(d.subTier)} · ${d.durationMonths ?? "?"} months`,
  }),
  "Twitch.GiftBomb": (d) => ({
    icon: "👾🎉",
    label: "Twitch Gift bomb",
    user: d.isAnonymous ? "Anonymous" : userName(d.user),
    detail: `${d.gifts ?? "?"} subs · Tier ${tierLabel(d.subTier)}`,
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
