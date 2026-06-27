const state = {
  characters: [],
  filtered: [],
  selectedCharacter: null,
  selectedSlot: null,
  selectedCrop: { x: 50, y: 38, zoom: 1 },
};

const $ = (selector) => document.querySelector(selector);

const elements = {
  castList: $("#castList"),
  castCount: $("#castCount"),
  searchInput: $("#searchInput"),
  viewSelect: $("#viewSelect"),
  selectedName: $("#selectedName"),
  selectedSign: $("#selectedSign"),
  selectedMeta: $("#selectedMeta"),
  profileName: $("#profileName"),
  profileLine: $("#profileLine"),
  cardName: $("#cardName"),
  profilePreview: $("#profilePreview"),
  cardPreview: $("#cardPreview"),
  astrogramGrid: $("#astrogramGrid"),
  astrogramCount: $("#astrogramCount"),
  editorPreview: $("#editorPreview"),
  selectedSlot: $("#selectedSlot"),
  xControl: $("#xControl"),
  yControl: $("#yControl"),
  zoomControl: $("#zoomControl"),
  saveButton: $("#saveButton"),
  resetButton: $("#resetButton"),
  reloadButton: $("#reloadButton"),
  pushButton: $("#pushButton"),
  pushReport: $("#pushReport"),
  saveStatus: $("#saveStatus"),
  preflightCard: $("#preflightCard"),
  preflightBody: $("#preflightBody"),
  preflightRefreshButton: $("#preflightRefreshButton"),
};

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function normalizeSlotName(slot) {
  if (slot === "profile_avatar") return "Profile";
  if (slot === "card_portrait") return "Card";
  return slot.replace("astrogram_", "Post ");
}

function shapeForSlot(slot) {
  if (slot === "profile_avatar") return "avatar";
  if (slot === "card_portrait") return "card";
  return "square";
}

function cropStyle(crop) {
  const safe = crop || { x: 50, y: 38, zoom: 1 };
  return `--crop-x:${safe.x}%;--crop-y:${safe.y}%;--crop-zoom:${safe.zoom};`;
}

function compactPath(path) {
  const value = String(path || "");
  const marker = "/Codex/";
  const index = value.indexOf(marker);
  return index >= 0 ? `...${value.slice(index)}` : value || "-";
}

function slotByName(character, slotName) {
  return character?.slots.find((slot) => slot.slot === slotName);
}

function setStatus(message) {
  elements.saveStatus.textContent = message;
}

async function loadData() {
  setStatus("Loading");
  const response = await fetch("/api/app-preview", { cache: "no-store" });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error || "Could not load Factory");

  state.characters = payload.characters || [];
  applyFilters();
  renderPreflight(payload.preflight || {});

  if (state.selectedCharacter) {
    const stillExists = state.characters.find((item) => item.id === state.selectedCharacter.id);
    selectCharacter(stillExists ? stillExists.id : state.filtered[0]?.id);
  } else if (state.filtered.length) {
    selectCharacter(state.filtered[0].id);
  }
  setStatus("Ready");
}

async function loadPreflight() {
  elements.preflightBody.textContent = "Checking target...";
  try {
    const response = await fetch("/api/app-preview/preflight", { cache: "no-store" });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || "Could not check target");
    renderPreflight(payload);
    return payload;
  } catch (error) {
    elements.preflightCard.classList.add("is-warning");
    elements.preflightBody.innerHTML = `<div class="preflight-note">${escapeHtml(error.message)}</div>`;
    return null;
  }
}

function renderPreflight(payload) {
  const target = payload.target || {};
  const git = payload.git || {};
  const images = payload.images || {};
  const latest = payload.latest_push || {};
  const latestSummary = latest.summary || {};
  const ready = Number(images.ready || 0);
  const expected = Number(images.expected || 0);
  const missing = Number(images.missing || 0);
  const targetExists = Boolean(target.exists);
  const correctBranch = git.branch === "codex/testflight-bitrig-readiness";
  const correctCommit = String(git.commit || "").startsWith("a3aae7e");
  const isReady = targetExists && correctBranch && correctCommit && expected > 0 && ready === expected && missing === 0;

  elements.preflightCard.classList.toggle("is-ready", isReady);
  elements.preflightCard.classList.toggle("is-warning", !isReady);
  elements.preflightBody.innerHTML = `
    <div class="preflight-status">
      <span>${isReady ? "Ready" : "Needs review"}</span>
      <strong>${ready} / ${expected} images ready</strong>
    </div>
    <div class="preflight-grid">
      <div><span>Repo</span><strong>${escapeHtml(target.name || "-")}</strong></div>
      <div><span>Branch</span><strong>${escapeHtml(git.branch || "unknown")}</strong></div>
      <div><span>Commit</span><strong>${escapeHtml(`${git.commit || "unknown"} ${git.subject || ""}`.trim())}</strong></div>
      <div><span>Status</span><strong>${Number(git.dirty_count || 0)} local changes</strong></div>
      <div><span>Missing</span><strong>${missing}</strong></div>
      <div><span>Base</span><strong>${correctCommit ? "a3aae7e" : "check commit"}</strong></div>
    </div>
    <div class="preflight-path"><span>Asset catalog</span>${escapeHtml(compactPath(target.asset_catalog))}</div>
    ${latest.manifest_path ? `<div class="preflight-path"><span>Latest manifest</span>${escapeHtml(compactPath(latest.manifest_path))}</div>` : ""}
    ${latestSummary.exported !== undefined ? `<div class="preflight-path"><span>Last push</span>${Number(latestSummary.exported || 0)} exported · ${Number(latestSummary.changed || 0)} changed · ${Number(latestSummary.missing || 0)} missing</div>` : ""}
  `;
}

function applyFilters() {
  const query = elements.searchInput.value.trim().toLowerCase();
  state.filtered = state.characters.filter((character) => {
    const haystack = `${character.name} ${character.sign} ${character.app_key} ${character.city}`.toLowerCase();
    return !query || haystack.includes(query);
  });
  renderCast();
}

function renderCast() {
  elements.castCount.textContent = state.filtered.length;
  elements.castList.innerHTML = state.filtered.map((character) => {
    const active = character.id === state.selectedCharacter?.id ? "is-active" : "";
    const missing = character.missing?.length ? `${character.missing.length} missing` : "ready";
    return `
      <button class="cast-button ${active}" type="button" data-character="${escapeHtml(character.id)}">
        <div class="crop-frame avatar-frame" style="${cropStyle(character.thumbnail_crop)}">
          ${character.thumbnail ? `<img src="${character.thumbnail}" alt="">` : ""}
        </div>
        <div class="cast-meta">
          <strong>${escapeHtml(character.name)}</strong>
          <span>${escapeHtml(character.sign)} · ${escapeHtml(missing)}</span>
        </div>
      </button>
    `;
  }).join("");
}

function selectCharacter(id) {
  const character = state.characters.find((item) => item.id === id);
  if (!character) return;
  state.selectedCharacter = character;
  state.selectedSlot = null;
  renderCast();
  renderSelectedCharacter();
  const firstSlot = character.slots.find((slot) => !slot.missing);
  if (firstSlot) selectSlot(firstSlot.slot);
}

function renderSelectedCharacter() {
  const character = state.selectedCharacter;
  if (!character) return;

  const profile = slotByName(character, "profile_avatar");
  const card = slotByName(character, "card_portrait");
  const astrogram = character.slots.filter((slot) => slot.slot.startsWith("astrogram_") && !slot.missing);

  elements.selectedName.textContent = character.name;
  elements.selectedSign.textContent = character.sign;
  elements.selectedMeta.textContent = `${character.age} · ${character.city}`;
  elements.profileName.textContent = character.name;
  elements.profileLine.textContent = `${character.sign} AI Astrologist`;
  elements.cardName.textContent = character.name;
  renderFrame(elements.profilePreview, profile);
  renderFrame(elements.cardPreview, card);
  elements.astrogramCount.textContent = `${astrogram.length} / 10`;
  renderImageGrid();
}

function renderFrame(frame, slot) {
  if (!slot || slot.missing) {
    frame.innerHTML = "";
    frame.style.cssText = cropStyle({ x: 50, y: 38, zoom: 1 });
    return;
  }
  frame.style.cssText = cropStyle(slot.crop);
  frame.innerHTML = `<img src="${slot.url}" alt="">`;
}

function renderImageGrid() {
  const character = state.selectedCharacter;
  if (!character) return;
  const view = elements.viewSelect.value;
  let slots = character.slots.filter((slot) => slot.slot.startsWith("astrogram_"));
  if (view === "profile") slots = character.slots.filter((slot) => slot.slot === "profile_avatar");
  if (view === "card") slots = character.slots.filter((slot) => slot.slot === "card_portrait");
  if (view === "all") slots = character.slots;

  elements.astrogramGrid.innerHTML = slots.map((slot) => {
    if (slot.missing) {
      return `<div class="missing-tile">${escapeHtml(slot.label || normalizeSlotName(slot.slot))}</div>`;
    }
    const selected = slot.asset === state.selectedSlot?.asset ? "is-selected" : "";
    const shape = shapeForSlot(slot.slot);
    return `
      <button class="astrogram-tile ${selected} ${shape}-tile" type="button" data-slot="${escapeHtml(slot.slot)}">
        <div class="crop-frame" style="${cropStyle(slot.crop)}">
          <img src="${slot.url}" alt="">
        </div>
        <span class="slot-label">${escapeHtml(slot.label)}</span>
      </button>
    `;
  }).join("");
}

function selectSlot(slotName) {
  const slot = slotByName(state.selectedCharacter, slotName);
  if (!slot || slot.missing) return;
  state.selectedSlot = slot;
  state.selectedCrop = { ...slot.crop };
  syncControls();
  renderEditor();
  renderImageGrid();
}

function syncControls() {
  elements.xControl.value = state.selectedCrop.x;
  elements.yControl.value = state.selectedCrop.y;
  elements.zoomControl.value = state.selectedCrop.zoom;
}

function renderEditor() {
  const slot = state.selectedSlot;
  elements.selectedSlot.textContent = slot ? slot.label : "None";
  elements.editorPreview.className = "editor-preview";
  if (!slot) {
    elements.editorPreview.innerHTML = "";
    return;
  }
  const shape = shapeForSlot(slot.slot);
  if (shape === "avatar") elements.editorPreview.classList.add("avatar-mode");
  if (shape === "card") elements.editorPreview.classList.add("card-mode");
  elements.editorPreview.style.cssText = cropStyle(state.selectedCrop);
  elements.editorPreview.innerHTML = `<img src="${slot.url}" alt="">`;

  const activeTile = document.querySelector(`[data-slot="${slot.slot}"] .crop-frame`);
  if (activeTile) activeTile.style.cssText = cropStyle(state.selectedCrop);

  if (slot.slot === "profile_avatar") elements.profilePreview.style.cssText = cropStyle(state.selectedCrop);
  if (slot.slot === "card_portrait") elements.cardPreview.style.cssText = cropStyle(state.selectedCrop);
}

function updateCropFromControls() {
  state.selectedCrop = {
    x: Number(elements.xControl.value),
    y: Number(elements.yControl.value),
    zoom: Number(elements.zoomControl.value),
  };
  renderEditor();
}

async function saveCrop(options = {}) {
  if (!state.selectedSlot) return true;
  setStatus("Saving");
  const response = await fetch("/api/app-preview/crops", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      asset: state.selectedSlot.asset,
      slot: state.selectedSlot.slot,
      ...state.selectedCrop,
    }),
  });
  const payload = await response.json();
  if (!response.ok || !payload.ok) {
    setStatus("Save failed");
    if (options.throwOnError) throw new Error(payload.error || "Crop save failed");
    return false;
  }
  state.selectedSlot.crop = payload.crop;
  if (state.selectedSlot.slot === "profile_avatar") {
    state.selectedCharacter.thumbnail_crop = payload.crop;
  }
  setStatus("Saved");
  return true;
}

async function resetCrop() {
  if (!state.selectedSlot) return;
  setStatus("Resetting");
  await fetch("/api/app-preview/crops/reset", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ asset: state.selectedSlot.asset }),
  });
  const fallback = state.selectedSlot.slot === "profile_avatar"
    ? { x: 50, y: 34, zoom: 1 }
    : state.selectedSlot.slot === "card_portrait"
      ? { x: 50, y: 36, zoom: 1 }
      : { x: 50, y: 38, zoom: 1 };
  state.selectedCrop = fallback;
  state.selectedSlot.crop = fallback;
  syncControls();
  renderEditor();
  setStatus("Reset");
}

function renderPushReport(payload) {
  const summary = payload.summary || {};
  const missing = payload.missing || [];
  elements.pushReport.hidden = false;
  elements.pushReport.innerHTML = `
    <strong>iOS app assets updated</strong>
    <span>${Number(summary.exported || 0)} exported · ${Number(summary.changed || 0)} changed · ${Number(summary.missing || 0)} missing</span>
    <small>${escapeHtml(payload.manifest_path || "")}</small>
    ${missing.length ? `<em>${escapeHtml(missing.slice(0, 4).map((item) => `${item.character} ${item.slot}`).join(", "))}</em>` : ""}
  `;
}

async function pushToIosApp() {
  elements.pushButton.disabled = true;
  elements.pushReport.hidden = true;
  try {
    await loadPreflight();
    await saveCrop({ throwOnError: true });
    setStatus("Pushing to iOS app");
    const response = await fetch("/api/app-preview/push-to-ios-app", { method: "POST" });
    const payload = await response.json();
    if (!response.ok || !payload.ok) throw new Error(payload.error || "Push failed");
    renderPushReport(payload);
    await loadPreflight();
    setStatus(`Pushed ${payload.summary?.exported || 0} images`);
  } catch (error) {
    elements.pushReport.hidden = false;
    elements.pushReport.innerHTML = `<strong>Push failed</strong><span>${escapeHtml(error.message)}</span>`;
    setStatus("Push failed");
  } finally {
    elements.pushButton.disabled = false;
  }
}

elements.castList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-character]");
  if (button) selectCharacter(button.dataset.character);
});

elements.astrogramGrid.addEventListener("click", (event) => {
  const button = event.target.closest("[data-slot]");
  if (button) selectSlot(button.dataset.slot);
});

document.querySelectorAll("[data-preview-slot]").forEach((button) => {
  button.addEventListener("click", () => selectSlot(button.dataset.previewSlot));
});

for (const control of [elements.xControl, elements.yControl, elements.zoomControl]) {
  control.addEventListener("input", updateCropFromControls);
}

elements.searchInput.addEventListener("input", applyFilters);
elements.viewSelect.addEventListener("change", renderImageGrid);
elements.saveButton.addEventListener("click", saveCrop);
elements.resetButton.addEventListener("click", resetCrop);
elements.reloadButton.addEventListener("click", loadData);
elements.preflightRefreshButton.addEventListener("click", loadPreflight);
elements.pushButton.addEventListener("click", pushToIosApp);

document.querySelectorAll("[data-preset]").forEach((button) => {
  button.addEventListener("click", () => {
    if (!state.selectedSlot) return;
    const preset = button.dataset.preset;
    if (preset === "head") state.selectedCrop = { ...state.selectedCrop, y: 24, zoom: Math.max(1.04, state.selectedCrop.zoom) };
    if (preset === "lower") state.selectedCrop = { ...state.selectedCrop, y: 52 };
    if (preset === "center") state.selectedCrop = { x: 50, y: 38, zoom: 1 };
    if (preset === "close") state.selectedCrop = { ...state.selectedCrop, zoom: Math.min(2.5, Math.max(1.16, state.selectedCrop.zoom + 0.16)) };
    syncControls();
    renderEditor();
  });
});

loadData().catch((error) => {
  console.error(error);
  setStatus("Could not load");
});
