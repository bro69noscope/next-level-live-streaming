function tierLabel(raw) {
  if (!raw) return "?";
  const n = Number(raw);
  return Number.isFinite(n) ? n / 1000 : raw;
}

function userName(u) {
  return (u && (u.name || u.login)) || "?";
}

// One formatter per event type. Each returns { icon, label, user, detail }.
// Unmapped/unknown types fall back to a raw-JSON dump in render.js so
// nothing is silently dropped while a type is still being verified.
const EVENT_MAP = {
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
