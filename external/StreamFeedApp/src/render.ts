function renderStatus(): void {
  statusEl.innerHTML = STREAMERBOT_INSTANCES.map((inst) => {
    const s = state[inst.name];
    const cls = s === "connected" ? "ok" : "bad";
    return `<span class="${cls}">${inst.name}: ${s}</span>`;
  }).join("  ·  ");
}

function escapeHtml(s: unknown): string {
  const map: Record<string, string> = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  };
  return String(s).replace(/[&<>"']/g, (c) => map[c]);
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

function addEntry(
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

  const row = document.createElement("div");
  row.className = "entry" + (mapped.unknown ? " unknown" : "");
  row.dataset.instance = inst.name;
  row.dataset.type = eventType;

  const instanceMismatch = activeFilter !== "all" && activeFilter !== inst.name;
  const twitchFollowHidden =
    !twitchFollowToggle.shown && row.dataset.type === "Twitch.Follow";
  if (instanceMismatch || twitchFollowHidden) {
    row.classList.add("hidden");
  }

  row.innerHTML = `
    <div class="icon">${mapped.icon}</div>
    <div>
      <div>
        <span class="instance">[${inst.name}]</span>
        <span class="timestamp">${new Date().toLocaleTimeString()}</span>
        <b>${escapeHtml(mapped.user || "?")}</b>
        <span class="label">${escapeHtml(mapped.label)}</span>
      </div>
      <div class="detail">${escapeHtml(mapped.detail || "")}</div>
      ${mapped.message ? `<div class="message">${escapeHtml(mapped.message)}</div>` : ""}
      <div class="raw">${escapeHtml(JSON.stringify(data))}</div>
    </div>
  `;
  feedEl.prepend(row);
}
