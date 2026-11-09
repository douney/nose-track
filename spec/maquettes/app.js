"use strict";

// Prototype indépendant : toutes les positions, distances et réceptions sont fictives.
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const icon = (name) => `<svg class="icon" aria-hidden="true"><use href="#i-${name}"/></svg>`;
const state = {
  role: null,
  startedAt: null,
  session: null,
  layer: "classic",
  accuracy: true,
  reference: true,
  zoom: 1,
  angle: 0,
  pan: { x: 0, y: 0 },
  tracks: [
    { name: "La boucle des Pins", detail: "Nala · Traceur + chien · 620 m" },
    { name: "Le départ de la Clairière", detail: "Traceur · 410 m" },
  ],
};
const route = $("#recordedPath");
const routeLength = route.getTotalLength();
const focusable = 'button:not(:disabled), input:not(:disabled), a[href], [tabindex="0"]';
let previousFocus;
let toastTimeout;

function notify(message) {
  clearTimeout(toastTimeout);
  $("#toast").textContent = message;
  $("#toast").hidden = false;
  toastTimeout = setTimeout(() => { $("#toast").hidden = true; }, 3500);
}

function closeSheet() {
  $("#sheetOverlay").hidden = true;
  previousFocus?.focus();
}

function showSheet(title, content) {
  if ($("#sheetOverlay").hidden) previousFocus = document.activeElement;
  $("#bottomSheet").innerHTML = `<div class="sheet-handle" aria-hidden="true"></div>
    <div class="sheet-heading"><h2 id="sheetTitle">${title}</h2>
    <button class="close-button" aria-label="Fermer">${icon("close")}</button></div>${content}`;
  $("#bottomSheet .close-button").addEventListener("click", closeSheet);
  $("#sheetOverlay").hidden = false;
  $("#bottomSheet").scrollTop = 0;
  $("#bottomSheet").focus();
}

$("#sheetOverlay").addEventListener("click", (event) => {
  if (event.target === $("#sheetOverlay")) closeSheet();
});
document.addEventListener("keydown", (event) => {
  if ($("#sheetOverlay").hidden) return;
  if (event.key === "Escape") closeSheet();
  if (event.key !== "Tab") return;
  const items = $$("#bottomSheet " + focusable.split(", ").join(", #bottomSheet "));
  const first = items[0];
  const last = items.at(-1);
  if (event.shiftKey && (document.activeElement === first || document.activeElement === $("#bottomSheet"))) {
    event.preventDefault(); last?.focus();
  } else if (!event.shiftKey && (document.activeElement === last || document.activeElement === $("#bottomSheet"))) {
    event.preventDefault(); first?.focus();
  }
});

function elapsedSeconds() {
  return state.startedAt === null ? 0 : Math.max(0, Math.floor((Date.now() - state.startedAt) / 1000));
}

function position() {
  return route.getPointAtLength(routeLength * Math.min(elapsedSeconds() / 600, 1));
}

function renderMap() {
  $("#mapWorld").setAttribute("transform", `translate(${state.pan.x} ${state.pan.y}) translate(300 560) rotate(${state.angle}) scale(${state.zoom}) translate(-300 -560)`);
  $$(".map-label").forEach((label) => {
    label.setAttribute("transform", `translate(${label.dataset.x} ${label.dataset.y}) rotate(${-state.angle})`);
  });
  $("#compassArrow").style.transform = `rotate(${state.angle}deg)`;
  $("#scaleLabel").textContent = `${Math.round(50 / state.zoom)} m`;
}

function render() {
  const recording = state.role !== null;
  const seconds = elapsedSeconds();
  const progress = Math.min(seconds / 600, 1);
  $("#idleCard").hidden = recording;
  $("#recordingCard").hidden = !recording;
  $("#recordingRole").textContent = state.role === "dog" ? "Chien · Nala" : "Traceur";
  $("#recordingTime").textContent = `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
  $("#recordingDistance").innerHTML = `${Math.round(progress * 720)} <em>m</em>`;
  route.toggleAttribute("hidden", !recording);
  route.style.stroke = state.role === "dog" ? "#27765b" : "#d48b47";
  route.style.strokeDasharray = `${routeLength} ${routeLength}`;
  route.style.strokeDashoffset = routeLength * (1 - progress);
  $("#referencePath").toggleAttribute("hidden", state.role !== "dog" || !state.reference);
  $("#traceLegend").hidden = state.role !== "dog";
  $("#accuracyRing").toggleAttribute("hidden", !state.accuracy);
  const point = position();
  $("#locationMarker").setAttribute("transform", `translate(${point.x} ${point.y})`);
  $("#sessionBadge").hidden = !state.session;
  $("#sessionBadgeLabel").textContent = state.session ?? "";
  $("#liveBadge").hidden = !recording || !state.session;
  $("#sessionNavDot").hidden = !state.session;
  $$("[data-scenario]").forEach((button) => button.setAttribute("aria-pressed", button.dataset.scenario === (state.role ?? "idle")));
}

function startRecording(role, demoSeconds = 0) {
  state.role = role;
  state.startedAt = Date.now() - demoSeconds * 1000;
  state.pan = { x: 0, y: 0 };
  closeSheet();
  renderMap();
  render();
}

function showStart() {
  showSheet("Un nouveau départ", `<p class="sheet-subtitle">Comment souhaitez-vous enregistrer cette trace ?</p>
    <form id="startForm"><div class="role-options">
      <label class="role-option">${icon("route")}<span class="role-copy"><strong>Traceur</strong><small>Poser une piste de référence</small></span><input type="radio" name="role" value="tracer" checked></label>
      <label class="role-option">${icon("paw")}<span class="role-copy"><strong>Chien</strong><small>Enregistrer la recherche avec Nala</small></span><input type="radio" name="role" value="dog"></label>
    </div><p class="sheet-info">${icon("signal")}L’enregistrement continue écran éteint.</p>
    <button class="primary-button" type="submit">Démarrer l’enregistrement ${icon("arrow")}</button></form>`);
  $("#startForm").addEventListener("submit", (event) => {
    event.preventDefault();
    startRecording(new FormData(event.target).get("role"));
    notify(state.session ? "Enregistrement démarré · live actif dans la session." : "Enregistrement démarré.");
  });
}

function stopRecording() {
  const seconds = elapsedSeconds();
  if (seconds >= 5) {
    const isDog = state.role === "dog";
    const distance = Math.round(Math.min(seconds / 600, 1) * 720);
    state.tracks.unshift({ name: isDog ? "Recherche avec Nala" : "Nouvelle piste des Pins", detail: `${isDog ? "Nala · Traceur + chien" : "Traceur"} · ${distance} m · À l’instant` });
  }
  const message = seconds < 5 ? "Trace de moins de 5 secondes : elle n’a pas été conservée." : state.session ? "Piste enregistrée · réception confirmée par l’organisateur." : "Votre piste a rejoint le carnet.";
  state.role = null;
  state.startedAt = null;
  render();
  notify(message);
}

function showLayers() {
  showSheet("Votre carte", `<p class="sheet-subtitle">Choisissez votre fond et les éléments affichés.</p>
    <div class="layer-options" role="radiogroup" aria-label="Fond de carte">
      ${[["classic", "Classique", ""], ["satellite", "Satellite", "satellite-thumb"], ["relief", "Relief 2D", "relief-thumb"]].map(([id, label, thumb]) => `<button class="layer-option" role="radio" aria-checked="${state.layer === id}" data-layer="${id}"><span class="layer-thumb ${thumb}"></span>${label}</button>`).join("")}
    </div><p class="sheet-info">Les fonds de cette maquette sont illustrés.</p>
    <label class="switch-row">Précision de ma position<input id="accuracySwitch" type="checkbox" ${state.accuracy ? "checked" : ""}></label>
    ${state.role === "dog" ? `<label class="switch-row">Traceur de référence<input id="referenceSwitch" type="checkbox" ${state.reference ? "checked" : ""}></label>` : ""}`);
  $$(".layer-option").forEach((button) => button.addEventListener("click", () => {
    state.layer = button.dataset.layer;
    $("#mapViewport").dataset.layer = state.layer;
    $$(".layer-option").forEach((option) => option.setAttribute("aria-checked", option === button));
  }));
  $("#accuracySwitch").addEventListener("change", (event) => { state.accuracy = event.target.checked; render(); });
  $("#referenceSwitch")?.addEventListener("change", (event) => { state.reference = event.target.checked; render(); });
}

function showNotebook() {
  showSheet("Votre carnet", `<p class="sheet-subtitle">Les départs passent. Les pistes restent.</p>
    <p class="list-count">${state.tracks.length} pistes dans le carnet</p><div class="track-list">${state.tracks.map((track) => `<div class="track-row">${icon("route")}<div><strong>${track.name}</strong><small>${track.detail}</small></div></div>`).join("")}</div>`);
}

function joinSession() {
  state.session = "Matinée aux Pins";
  closeSheet();
  render();
  notify(state.role ? "Session rejointe · votre enregistrement est maintenant en live." : "Session rejointe. Le live commencera avec votre enregistrement.");
}

function showSession() {
  if (state.session) {
    showSheet("Votre session", `<div class="session-card"><strong>Matinée aux Pins</strong><p>Organisée par Alex · Vous êtes participant</p><p>${state.role ? "Votre enregistrement est partagé en live avec l’organisateur." : "Vous êtes prêt. Démarrez une trace pour la partager en live."}</p></div>
      <p class="sheet-info">Quitter la session conserve votre enregistrement GPS local en cours.</p><button class="secondary-button leave-button" id="leaveSession">Quitter la session</button>`);
    $("#leaveSession").addEventListener("click", () => {
      state.session = null; closeSheet(); render();
      notify(state.role ? "Session quittée · le live est coupé, l’enregistrement continue." : "Vous avez quitté la session.");
    });
    return;
  }
  showSheet("Rejoindre une session", `<p class="sheet-subtitle">Retrouvez votre groupe, puis partez sur la piste.</p>
    <label class="field-label" for="sessionCode">Code de la session</label><form class="code-form" id="codeForm"><input id="sessionCode" name="code" placeholder="Ex. PINS24" minlength="4" maxlength="8" pattern="[A-Za-z0-9]{4,8}" autocomplete="off" required><button type="submit">Rejoindre</button></form>
    <p class="section-label">À PROXIMITÉ</p><div class="session-card"><strong>Matinée aux Pins</strong><p>Alex · À 280 m</p><button class="secondary-button" id="joinNearby">Rejoindre cette session</button></div>`);
  $("#codeForm").addEventListener("submit", (event) => { event.preventDefault(); joinSession(); });
  $("#joinNearby").addEventListener("click", joinSession);
}

$("#newTrackButton").addEventListener("click", showStart);
$("#stopButton").addEventListener("click", stopRecording);
$("#layersButton").addEventListener("click", showLayers);
$("#sessionBadge").addEventListener("click", showSession);
$("#profileButton").addEventListener("click", () => showSheet("Votre espace", `<div class="profile-info"><span class="avatar">CL</span><div><h3>Camille Laurent</h3><p>Compte Premium</p></div></div><div class="profile-detail"><span>Votre chien</span><strong>Nala</strong></div><div class="profile-detail"><span>Votre carnet</span><strong>${state.tracks.length} pistes</strong></div>`));
$("#northButton").addEventListener("click", () => { state.angle = 0; renderMap(); notify("La carte est orientée vers le nord."); });

function centerMap() {
  const point = position();
  const angle = state.angle * Math.PI / 180;
  const x = (point.x - 300) * state.zoom;
  const y = (point.y - 560) * state.zoom;
  state.pan.x = -(x * Math.cos(angle) - y * Math.sin(angle));
  state.pan.y = 486 - 560 - (x * Math.sin(angle) + y * Math.cos(angle));
  renderMap();
}
$("#centerButton").addEventListener("click", () => { centerMap(); notify("Carte centrée sur votre position."); });
const navActions = { map: closeSheet, notebook: showNotebook, session: showSession };
$$('[data-nav]').forEach((button) => button.addEventListener("click", () => navActions[button.dataset.nav]()));

$$('[data-device]').forEach((button) => button.addEventListener("click", () => {
  const compact = button.dataset.device === "compact";
  document.documentElement.style.setProperty("--phone-width", compact ? "360px" : "390px");
  document.documentElement.style.setProperty("--phone-height", compact ? "780px" : "844px");
  $$('[data-device]').forEach((option) => option.setAttribute("aria-pressed", option === button));
  fitPreview();
}));
$$('[data-scenario]').forEach((button) => button.addEventListener("click", () => {
  if (button.dataset.scenario !== "idle") return startRecording(button.dataset.scenario, 96);
  state.role = null; state.startedAt = null; state.session = null;
  state.angle = 0; state.zoom = 1; state.pan = { x: 0, y: 0 };
  closeSheet(); render(); renderMap();
}));

// La géométrie et ses libellés partagent le déplacement ; les libellés compensent la rotation.
const mapViewport = $("#mapViewport");
const pointers = new Map();
function mapPoint(event) {
  const bounds = $("#mapSvg").getBoundingClientRect();
  const scale = Math.max(bounds.width / 600, bounds.height / 1120);
  return { x: event.clientX / scale, y: event.clientY / scale };
}
mapViewport.addEventListener("pointerdown", (event) => {
  pointers.set(event.pointerId, mapPoint(event));
  mapViewport.setPointerCapture(event.pointerId);
});
mapViewport.addEventListener("pointermove", (event) => {
  const previous = pointers.get(event.pointerId);
  if (!previous) return;
  const point = mapPoint(event);
  if (pointers.size === 1) {
    if (event.shiftKey) state.angle += (point.x - previous.x) * .4;
    else { state.pan.x += point.x - previous.x; state.pan.y += point.y - previous.y; }
  } else {
    const other = [...pointers.entries()].find(([id]) => id !== event.pointerId)[1];
    const oldDistance = Math.hypot(previous.x - other.x, previous.y - other.y);
    const newDistance = Math.hypot(point.x - other.x, point.y - other.y);
    if (oldDistance > 5) state.zoom = Math.max(.8, Math.min(2.8, state.zoom * newDistance / oldDistance));
    const oldAngle = Math.atan2(previous.y - other.y, previous.x - other.x);
    const newAngle = Math.atan2(point.y - other.y, point.x - other.x);
    const delta = Math.atan2(Math.sin(newAngle - oldAngle), Math.cos(newAngle - oldAngle));
    state.angle += delta * 180 / Math.PI;
  }
  pointers.set(event.pointerId, point); renderMap();
});
["pointerup", "pointercancel", "lostpointercapture"].forEach((name) => mapViewport.addEventListener(name, (event) => pointers.delete(event.pointerId)));
mapViewport.addEventListener("wheel", (event) => {
  event.preventDefault(); state.zoom = Math.max(.8, Math.min(2.8, state.zoom * (event.deltaY < 0 ? 1.1 : 1 / 1.1))); renderMap();
}, { passive: false });
mapViewport.addEventListener("keydown", (event) => {
  const actions = {
    ArrowLeft: () => state.pan.x += 25, ArrowRight: () => state.pan.x -= 25,
    ArrowUp: () => state.pan.y += 25, ArrowDown: () => state.pan.y -= 25,
    "+": () => state.zoom = Math.min(2.8, state.zoom * 1.1), "=": () => state.zoom = Math.min(2.8, state.zoom * 1.1),
    "-": () => state.zoom = Math.max(.8, state.zoom / 1.1),
    n: () => state.angle = 0, N: () => state.angle = 0, Home: centerMap,
  };
  if (!actions[event.key]) return;
  event.preventDefault(); actions[event.key](); renderMap();
});

function fitPreview() {
  const height = parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--phone-height"));
  const scale = window.innerWidth <= 620 ? 1 : Math.min(1, Math.max(350, window.innerHeight - 88) / (height + 18));
  document.documentElement.style.setProperty("--preview-scale", scale);
}
window.addEventListener("resize", fitPreview);
setInterval(() => { if (state.role) render(); }, 1000);
fitPreview();
renderMap();
render();
