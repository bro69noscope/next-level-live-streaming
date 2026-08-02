function renderStatus() {
  statusEl.innerHTML = INSTANCES.map((inst) => {
    const s = state[inst.name];
    const cls = s === "connected" ? "ok" : "bad";
    return `<span class="${cls}">${inst.name}: ${s}</span>`;
  }).join("  ·  ");
}

function escapeHtml(s) {
  return String(s).replace(
    /[&<>"']/g,
    (c) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      })[c],
  );
}

// Forwards unverified/unknown event payloads to the C# host, which
// appends them to logs/unverified-events.log. See MainWindow.xaml.cs.
function logUnverified(eventType, instanceName, data) {
  if (window.chrome && window.chrome.webview) {
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

function addEntry(inst, eventType, data) {
  const mapper = EVENT_MAP[eventType];
  const mapped = mapper
    ? mapper(data)
    : { icon: "❔", label: eventType, user: "", detail: "", unknown: true };

  if (mapped.unknown || UNVERIFIED_TYPES.has(eventType)) {
    logUnverified(eventType, inst.name, data);
  }

  const row = document.createElement("div");
  row.className = "entry" + (mapped.unknown ? " unknown" : "");
  row.dataset.instance = inst.name;
  row.dataset.type = eventType;

  const instanceMismatch = activeFilter !== "all" && activeFilter !== inst.name;
  const followHidden = hideFollows && row.dataset.type === "Twitch.Follow";
  if (instanceMismatch || followHidden) {
    row.classList.add("hidden");
  }

  row.innerHTML = `
    <div class="icon">${mapped.icon}</div>
    <div>
      <div>
        <span style="color:#5b9dff">[${inst.name}]</span>
        ${new Date().toLocaleTimeString()} —
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
