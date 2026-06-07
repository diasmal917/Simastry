const castingStates = [
  "needs_decision",
  "locked",
  "needs_better_photos",
  "replace_identity",
  "consolidate_duplicate",
  "archived",
];

const state = {
  characters: [],
  customCharacters: [],
  selectedCharacterId: null,
  castingFilter: "all",
  detailTab: "candidates",
  characterReferencePreviewUrls: [],
  stats: null,
};

const appAssetSlots = [
  "profile_avatar",
  "card_portrait",
  "astrogram_01",
  "astrogram_02",
  "astrogram_03",
  "astrogram_04",
  "astrogram_05",
  "astrogram_06",
  "astrogram_07",
  "astrogram_08",
  "astrogram_09",
  "astrogram_10",
];

const statsGrid = document.querySelector("#statsGrid");
const resultBox = document.querySelector("#resultBox");
const characterCount = document.querySelector("#characterCount");
const customCharacterCount = document.querySelector("#customCharacterCount");
const characterGallery = document.querySelector("#characterGallery");
const castingFilterBar = document.querySelector("#castingFilterBar");
const customGallery = document.querySelector("#customGallery");
const characterDetail = document.querySelector("#characterDetail");
const referenceGrid = document.querySelector("#referenceGrid");
const referenceInput = document.querySelector("#referenceInput");
const stylePromptInput = document.querySelector("#stylePromptInput");
const stylePromptList = document.querySelector("#stylePromptList");
const characterReferenceInput = document.querySelector("#characterReferenceInput");
const characterReferencePreview = document.querySelector("#characterReferencePreview");
const imageDialog = document.querySelector("#imageDialog");
const fullImage = document.querySelector("#fullImage");
const fullImageCaption = document.querySelector("#fullImageCaption");

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

function formatNumber(value) {
  return Number(value || 0).toLocaleString();
}

function setResult(message, payload) {
  resultBox.textContent = payload ? `${message}\n${JSON.stringify(payload, null, 2)}` : message;
}

function isMobileViewport() {
  return window.matchMedia("(max-width: 680px)").matches;
}

function scrollToStudioDetail() {
  if (isMobileViewport()) {
    characterDetail.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

function scrollToCastGallery() {
  characterGallery.scrollIntoView({ behavior: "smooth", block: "start" });
}

function slotLabel(slot) {
  if (slot === "profile_avatar") return "Profile";
  if (slot === "card_portrait") return "Card";
  if (slot.startsWith("astrogram_")) return `Post ${slot.split("_").at(-1)}`;
  return slot.replaceAll("_", " ");
}

function slotOptions(selected = "profile_avatar") {
  return appAssetSlots
    .map((slot) => `<option value="${slot}" ${slot === selected ? "selected" : ""}>${escapeHtml(slotLabel(slot))}</option>`)
    .join("");
}

function castingLabel(status) {
  const labels = {
    needs_decision: "Needs decision",
    locked: "Locked",
    needs_better_photos: "Needs better photos",
    replace_identity: "Replace identity",
    consolidate_duplicate: "Consolidate duplicate",
    archived: "Archived",
    candidates: "Candidates",
    references: "References",
    rejected: "Rejected",
  };
  return labels[status] || status.replaceAll("_", " ");
}

function castingOptions(selected = "needs_decision") {
  return castingStates
    .map(
      (status) =>
        `<option value="${status}" ${status === selected ? "selected" : ""}>${escapeHtml(castingLabel(status))}</option>`,
    )
    .join("");
}

function initials(name) {
  return String(name || "?")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || "")
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

function renderCharacterReferencePreview() {
  state.characterReferencePreviewUrls.forEach((url) => URL.revokeObjectURL(url));
  state.characterReferencePreviewUrls = [];
  const files = [...characterReferenceInput.files];
  if (!files.length) {
    characterReferencePreview.innerHTML = "";
    return;
  }
  characterReferencePreview.innerHTML = files
    .map((file) => {
      const url = URL.createObjectURL(file);
      state.characterReferencePreviewUrls.push(url);
      return `
        <div class="preview-thumb">
          <img src="${escapeHtml(url)}" alt="${escapeHtml(file.name)}" />
          <span title="${escapeHtml(file.name)}">${escapeHtml(file.name)}</span>
        </div>
      `;
    })
    .join("");
}

function clearCharacterReferencePreview() {
  state.characterReferencePreviewUrls.forEach((url) => URL.revokeObjectURL(url));
  state.characterReferencePreviewUrls = [];
  characterReferencePreview.innerHTML = "";
}

function characterApproval(character) {
  const completion = character.asset_completion || character.completion || {};
  const approved = Number(completion.approved || 0);
  const required = Number(completion.required || appAssetSlots.length);
  const missing = Number(completion.missing || Math.max(required - approved, 0));
  const percent = required ? Math.round((approved / required) * 100) : 0;
  return { approved, required, missing, percent, isComplete: missing === 0 && approved >= required };
}

function coreMissing(character) {
  const missing = character.missing_slots || [];
  return missing.filter((slot) => slot === "profile_avatar" || slot === "card_portrait");
}

function thumbnailMarkup(character) {
  if (character.thumbnail_url) {
    return `<img src="${escapeHtml(character.thumbnail_url)}" alt="${escapeHtml(character.display_name)}" />`;
  }
  return `<span>${escapeHtml(initials(character.display_name))}</span>`;
}

function renderStats() {
  const locked = state.characters.filter((character) => character.casting_status === "locked").length;
  const needsDecision = state.characters.filter((character) => character.casting_status !== "locked").length;
  const coreReady = state.characters.filter((character) => coreMissing(character).length === 0).length;
  const candidates = state.characters.reduce((total, character) => total + Number(character.image_counts?.candidate || 0), 0);
  const items = [
    ["Cast", state.characters.length],
    ["Locked", locked],
    ["Needs decision", needsDecision],
    ["Core ready", coreReady],
    ["Candidates", candidates],
  ];
  statsGrid.innerHTML = items
    .map(([label, value]) => `<div class="summary-pill"><span>${label}</span><strong>${formatNumber(value)}</strong></div>`)
    .join("");
}

function filteredCharacters() {
  if (state.castingFilter === "all") return state.characters;
  return state.characters.filter((character) => character.casting_status === state.castingFilter);
}

function renderCastingFilters() {
  const counts = {
    all: state.characters.length,
    ...Object.fromEntries(castingStates.map((status) => [status, 0])),
  };
  state.characters.forEach((character) => {
    counts[character.casting_status] = Number(counts[character.casting_status] || 0) + 1;
  });
  const filters = ["all", ...castingStates];
  castingFilterBar.innerHTML = filters
    .map((status) => {
      const label = status === "all" ? "All" : castingLabel(status);
      return `
        <button class="filter-chip ${state.castingFilter === status ? "active" : ""}" type="button" data-casting-filter="${status}">
          <span>${escapeHtml(label)}</span>
          <strong>${formatNumber(counts[status] || 0)}</strong>
        </button>
      `;
    })
    .join("");
}

function quickFlags(character) {
  const flags = [];
  const missingCore = coreMissing(character);
  const approval = characterApproval(character);
  if (missingCore.length) flags.push("Core missing");
  if (approval.missing) flags.push(`${approval.missing} slots missing`);
  if (Number(character.image_counts?.candidate || 0)) flags.push("Candidates");
  if (Number(character.image_counts?.rejected || 0)) flags.push("Rejected");
  return flags.slice(0, 3);
}

function characterCard(character) {
  const active = character.id === state.selectedCharacterId ? "active" : "";
  const approval = characterApproval(character);
  const flags = quickFlags(character);
  return `
    <button class="cast-card studio-card ${active} ${character.casting_status === "archived" ? "archived" : ""}" type="button" data-character-id="${escapeHtml(character.id)}">
      <div class="cast-photo">${thumbnailMarkup(character)}</div>
      <div class="cast-card-footer">
        <div class="card-title-row">
          <strong>${escapeHtml(character.display_name)}</strong>
          <em class="casting-badge ${escapeHtml(character.casting_status)}">${escapeHtml(castingLabel(character.casting_status))}</em>
        </div>
        <span>${escapeHtml(character.gender || "Companion")} · ${escapeHtml(character.sun_sign || "No sign")}</span>
        <div class="asset-meter" aria-label="${approval.approved} of ${approval.required} assets approved">
          <span style="width: ${Math.max(approval.percent, 4)}%"></span>
        </div>
        <div class="cast-status-row">
          <small>${approval.approved}/${approval.required} assets</small>
          <small>${character.generation_job_count || 0} prompts</small>
        </div>
        <div class="flag-row">
          ${flags.length ? flags.map((flag) => `<span>${escapeHtml(flag)}</span>`).join("") : `<span>Ready to judge</span>`}
        </div>
      </div>
    </button>
  `;
}

function renderCharacterGallery() {
  const items = filteredCharacters();
  characterGallery.innerHTML = items.length
    ? items.map(characterCard).join("")
    : `<div class="path-box">No characters match this casting state.</div>`;
}

function customCard(character) {
  const title = `${character.display_name || "Custom character"} profile`;
  const referenceCount = Number(character.image_counts?.reference || 0);
  const candidateCount = Number(character.image_counts?.candidate || 0);
  return `
    <article class="custom-card ${character.casting_status === "archived" ? "archived" : ""}" data-custom-character-id="${escapeHtml(character.id)}">
      <button class="custom-photo-button" type="button" data-full-image="${escapeHtml(character.thumbnail_url || "")}" data-full-title="${escapeHtml(title)}" ${character.thumbnail_url ? "" : "disabled"}>
        <div class="custom-photo">${thumbnailMarkup(character)}</div>
      </button>
      <strong>${escapeHtml(character.display_name)}</strong>
      <span>${escapeHtml(castingLabel(character.casting_status))}</span>
      <span>${formatNumber(referenceCount)} reference${referenceCount === 1 ? "" : "s"} · ${formatNumber(candidateCount)} candidate${candidateCount === 1 ? "" : "s"}</span>
      <div class="custom-reference-uploader">
        <label>
          Add reference pictures
          <input type="file" accept="image/*" multiple data-custom-reference-files />
        </label>
        <button type="button" data-upload-custom-references="${escapeHtml(character.id)}">Add references</button>
      </div>
      <div class="custom-card-actions">
        <button type="button" data-generate-custom="${escapeHtml(character.id)}">Generate 10-photo prompt</button>
        <button type="button" data-generate-custom-style-board="${escapeHtml(character.id)}">Generate style-board set</button>
        <button type="button" data-archive-custom="${escapeHtml(character.id)}">Archive</button>
      </div>
    </article>
  `;
}

function customCharacterOptions(selected = "") {
  const choices = state.customCharacters.filter((character) => character.casting_status !== "archived");
  if (!choices.length) {
    return `<option value="">No custom candidates yet</option>`;
  }
  return [
    `<option value="">Choose custom candidate</option>`,
    ...choices.map(
      (character) =>
        `<option value="${escapeHtml(character.id)}" ${character.id === selected ? "selected" : ""}>${escapeHtml(character.display_name)}</option>`,
    ),
  ].join("");
}

function allConsolidationOptions(selectedCharacterId) {
  const choices = state.customCharacters.filter((character) => character.id !== selectedCharacterId && character.casting_status !== "archived");
  if (!choices.length) return `<option value="">No duplicate candidates yet</option>`;
  return [
    `<option value="">Choose duplicate candidate</option>`,
    ...choices.map((character) => `<option value="${escapeHtml(character.id)}">${escapeHtml(character.display_name)}</option>`),
  ].join("");
}

function pictureButton(image, title, className = "picture-tile", options = {}) {
  if (!image) return "";
  const canReject = Boolean(options.canReject && image.id);
  const rejectLabel = options.rejectLabel || `Move ${title} to rejected`;
  return `
    <div class="picture-shell ${canReject ? "can-reject" : ""}">
      <button class="${className}" type="button" data-full-image="${escapeHtml(image.url)}" data-full-title="${escapeHtml(title)}">
        <img src="${escapeHtml(image.url)}" alt="${escapeHtml(title)}" />
      </button>
      ${
        canReject
          ? `<button class="trash-button" type="button" data-reject-image="${escapeHtml(image.id)}" title="${escapeHtml(rejectLabel)}" aria-label="${escapeHtml(rejectLabel)}"><span class="trash-icon" aria-hidden="true"></span></button>`
          : ""
      }
    </div>
  `;
}

function slotCard(slot, characterName) {
  const image = slot.approved_image;
  const title = `${characterName} · ${slot.label || slotLabel(slot.slot_key)}`;
  return `
    <div class="slot-card ${slot.missing ? "missing" : "filled"}">
      ${
        image
          ? pictureButton(image, title, "picture-tile", { canReject: true, rejectLabel: "Move to rejected" })
          : `<div class="slot-empty">Missing</div>`
      }
      <div class="slot-card-footer">
        <strong>${escapeHtml(slot.label || slotLabel(slot.slot_key))}</strong>
        <span>${image ? "Approved" : "Missing"}</span>
      </div>
    </div>
  `;
}

function referenceCard(image, characterName, isPrimary = false) {
  const title = `${characterName} reference`;
  return `
    <div class="asset-card" data-image-card="${escapeHtml(image.id)}">
      ${pictureButton(image, title)}
      <div class="slot-card-footer">
        <strong>${escapeHtml(image.name || "Reference")}</strong>
        <span>${isPrimary ? "Primary reference" : "Reference"}</span>
      </div>
      <div class="asset-card-actions">
        <button type="button" data-primary-reference="${escapeHtml(image.id)}">${isPrimary ? "Primary" : "Make primary"}</button>
      </div>
    </div>
  `;
}

function candidateCard(image, characterName) {
  const title = `${characterName} candidate`;
  const rating = Number(image.feedback_rating || 0);
  return `
    <div class="asset-card" data-image-card="${escapeHtml(image.id)}">
      ${pictureButton(image, title, "picture-tile", { canReject: true, rejectLabel: "Reject candidate" })}
      <div class="slot-card-footer">
        <strong>${escapeHtml(image.name || "Candidate")}</strong>
        <span>${rating ? `${rating}/5` : "Unrated"} candidate</span>
      </div>
      <div class="feedback-form">
        <label>
          Rating
          <select data-feedback-rating>
            <option value="0" ${rating === 0 ? "selected" : ""}>No rating</option>
            ${[1, 2, 3, 4, 5].map((value) => `<option value="${value}" ${rating === value ? "selected" : ""}>${value}/5</option>`).join("")}
          </select>
        </label>
        <label>
          Feedback
          <textarea data-feedback-notes rows="2" placeholder="What to reinforce or avoid?">${escapeHtml(image.feedback_notes || "")}</textarea>
        </label>
        <button type="button" data-save-image-feedback="${escapeHtml(image.id)}">Save feedback</button>
      </div>
      <div class="asset-card-actions">
        <select data-promote-slot>${slotOptions("profile_avatar")}</select>
        <button type="button" data-promote-candidate="${escapeHtml(image.id)}">Promote</button>
      </div>
    </div>
  `;
}

function historyCard(image, label, characterName) {
  const slot = image.slot_label || slotLabel(image.slot_key || "");
  const title = `${characterName} · ${slot || label}`;
  return `
    <div class="asset-card muted">
      ${pictureButton(image, title)}
      <div class="slot-card-footer">
        <strong>${escapeHtml(slot || label)}</strong>
        <span>${escapeHtml(label)}</span>
      </div>
    </div>
  `;
}

function renderAssetPanel(character, panelName) {
  if (panelName === "references") {
    const references = character.references || [];
    return references.length
      ? `<div class="asset-grid">${references
          .map((image) => referenceCard(image, character.display_name, image.id === character.primary_reference_image_id))
          .join("")}</div>`
      : `<div class="path-box">No identity references yet.</div>`;
  }
  if (panelName === "candidates") {
    const candidates = character.candidates || [];
    return candidates.length
      ? `<div class="asset-grid">${candidates.map((image) => candidateCard(image, character.display_name)).join("")}</div>`
      : `<div class="path-box">No generated candidates yet.</div>`;
  }
  if (panelName === "rejected") {
    const rejected = character.rejected_images || [];
    return rejected.length
      ? `<div class="asset-grid">${rejected.map((image) => historyCard(image, "Rejected", character.display_name)).join("")}</div>`
      : `<div class="path-box">No rejected pictures.</div>`;
  }
  const archived = character.archived_images || [];
  return archived.length
    ? `<div class="asset-grid">${archived.map((image) => historyCard(image, "Archived", character.display_name)).join("")}</div>`
    : `<div class="path-box">No archived slot versions.</div>`;
}

function generationJobs(character) {
  const jobs = character.generation_jobs || [];
  if (!jobs.length) return `<div class="path-box">No prompt packs yet.</div>`;
  return jobs
    .slice(0, 3)
    .map(
      (job) => `
        <div class="job-row">
          <strong>${escapeHtml(job.id)}</strong>
          <span>${escapeHtml(job.status || "ready")}</span>
          <small>${escapeHtml(job.prompt_pack_path || "")}</small>
        </div>
      `,
    )
    .join("");
}

function characterDetailTemplate(character) {
  const approval = characterApproval(character);
  const thumbnailTitle = `${character.display_name} profile`;
  const coreSlots = (character.slot_status || []).filter((slot) => slot.slot_key === "profile_avatar" || slot.slot_key === "card_portrait");
  const astrogramSlots = (character.slot_status || []).filter((slot) => slot.slot_key.startsWith("astrogram_"));
  const activeTab = state.detailTab || "candidates";
  return `
    <button class="mobile-back-button" type="button" data-scroll-gallery>Back to 24</button>

    <div class="character-detail-header studio-detail-header">
      <div class="detail-profile">
        ${
          character.thumbnail_url
            ? `<button class="detail-avatar" type="button" data-full-image="${escapeHtml(character.thumbnail_url)}" data-full-title="${escapeHtml(thumbnailTitle)}">${thumbnailMarkup(character)}</button>`
            : `<div class="detail-avatar">${thumbnailMarkup(character)}</div>`
        }
        <div>
          <h2>${escapeHtml(character.display_name)}</h2>
          <p>${escapeHtml(character.gender || "Companion")} · ${escapeHtml(character.sun_sign || "No sign")}</p>
          <div class="detail-chip-row">
            <em class="casting-badge ${escapeHtml(character.casting_status)}">${escapeHtml(castingLabel(character.casting_status))}</em>
            <em class="approval-badge ${approval.isComplete ? "approved" : "not-approved"}">${approval.approved}/${approval.required} assets</em>
          </div>
        </div>
      </div>
    </div>

    <section class="studio-block">
      <h3>Casting Decision</h3>
      <div class="casting-editor">
        <label>
          Casting status
          <select data-casting-status>${castingOptions(character.casting_status)}</select>
        </label>
        <label class="wide-field">
          Casting notes
          <textarea data-casting-notes rows="3" placeholder="What needs to change before this identity is locked?">${escapeHtml(character.casting_notes || "")}</textarea>
        </label>
        <button type="button" data-save-casting>Save casting</button>
        <button type="button" data-archive-character>Archive character</button>
      </div>
    </section>

    <div class="detail-stats">
      <div><span>Identity</span><strong>${escapeHtml(castingLabel(character.casting_status))}</strong></div>
      <div><span>Assets</span><strong>${approval.approved}/${approval.required}</strong></div>
      <div><span>References</span><strong>${formatNumber(character.image_counts?.reference || 0)}</strong></div>
      <div><span>Candidates</span><strong>${formatNumber(character.image_counts?.candidate || 0)}</strong></div>
    </div>

    <section class="studio-block">
      <div class="section-heading-row">
        <h3>Generate And Import</h3>
        <button type="button" data-generate-selected>Generate 10-photo prompt</button>
        <button type="button" data-generate-selected-style-board>Generate style-board set</button>
      </div>
      <div class="generation-tools">
        <label>
          Upload generated candidates
          <input id="candidateUpload" data-candidate-upload-files type="file" accept="image/*" multiple />
        </label>
        <button type="button" data-upload-candidates>Upload candidates</button>
        <label>
          Upload identity references
          <input id="identityReferenceUpload" data-reference-upload-files type="file" accept="image/*" multiple />
        </label>
        <button type="button" data-upload-character-references>Upload references</button>
      </div>
      <div class="job-list">${generationJobs(character)}</div>
    </section>

    <section class="studio-block">
      <h3>Profile And Card</h3>
      <div class="slot-grid core-slot-grid">${coreSlots.map((slot) => slotCard(slot, character.display_name)).join("")}</div>
    </section>

    <section class="studio-block">
      <h3>Astrogram</h3>
      <div class="slot-grid">${astrogramSlots.map((slot) => slotCard(slot, character.display_name)).join("")}</div>
    </section>

    <section class="studio-block">
      <h3>Image Library</h3>
      <div class="detail-picture-tabs">
        ${["candidates", "references", "rejected", "archived"]
          .map(
            (tab) =>
              `<button class="detail-picture-tab ${activeTab === tab ? "active" : ""}" type="button" data-picture-tab="${tab}">${escapeHtml(castingLabel(tab).replace("Needs ", ""))}</button>`,
          )
          .join("")}
      </div>
      <div class="picture-panel active" data-picture-panel="${escapeHtml(activeTab)}">
        ${renderAssetPanel(character, activeTab)}
      </div>
    </section>

    <section class="studio-block">
      <h3>Replace Or Consolidate</h3>
      <div class="customize-panel">
        <label>
          Slot
          <select data-replace-slot>${slotOptions("profile_avatar")}</select>
        </label>
        <label>
          Upload direct replacement
          <input data-replace-file type="file" accept="image/*" />
        </label>
        <button data-replace-upload type="button">Replace with upload</button>
        <label>
          Custom candidate
          <select data-custom-character-select>${customCharacterOptions()}</select>
        </label>
        <button data-swap-custom type="button" ${state.customCharacters.some((item) => item.casting_status !== "archived") ? "" : "disabled"}>Replace with custom</button>
        <label>
          Duplicate candidate
          <select data-consolidate-character-select>${allConsolidationOptions(character.id)}</select>
        </label>
        <button data-consolidate-character type="button" ${state.customCharacters.some((item) => item.casting_status !== "archived") ? "" : "disabled"}>Consolidate duplicate</button>
      </div>
    </section>
  `;
}

async function loadStats() {
  state.stats = await api.get("/api/stats");
}

async function loadCharacters() {
  const payload = await api.get("/api/characters?source=app&limit=24");
  state.characters = payload.items;
  characterCount.textContent = `${formatNumber(payload.total)} app-facing companions`;
  renderStats();
  renderCastingFilters();
  renderCharacterGallery();

  const selectedStillVisible = state.characters.some((item) => item.id === state.selectedCharacterId);
  const preferredSelection = filteredCharacters()[0] || state.characters[0];
  if (!selectedStillVisible && preferredSelection) {
    await selectCharacter(preferredSelection.id);
  } else if (state.selectedCharacterId) {
    await selectCharacter(state.selectedCharacterId);
  } else if (preferredSelection) {
    await selectCharacter(preferredSelection.id);
  }
  renderCharacterGallery();
}

async function loadCustomCharacters() {
  const payload = await api.get("/api/characters?source=custom&limit=200");
  state.customCharacters = payload.items;
  customCharacterCount.textContent = `${formatNumber(payload.total)} candidates`;
  customGallery.innerHTML = payload.items.length
    ? payload.items.map(customCard).join("")
    : `<div class="path-box">No custom candidates yet.</div>`;
}

async function selectCharacter(id) {
  state.selectedCharacterId = id;
  characterGallery.querySelectorAll(".cast-card").forEach((card) => {
    card.classList.toggle("active", card.dataset.characterId === id);
  });
  const character = await api.get(`/api/characters/${id}`);
  characterDetail.innerHTML = characterDetailTemplate(character);
}

function openFullImage(url, title) {
  if (!url) return;
  fullImage.src = url;
  fullImage.alt = title || "Full picture";
  fullImageCaption.textContent = title || "";
  if (typeof imageDialog.showModal === "function") {
    imageDialog.showModal();
  } else {
    imageDialog.setAttribute("open", "");
  }
}

async function refreshStudioDetail() {
  await Promise.all([loadStats(), loadCustomCharacters()]);
  await loadCharacters();
}

async function rejectImage(imageId) {
  if (!state.selectedCharacterId || !imageId) return;
  setResult("Moving picture to Rejected...");
  await api.post(`/api/images/${imageId}/reject`);
  state.detailTab = "rejected";
  setResult("Picture moved to Rejected.");
  await refreshStudioDetail();
}

async function saveCastingStatus(primaryReferenceImageId = "") {
  if (!state.selectedCharacterId) return;
  const status = characterDetail.querySelector("[data-casting-status]")?.value || "needs_decision";
  const notes = characterDetail.querySelector("[data-casting-notes]")?.value || "";
  setResult("Saving casting decision...");
  await api.post(`/api/characters/${state.selectedCharacterId}/casting-status`, {
    casting_status: status,
    casting_notes: notes,
    primary_reference_image_id: primaryReferenceImageId,
  });
  setResult(primaryReferenceImageId ? "Primary reference saved." : "Casting decision saved.");
  await refreshStudioDetail();
}

async function archiveSelectedCharacter(characterId = state.selectedCharacterId) {
  if (!characterId) return;
  setResult("Archiving character...");
  await api.post(`/api/characters/${characterId}/archive`, { reason: "Archived from Factory Cast Studio." });
  setResult("Character archived.");
  if (characterId === state.selectedCharacterId) state.detailTab = "candidates";
  await refreshStudioDetail();
}

async function generatePromptForCharacter(characterId, label = "character") {
  if (!characterId) return;
  setResult(`Preparing 10-photo prompt for ${label}...`);
  const payload = await api.post(`/api/characters/${characterId}/generation-jobs`, {
    notes: "Identity-first 10-photo Instagram-style prompt pack.",
  });
  setResult("10-photo prompt ready.", {
    character: payload.character?.display_name || label,
    promptPack: payload.job?.prompt_pack_path,
    references: payload.character?.references?.length || 0,
  });
  await refreshStudioDetail();
}

async function generateStyleBoardForCharacter(characterId, label = "character") {
  if (!characterId) return;
  setResult(`Preparing style-board set for ${label}...`);
  const payload = await api.post(`/api/characters/${characterId}/style-board-generation-jobs`, {
    notes: "One picture per individual style-board reference.",
  });
  setResult("Style-board prompt set ready.", {
    character: payload.character?.display_name || label,
    styleItems: payload.style_item_count,
    promptPack: payload.job?.prompt_pack_path,
  });
  await refreshStudioDetail();
}

async function uploadCandidates() {
  if (!state.selectedCharacterId) return;
  const input = characterDetail.querySelector("[data-candidate-upload-files]");
  const files = [...(input?.files || [])];
  if (!files.length) {
    setResult("Choose generated candidate pictures first.");
    return;
  }
  setResult("Uploading generated candidates...");
  const encodedFiles = await Promise.all(files.map(readFileAsDataURL));
  const payload = await api.post(`/api/characters/${state.selectedCharacterId}/images/upload`, {
    files: encodedFiles,
    notes: "Uploaded generated candidate from Cast Studio.",
  });
  input.value = "";
  state.detailTab = "candidates";
  setResult("Candidates uploaded.", { saved: payload.saved });
  await refreshStudioDetail();
}

async function uploadCharacterReferences() {
  if (!state.selectedCharacterId) return;
  const input = characterDetail.querySelector("[data-reference-upload-files]");
  const files = [...(input?.files || [])];
  if (!files.length) {
    setResult("Choose identity reference pictures first.");
    return;
  }
  setResult("Uploading identity references...");
  const encodedFiles = await Promise.all(files.map(readFileAsDataURL));
  const payload = await api.post(`/api/characters/${state.selectedCharacterId}/references/upload`, { files: encodedFiles });
  input.value = "";
  state.detailTab = "references";
  setResult("Identity references uploaded.", { saved: payload.saved });
  await refreshStudioDetail();
}

async function promoteCandidate(button) {
  if (!state.selectedCharacterId) return;
  const card = button.closest("[data-image-card]");
  const imageId = button.dataset.promoteCandidate;
  const slot = card?.querySelector("[data-promote-slot]")?.value || "profile_avatar";
  setResult("Promoting candidate...");
  await api.post(`/api/images/${imageId}/promote`, { slot_key: slot });
  setResult("Candidate promoted.", { slot: slotLabel(slot) });
  await refreshStudioDetail();
}

async function saveImageFeedback(button) {
  const imageId = button?.dataset?.saveImageFeedback || "";
  if (!imageId) return;
  const card = button.closest("[data-image-card]");
  const rating = Number(card?.querySelector("[data-feedback-rating]")?.value || 0);
  const feedbackNotes = card?.querySelector("[data-feedback-notes]")?.value || "";
  setResult("Saving image feedback...");
  await api.post(`/api/images/${imageId}/feedback`, {
    rating,
    feedback_notes: feedbackNotes,
  });
  setResult("Image feedback saved.");
  await refreshStudioDetail();
}

async function replaceSlotWithUpload() {
  if (!state.selectedCharacterId) return;
  const input = characterDetail.querySelector("[data-replace-file]");
  const slot = characterDetail.querySelector("[data-replace-slot]")?.value || "profile_avatar";
  const file = input?.files?.[0];
  if (!file) {
    setResult("Choose a picture first.");
    return;
  }
  setResult("Replacing picture...");
  const encoded = await readFileAsDataURL(file);
  const upload = await api.post(`/api/characters/${state.selectedCharacterId}/images/upload`, {
    files: [encoded],
    notes: "Direct replacement uploaded from Cast Studio.",
  });
  const imageId = upload.items?.[0]?.id;
  if (!imageId) throw new Error("Picture upload did not save.");
  await api.post(`/api/images/${imageId}/promote`, { slot_key: slot });
  input.value = "";
  setResult("Picture replaced.", { slot: slotLabel(slot) });
  await refreshStudioDetail();
}

async function swapSlotWithCustom() {
  if (!state.selectedCharacterId) return;
  const slot = characterDetail.querySelector("[data-replace-slot]")?.value || "profile_avatar";
  const sourceCharacterId = characterDetail.querySelector("[data-custom-character-select]")?.value || "";
  if (!sourceCharacterId) {
    setResult("Choose a custom candidate first.");
    return;
  }
  setResult("Replacing picture from custom candidate...");
  await api.post(`/api/characters/${state.selectedCharacterId}/swap-from-character`, {
    source_character_id: sourceCharacterId,
    slot_key: slot,
  });
  setResult("Picture replaced.", { slot: slotLabel(slot) });
  await refreshStudioDetail();
}

async function consolidateDuplicate() {
  if (!state.selectedCharacterId) return;
  const sourceCharacterId = characterDetail.querySelector("[data-consolidate-character-select]")?.value || "";
  if (!sourceCharacterId) {
    setResult("Choose a duplicate candidate first.");
    return;
  }
  const notes = characterDetail.querySelector("[data-casting-notes]")?.value || "";
  setResult("Consolidating duplicate...");
  const payload = await api.post(`/api/characters/${state.selectedCharacterId}/consolidate`, {
    source_character_id: sourceCharacterId,
    notes,
  });
  state.detailTab = "references";
  setResult("Duplicate consolidated.", { copied: payload.copied_count });
  await refreshStudioDetail();
}

async function createCharacter(options = {}) {
  const generatePrompt = Boolean(options.generatePrompt);
  const nameInput = document.querySelector("#characterNameInput");
  const name = nameInput.value.trim();
  if (!name) {
    setResult("Add a candidate name first.");
    nameInput.focus();
    return;
  }
  const sign = document.querySelector("#characterSignInput").value;
  const files = [...characterReferenceInput.files];
  if (!files.length) {
    setResult("Choose at least one character picture.");
    characterReferenceInput.focus();
    return;
  }
  const encodedFiles = await Promise.all(files.map(readFileAsDataURL));
  setResult(generatePrompt ? "Adding candidate and preparing prompt..." : "Adding candidate...");
  const character = await api.post("/api/characters", {
    display_name: name,
    gender: "",
    sun_sign: sign,
    moon_sign: sign,
    rising_sign: sign,
    visual_notes: document.querySelector("#characterNotesInput").value.trim(),
    files: encodedFiles,
  });

  document.querySelector("#characterNameInput").value = "";
  document.querySelector("#characterSignInput").value = "";
  document.querySelector("#characterNotesInput").value = "";
  characterReferenceInput.value = "";
  clearCharacterReferencePreview();
  if (generatePrompt) {
    const promptPayload = await api.post(`/api/characters/${character.id}/generation-jobs`, {
      notes: "Custom candidate 10-photo Instagram-style prompt pack.",
    });
    setResult("Candidate added and 10-photo prompt ready.", {
      name: character.display_name,
      promptPack: promptPayload.job?.prompt_pack_path,
      referencePictures: promptPayload.character?.references?.length || files.length,
    });
  } else {
    setResult("Candidate added.", {
      name: character.display_name,
      referencePictures: character.references?.length || files.length,
    });
  }
  await Promise.all([loadStats(), loadCustomCharacters()]);
  if (state.selectedCharacterId) await selectCharacter(state.selectedCharacterId);
}

async function uploadCustomReferences(button) {
  const characterId = button?.dataset?.uploadCustomReferences || "";
  if (!characterId) return;
  const card = button.closest("[data-custom-character-id]");
  const input = card?.querySelector("[data-custom-reference-files]");
  const files = [...(input?.files || [])];
  if (!files.length) {
    setResult("Choose reference pictures for this candidate first.");
    input?.focus();
    return;
  }
  const character = state.customCharacters.find((item) => item.id === characterId);
  setResult(`Adding ${files.length} reference picture${files.length === 1 ? "" : "s"}...`);
  const encodedFiles = await Promise.all(files.map(readFileAsDataURL));
  const payload = await api.post(`/api/characters/${characterId}/references/upload`, { files: encodedFiles });
  input.value = "";
  setResult("Reference pictures added.", {
    candidate: payload.character?.display_name || character?.display_name || "Custom candidate",
    added: payload.saved,
    totalReferences: payload.character?.references?.length,
  });
  await Promise.all([loadStats(), loadCustomCharacters()]);
  if (state.selectedCharacterId) await selectCharacter(state.selectedCharacterId);
}

async function exportAppAssets() {
  setResult("Building app-facing 24 export package...");
  const payload = await api.post("/api/export/app-assets");
  setResult("Export package created.", {
    directory: payload.directory,
    missing: payload.missing_count,
    unlocked: payload.unlocked_count,
  });
  await loadStats();
}

async function importApprovedAssets() {
  setResult("Refreshing approved pictures...");
  const payload = await api.post("/api/characters/import-approved-assets");
  setResult("Approved pictures refreshed.", {
    charactersUpdated: payload.characters_updated,
    slotsAdded: payload.approved_slots_added,
  });
  await refreshStudioDetail();
}

function referenceThumbs(items) {
  if (!items?.length) return `<div class="path-box">No style pictures yet.</div>`;
  return items
    .map(
      (item) => `
        <div class="reference-shell">
          <button class="reference-thumb" type="button" data-full-image="${escapeHtml(item.url)}" data-full-title="${escapeHtml(item.name)}">
            <img src="${escapeHtml(item.url)}" alt="${escapeHtml(item.name)}" />
            <span title="${escapeHtml(item.name)}">${escapeHtml(item.name)}</span>
          </button>
          <button class="trash-button" type="button" data-delete-style-reference="${escapeHtml(item.name)}" title="Delete style picture" aria-label="Delete style picture"><span class="trash-icon" aria-hidden="true"></span></button>
        </div>
      `,
    )
    .join("");
}

function stylePromptCards(prompts) {
  if (!prompts?.length) return `<div class="path-box">No style prompts yet.</div>`;
  return prompts
    .map(
      (item) => `
        <article class="style-prompt-card">
          <p>${escapeHtml(item.text)}</p>
          <span>${escapeHtml(item.created_at || "")}</span>
          <button type="button" data-delete-style-prompt="${escapeHtml(item.id)}">Delete prompt</button>
        </article>
      `,
    )
    .join("");
}

async function loadReferences() {
  const payload = await api.get("/api/references");
  referenceGrid.innerHTML = referenceThumbs(payload.items);
  stylePromptList.innerHTML = stylePromptCards(payload.prompts);
}

async function uploadReferences() {
  const files = [...referenceInput.files];
  if (!files.length) {
    setResult("Choose style pictures first.");
    return;
  }
  setResult("Uploading style pictures...");
  const encodedFiles = await Promise.all(files.map(readFileAsDataURL));
  const payload = await api.post("/api/references/upload", { files: encodedFiles });
  referenceInput.value = "";
  setResult("Style pictures uploaded.", { saved: payload.saved });
  await Promise.all([loadReferences(), loadStats()]);
}

async function addStylePrompt() {
  const text = stylePromptInput.value.trim();
  if (!text) {
    setResult("Add a style prompt first.");
    stylePromptInput.focus();
    return;
  }
  setResult("Adding style prompt...");
  const payload = await api.post("/api/style-prompts", { text });
  stylePromptInput.value = "";
  setResult("Style prompt added.", { saved: payload.saved, prompts: payload.prompts?.length || 0 });
  await Promise.all([loadReferences(), loadStats()]);
}

async function deleteStyleReference(button) {
  const name = button?.dataset?.deleteStyleReference || "";
  if (!name) return;
  setResult("Deleting style picture...");
  await api.post("/api/references/delete", { name });
  setResult("Style picture deleted.", { name });
  await Promise.all([loadReferences(), loadStats()]);
}

async function deleteStylePrompt(button) {
  const id = button?.dataset?.deleteStylePrompt || "";
  if (!id) return;
  setResult("Deleting style prompt...");
  await api.post("/api/style-prompts/delete", { id });
  setResult("Style prompt deleted.");
  await Promise.all([loadReferences(), loadStats()]);
}

function switchTab(targetId) {
  document.querySelectorAll(".tab-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.tabTarget === targetId);
  });
  document.querySelectorAll(".tab-panel").forEach((panel) => {
    const active = panel.id === targetId;
    panel.hidden = !active;
    panel.classList.toggle("active", active);
  });
}

function bindEvents() {
  document.querySelector("#createCharacterBtn").addEventListener("click", () => createCharacter().catch(showError));
  document
    .querySelector("#createAndGenerateCharacterBtn")
    .addEventListener("click", () => createCharacter({ generatePrompt: true }).catch(showError));
  document.querySelector("#importApprovedAssetsBtn").addEventListener("click", () => importApprovedAssets().catch(showError));
  document.querySelector("#exportAppAssetsBtn").addEventListener("click", () => exportAppAssets().catch(showError));
  document.querySelector("#uploadReferencesBtn").addEventListener("click", () => uploadReferences().catch(showError));
  document.querySelector("#addStylePromptBtn").addEventListener("click", () => addStylePrompt().catch(showError));
  characterReferenceInput.addEventListener("change", renderCharacterReferencePreview);

  document.querySelector(".tab-bar").addEventListener("click", (event) => {
    const button = event.target.closest("[data-tab-target]");
    if (button) switchTab(button.dataset.tabTarget);
  });

  castingFilterBar.addEventListener("click", (event) => {
    const button = event.target.closest("[data-casting-filter]");
    if (!button) return;
    state.castingFilter = button.dataset.castingFilter;
    renderCastingFilters();
    renderCharacterGallery();
  });

  characterGallery.addEventListener("click", async (event) => {
    const card = event.target.closest("[data-character-id]");
    if (card) {
      await selectCharacter(card.dataset.characterId).catch(showError);
      scrollToStudioDetail();
    }
  });

  characterDetail.addEventListener("click", async (event) => {
    if (event.target.closest("[data-scroll-gallery]")) {
      scrollToCastGallery();
      return;
    }
    const rejectButton = event.target.closest("[data-reject-image]");
    if (rejectButton) {
      await rejectImage(rejectButton.dataset.rejectImage).catch(showError);
      return;
    }
    const pictureTab = event.target.closest("[data-picture-tab]");
    if (pictureTab) {
      state.detailTab = pictureTab.dataset.pictureTab;
      await selectCharacter(state.selectedCharacterId).catch(showError);
      return;
    }
    const fullPicture = event.target.closest("[data-full-image]");
    if (fullPicture) {
      openFullImage(fullPicture.dataset.fullImage, fullPicture.dataset.fullTitle);
      return;
    }
    const promoteButton = event.target.closest("[data-promote-candidate]");
    if (promoteButton) {
      await promoteCandidate(promoteButton).catch(showError);
      return;
    }
    const feedbackButton = event.target.closest("[data-save-image-feedback]");
    if (feedbackButton) {
      await saveImageFeedback(feedbackButton).catch(showError);
      return;
    }
    const primaryButton = event.target.closest("[data-primary-reference]");
    if (primaryButton) {
      await saveCastingStatus(primaryButton.dataset.primaryReference).catch(showError);
      return;
    }
    if (event.target.closest("[data-save-casting]")) {
      await saveCastingStatus().catch(showError);
      return;
    }
    if (event.target.closest("[data-archive-character]")) {
      await archiveSelectedCharacter().catch(showError);
      return;
    }
    if (event.target.closest("[data-generate-selected]")) {
      const selected = state.characters.find((character) => character.id === state.selectedCharacterId);
      await generatePromptForCharacter(state.selectedCharacterId, selected?.display_name || "selected character").catch(showError);
      return;
    }
    if (event.target.closest("[data-generate-selected-style-board]")) {
      const selected = state.characters.find((character) => character.id === state.selectedCharacterId);
      await generateStyleBoardForCharacter(state.selectedCharacterId, selected?.display_name || "selected character").catch(showError);
      return;
    }
    if (event.target.closest("[data-upload-candidates]")) {
      await uploadCandidates().catch(showError);
      return;
    }
    if (event.target.closest("[data-upload-character-references]")) {
      await uploadCharacterReferences().catch(showError);
      return;
    }
    if (event.target.closest("[data-replace-upload]")) {
      await replaceSlotWithUpload().catch(showError);
      return;
    }
    if (event.target.closest("[data-swap-custom]")) {
      await swapSlotWithCustom().catch(showError);
      return;
    }
    if (event.target.closest("[data-consolidate-character]")) {
      await consolidateDuplicate().catch(showError);
    }
  });

  customGallery.addEventListener("click", async (event) => {
    const uploadReferencesButton = event.target.closest("[data-upload-custom-references]");
    if (uploadReferencesButton) {
      await uploadCustomReferences(uploadReferencesButton).catch(showError);
      return;
    }
    const generateButton = event.target.closest("[data-generate-custom]");
    if (generateButton) {
      const character = state.customCharacters.find((item) => item.id === generateButton.dataset.generateCustom);
      await generatePromptForCharacter(generateButton.dataset.generateCustom, character?.display_name || "custom candidate").catch(showError);
      return;
    }
    const generateStyleButton = event.target.closest("[data-generate-custom-style-board]");
    if (generateStyleButton) {
      const character = state.customCharacters.find((item) => item.id === generateStyleButton.dataset.generateCustomStyleBoard);
      await generateStyleBoardForCharacter(generateStyleButton.dataset.generateCustomStyleBoard, character?.display_name || "custom candidate").catch(showError);
      return;
    }
    const archiveButton = event.target.closest("[data-archive-custom]");
    if (archiveButton) {
      await archiveSelectedCharacter(archiveButton.dataset.archiveCustom).catch(showError);
      return;
    }
    const fullPicture = event.target.closest("[data-full-image]");
    if (fullPicture) openFullImage(fullPicture.dataset.fullImage, fullPicture.dataset.fullTitle);
  });

  referenceGrid.addEventListener("click", (event) => {
    const deleteButton = event.target.closest("[data-delete-style-reference]");
    if (deleteButton) {
      deleteStyleReference(deleteButton).catch(showError);
      return;
    }
    const fullPicture = event.target.closest("[data-full-image]");
    if (fullPicture) openFullImage(fullPicture.dataset.fullImage, fullPicture.dataset.fullTitle);
  });

  stylePromptList.addEventListener("click", (event) => {
    const deleteButton = event.target.closest("[data-delete-style-prompt]");
    if (deleteButton) deleteStylePrompt(deleteButton).catch(showError);
  });

  imageDialog.addEventListener("click", (event) => {
    if (event.target === imageDialog) imageDialog.close();
  });
}

function showError(error) {
  setResult(`Needs attention: ${error.message}`);
}

async function init() {
  bindEvents();
  await Promise.all([loadStats(), loadCustomCharacters(), loadReferences()]);
  await loadCharacters();
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("/sw.js").catch(() => {});
  }
}

init().catch(showError);
