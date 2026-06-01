const state = {
  companions: [],
  selectedId: null,
  searchTimer: null,
};

const statsGrid = document.querySelector("#statsGrid");
const resultBox = document.querySelector("#resultBox");
const companionList = document.querySelector("#companionList");
const detailPanel = document.querySelector("#detailPanel");
const listCount = document.querySelector("#listCount");
const referenceGrid = document.querySelector("#referenceGrid");
const referencePath = document.querySelector("#referencePath");
const referenceInput = document.querySelector("#referenceInput");
const appSyncGrid = document.querySelector("#appSyncGrid");
const visualSessionsGrid = document.querySelector("#visualSessionsGrid");
const slackAssignmentGrid = document.querySelector("#slackAssignmentGrid");

const api = {
  async get(path) {
    const response = await fetch(path);
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || "Request failed");
    return payload;
  },
  async post(path, body = {}) {
    const response = await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || "Request failed");
    return payload;
  },
};

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function setResult(message, payload) {
  resultBox.textContent = payload ? `${message}\n${JSON.stringify(payload, null, 2)}` : message;
}

function formatNumber(value) {
  return Number(value || 0).toLocaleString();
}

async function loadStats() {
  const stats = await api.get("/api/stats");
  const starterReady = (stats.starter_generated || 0) + (stats.starter_reviewed || 0) + (stats.starter_approved || 0);
  const cards = [
    ["Starter", stats.starter_total],
    ["Complete", stats.starter_complete],
    ["Needs work", stats.starter_incomplete],
    ["Assigned", stats.starter_assigned],
    ["Existing chars", stats.starter_existing_characters],
    ["App cast", stats.app_character_count],
    ["Starter images", (stats.starter_cards || 0) + (stats.starter_photos || 0)],
    ["References", stats.reference_count],
    ["Visual sessions", stats.visual_session_count],
    ["Visual approved", stats.visual_approved_count],
    ["Slack tasks", stats.slack_assignment_count],
    ["Slack posted", stats.slack_posted_count],
  ];
  statsGrid.innerHTML = cards
    .map(([label, value]) => `<div class="stat-card"><span>${label}</span><strong>${formatNumber(value)}</strong></div>`)
    .join("");
}

function slackAssignmentCard(assignment) {
  const target = assignment.slack_target || "missing target";
  const latest = assignment.latest_reply_text ? `<p>${escapeHtml(assignment.latest_reply_text)}</p>` : "";
  const error = assignment.error ? `<p class="error-text">${escapeHtml(assignment.error)}</p>` : "";
  return `
    <div class="slack-assignment-card">
      <div>
        <strong>${escapeHtml(assignment.delegate_name)}</strong>
        <span>${escapeHtml(target)} · ${assignment.companion_ids?.length || 0} companions</span>
      </div>
      <span class="status-pill ${escapeHtml(assignment.status)}">${escapeHtml(assignment.status)}</span>
      ${latest}
      ${error}
    </div>
  `;
}

async function loadSlackAssignments() {
  if (!slackAssignmentGrid) return;
  const payload = await api.get("/api/slack-assignments?limit=8");
  slackAssignmentGrid.innerHTML = payload.items.length
    ? payload.items.map(slackAssignmentCard).join("")
    : `<div class="path-box">No Slack assignments yet. Draft or push assignments first.</div>`;
}

function visualSessionCard(session) {
  const archetype = String(session.archetype || "").replaceAll("_", " ");
  const level = Number(session.sensuality_level || 1);
  return `
    <div class="visual-session-card">
      <div>
        <strong>${escapeHtml(session.character_name)}</strong>
        <span>${escapeHtml(session.operator)} · ${escapeHtml(session.presentation)} · ${escapeHtml(session.age_read)}</span>
      </div>
      <p>${escapeHtml(archetype)} · sensuality ${level}/3 · ${escapeHtml(session.realism_target)}</p>
      <span class="status-pill ${escapeHtml(session.status)}">${escapeHtml(session.status)}</span>
    </div>
  `;
}

async function loadVisualSessions() {
  if (!visualSessionsGrid) return;
  const payload = await api.get("/api/visual-production/sessions?limit=8");
  visualSessionsGrid.innerHTML = payload.items.length
    ? payload.items.map(visualSessionCard).join("")
    : `<div class="path-box">No ChatGPT visual production sessions yet.</div>`;
}

function companionRow(companion) {
  const active = companion.id === state.selectedId ? "active" : "";
  const signs = `${companion.sun_sign} Sun / ${companion.moon_sign} Moon / ${companion.rising_sign} Rising`;
  const idLabel = companion.is_starter ? `S${String(companion.starter_rank).padStart(2, "0")}` : companion.id.replace("simastry-", "#");
  const workLabel = `${companion.photo_count}/${companion.target_photo_count || 10} img · ${companion.delegate_name || "unassigned"}`;
  return `
    <button class="companion-row ${active}" type="button" data-id="${companion.id}">
      <span class="id-pill">${idLabel}</span>
      <span class="identity">
        <strong>${escapeHtml(companion.display_name)}</strong>
        <span>${escapeHtml(signs)}</span>
      </span>
      <span class="asset-counts">${escapeHtml(workLabel)}</span>
      <span class="status-pill ${companion.status}">${companion.status}</span>
    </button>
  `;
}

async function loadCompanions() {
  const params = new URLSearchParams();
  const search = document.querySelector("#searchInput").value.trim();
  const scope = document.querySelector("#scopeFilter").value;
  const status = document.querySelector("#statusFilter").value;
  const gender = document.querySelector("#genderFilter").value;
  if (search) params.set("search", search);
  if (scope) params.set("scope", scope);
  if (status) params.set("status", status);
  if (gender) params.set("gender", gender);
  params.set("limit", "160");
  const payload = await api.get(`/api/companions?${params.toString()}`);
  state.companions = payload.items;
  listCount.textContent = scope === "starter" ? `${formatNumber(payload.total)} Starter 24 companions` : `${formatNumber(payload.total)} matching companions`;
  companionList.innerHTML = payload.items.map(companionRow).join("");
}

function detailTemplate(companion) {
  const signs = `${companion.sun_sign} Sun / ${companion.moon_sign} Moon / ${companion.rising_sign} Rising`;
  const phaseLabel = companion.is_starter ? `Starter 24 · ${companion.gender}` : companion.gender;
  const identityReferences = companion.identity_references || [];
  const identityGrid = identityReferences.length
    ? identityReferences
        .map(
          (item) => `
            <div class="reference-thumb">
              <img src="${item.url}" alt="${escapeHtml(item.name)}" />
              <span title="${escapeHtml(item.name)}">${escapeHtml(item.name)}</span>
            </div>
          `,
        )
        .join("")
    : `<div class="path-box">No character references yet.</div>`;
  return `
    <div class="detail-header">
      <div>
        <p class="eyebrow">${escapeHtml(phaseLabel)}</p>
        <h2>${escapeHtml(companion.display_name)}</h2>
        <p>${escapeHtml(signs)}</p>
      </div>
      <span class="status-pill ${companion.status}">${companion.status}</span>
    </div>

    <div class="meta-grid">
      <div><span>Pictures</span>${companion.photo_count}/${companion.target_photo_count || 10}</div>
      <div><span>Remaining</span>${companion.remaining_photo_count}</div>
      <div><span>Complete</span>${companion.is_complete ? "Yes" : "No"}</div>
    </div>

    <p class="section-label">Generation focus</p>
    <p>Realistic same-person photos for dating-app and Instagram-style use.</p>

    ${
      companion.app_character_name
        ? `
          <p class="section-label">Simastry app character</p>
          <div class="app-character-box">
            <strong>${escapeHtml(companion.app_character_name)}</strong>
            <span>${escapeHtml(companion.app_sources || "Synced from Simastry apps")} · ${companion.app_asset_count || 0} app assets · ${companion.app_astrogram_count || 0} Astrogram photos</span>
          </div>
        `
        : ""
    }

    <p class="section-label">Character references</p>
    <div class="identity-reference-controls">
      <label class="file-picker">
        Add pictures for this companion
        <input data-identity-input type="file" accept="image/*" multiple />
      </label>
      <button data-identity-upload type="button">Upload character references</button>
    </div>
    <div class="path-box">${escapeHtml(companion.identity_reference_dir)}</div>
    <div class="identity-reference-grid">${identityGrid}</div>

    <div class="production-form">
      <label>
        Character source
        <select data-production-field="character_source">
          <option value="existing_character" ${companion.character_source === "existing_character" ? "selected" : ""}>Existing character</option>
          <option value="generated_from_scratch" ${companion.character_source === "generated_from_scratch" ? "selected" : ""}>Generate from scratch</option>
        </select>
      </label>
      <label>
        Delegate
        <input data-production-field="delegate_name" value="${escapeHtml(companion.delegate_name || "")}" placeholder="Delegate name" />
      </label>
      <label>
        Slack handle or channel
        <input data-production-field="delegate_slack" value="${escapeHtml(companion.delegate_slack || "")}" placeholder="@name or #channel" />
      </label>
      <label>
        Target pictures
        <input data-production-field="target_photo_count" type="number" min="1" value="${companion.target_photo_count || 10}" />
      </label>
      <label class="wide-field">
        Cloud folder
        <input data-production-field="cloud_folder_path" value="${escapeHtml(companion.cloud_folder_path || "")}" />
      </label>
      <label class="wide-field">
        Existing character brief
        <textarea data-production-field="character_brief" rows="4" placeholder="Describe the already-known character, look, age range, styling rules, and any must-keep details.">${escapeHtml(companion.character_brief || "")}</textarea>
      </label>
      <button data-production-save type="button">Save assignment</button>
    </div>

    <p class="section-label">Folder</p>
    <div class="path-box">${escapeHtml(companion.folder_path)}</div>

    <div class="status-actions">
      <button data-status="todo" type="button">Todo</button>
      <button data-status="reviewed" type="button">Reviewed</button>
      <button data-status="approved" type="button">Approved</button>
      <button data-status="blocked" type="button">Blocked</button>
      <button data-status="generated" type="button">Generated</button>
      <button data-status="queued" type="button">Queued</button>
    </div>

    <p class="section-label">Core prompt</p>
    <div class="prompt-box">${escapeHtml(companion.prompt_core)}</div>
  `;
}

async function selectCompanion(id) {
  state.selectedId = id;
  companionList.querySelectorAll(".companion-row").forEach((row) => {
    row.classList.toggle("active", row.dataset.id === id);
  });
  const companion = await api.get(`/api/companions/${id}`);
  detailPanel.innerHTML = detailTemplate(companion);
}

async function seedCatalog() {
  setResult("Seeding catalog and folders…");
  const payload = await api.post("/api/seed");
  setResult("Catalog ready.", payload);
  await Promise.all([loadStats(), loadCompanions()]);
}

async function loadReferences() {
  const payload = await api.get("/api/references");
  referencePath.textContent = payload.directory;
  if (!payload.items.length) {
    referenceGrid.innerHTML = `<div class="path-box">No references uploaded yet.</div>`;
    return;
  }
  referenceGrid.innerHTML = payload.items
    .map(
      (item) => `
        <div class="reference-thumb">
          <img src="${item.url}" alt="${escapeHtml(item.name)}" />
          <span title="${escapeHtml(item.name)}">${escapeHtml(item.name)}</span>
        </div>
      `,
    )
    .join("");
}

async function loadAppCharacters() {
  const payload = await api.get("/api/app-characters");
  if (!payload.items.length) {
    appSyncGrid.innerHTML = `<div class="path-box">No app characters synced yet.</div>`;
    return;
  }
  appSyncGrid.innerHTML = payload.items
    .map((item) => {
      const companionLabel = item.factory_companions
        .map((companion) => `${companion.display_name} (${companion.gender})`)
        .join(", ");
      return `
        <div class="app-character-card">
          <span>${escapeHtml(item.sign)}</span>
          <strong>${escapeHtml(item.display_name)}</strong>
          <p>${escapeHtml(item.source_summary || "No source summary")} · ${item.existing_asset_count}/${item.asset_count} assets · ${item.astrogram_count} Astrogram</p>
          <small>${escapeHtml(companionLabel || "No Starter 24 match")}</small>
        </div>
      `;
    })
    .join("");
}

function readFileAsDataURL(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve({ name: file.name, type: file.type, data: reader.result });
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

async function uploadReferences() {
  const files = [...referenceInput.files];
  if (!files.length) {
    setResult("Choose one or more reference images first.");
    return;
  }
  setResult("Uploading reference images…");
  const encodedFiles = await Promise.all(files.map(readFileAsDataURL));
  const payload = await api.post("/api/references/upload", { files: encodedFiles });
  referenceInput.value = "";
  setResult("References uploaded.", payload);
  await Promise.all([loadReferences(), loadStats()]);
}

async function createBatch() {
  const scope = document.querySelector("#batchScope").value;
  const kind = document.querySelector("#batchKind").value;
  const status = document.querySelector("#batchStatus").value;
  const count = Number(document.querySelector("#batchCount").value || 24);
  setResult("Creating batch…");
  const payload = await api.post("/api/batches", { scope, kind, status, count });
  setResult("Batch created.", payload);
  await Promise.all([loadStats(), loadCompanions()]);
}

async function scanImports() {
  setResult("Scanning import and cloud folders…");
  const payload = await api.post("/api/imports/scan");
  setResult("Folder scan complete.", payload);
  await Promise.all([loadStats(), loadCompanions()]);
  if (state.selectedId) await selectCompanion(state.selectedId);
}

async function syncSimastryApps() {
  setResult("Scanning Simastry app characters…");
  const payload = await api.post("/api/simastry/sync");
  setResult("Simastry app sync complete.", payload);
  await Promise.all([loadStats(), loadCompanions(), loadAppCharacters()]);
  if (state.selectedId) await selectCompanion(state.selectedId);
}

async function buildLinearPlan() {
  setResult("Building Linear issue drafts…");
  const payload = await api.post("/api/linear/drafts");
  setResult("Linear issue drafts created.", payload);
}

async function generateDelegateTasks() {
  setResult("Creating Slack task drafts…");
  const payload = await api.post("/api/slack-tasks/generate");
  setResult("Slack task drafts created.", payload);
  await Promise.all([loadStats(), loadSlackAssignments()]);
}

async function pushSlackAssignments() {
  setResult("Pushing Slack assignments…");
  const payload = await api.post("/api/slack-assignments/push");
  setResult("Slack assignment push complete.", payload);
  await Promise.all([loadStats(), loadSlackAssignments()]);
}

async function monitorSlackAssignments() {
  setResult("Checking Slack assignment threads…");
  const payload = await api.post("/api/slack-assignments/monitor");
  setResult("Slack assignment monitor complete.", payload);
  await Promise.all([loadStats(), loadSlackAssignments()]);
}

async function uploadIdentityReferences() {
  if (!state.selectedId) return;
  const input = detailPanel.querySelector("[data-identity-input]");
  const files = [...(input?.files || [])];
  if (!files.length) {
    setResult("Choose one or more character reference pictures first.");
    return;
  }
  setResult("Uploading character references…");
  const encodedFiles = await Promise.all(files.map(readFileAsDataURL));
  const payload = await api.post(`/api/companions/${state.selectedId}/identity-references/upload`, { files: encodedFiles });
  if (input) input.value = "";
  detailPanel.innerHTML = detailTemplate(payload.companion);
  setResult("Character references uploaded.", payload);
  await Promise.all([loadStats(), loadCompanions()]);
}

async function saveProduction() {
  if (!state.selectedId) return;
  const payload = {};
  detailPanel.querySelectorAll("[data-production-field]").forEach((field) => {
    payload[field.dataset.productionField] = field.value;
  });
  setResult("Saving assignment…");
  const companion = await api.post(`/api/companions/${state.selectedId}/production`, payload);
  detailPanel.innerHTML = detailTemplate(companion);
  setResult("Assignment saved.");
  await Promise.all([loadStats(), loadCompanions()]);
}

function bindEvents() {
  document.querySelector("#seedBtn").addEventListener("click", () => seedCatalog().catch(showError));
  document.querySelector("#syncAppsBtn").addEventListener("click", () => syncSimastryApps().catch(showError));
  document.querySelector("#linearBtn").addEventListener("click", () => buildLinearPlan().catch(showError));
  document.querySelector("#batchBtn").addEventListener("click", () => createBatch().catch(showError));
  document.querySelector("#scanBtn").addEventListener("click", () => scanImports().catch(showError));
  document.querySelector("#taskBtn").addEventListener("click", () => generateDelegateTasks().catch(showError));
  document.querySelector("#pushSlackBtn").addEventListener("click", () => pushSlackAssignments().catch(showError));
  document.querySelector("#monitorSlackBtn").addEventListener("click", () => monitorSlackAssignments().catch(showError));
  document.querySelector("#uploadReferencesBtn").addEventListener("click", () => uploadReferences().catch(showError));

  companionList.addEventListener("click", (event) => {
    const row = event.target.closest(".companion-row");
    if (row) selectCompanion(row.dataset.id).catch(showError);
  });

  detailPanel.addEventListener("click", async (event) => {
    const identityUploadButton = event.target.closest("[data-identity-upload]");
    if (identityUploadButton) {
      await uploadIdentityReferences().catch(showError);
      return;
    }
    const productionButton = event.target.closest("[data-production-save]");
    if (productionButton) {
      await saveProduction().catch(showError);
      return;
    }
    const button = event.target.closest("[data-status]");
    if (!button || !state.selectedId) return;
    const companion = await api.post(`/api/companions/${state.selectedId}/status`, { status: button.dataset.status });
    detailPanel.innerHTML = detailTemplate(companion);
    await Promise.all([loadStats(), loadCompanions()]);
  });

  ["#scopeFilter", "#statusFilter", "#genderFilter"].forEach((selector) => {
    document.querySelector(selector).addEventListener("change", () => loadCompanions().catch(showError));
  });
  document.querySelector("#searchInput").addEventListener("input", () => {
    clearTimeout(state.searchTimer);
    state.searchTimer = setTimeout(() => loadCompanions().catch(showError), 180);
  });
}

function showError(error) {
  setResult(`Something needs attention: ${error.message}`);
}

async function init() {
  bindEvents();
  await Promise.all([loadStats(), loadCompanions(), loadReferences(), loadAppCharacters(), loadVisualSessions(), loadSlackAssignments()]);
  if (state.companions[0]) await selectCompanion(state.companions[0].id);
}

init().catch(showError);
