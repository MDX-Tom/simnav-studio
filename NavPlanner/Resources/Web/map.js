const API_ROOT = "navplanner://api";
const canvas = document.querySelector("#mapCanvas");
const statusEl = document.querySelector("#mapStatus");
const popupEl = document.querySelector("#popup");
const zoomInButton = document.querySelector("#zoomInButton");
const zoomOutButton = document.querySelector("#zoomOutButton");
const ctx = canvas.getContext("2d");
const TILE_SIZE = 256;

const state = {
  center: { lat: 28.6, lon: 104.0 },
  zoom: 4.2,
  dragging: false,
  dragStart: null,
  overlay: emptyOverlay(),
  procedure: null,
  header: null,
  offlineStatus: null,
  overlayAbort: null,
  overlayTimer: 0,
  renderFrame: 0,
};

function emptyOverlay() {
  return { airports: [], airways: [], waypoints: [], navaids: [], runways: [], ils: [] };
}

function postEvent(type, payload = {}) {
  window.webkit?.messageHandlers?.navplanner?.postMessage({ type, payload });
}

function scaleForZoom(zoom = state.zoom) {
  return TILE_SIZE * Math.pow(2, zoom);
}

function project(lat, lon, zoom = state.zoom) {
  const scale = scaleForZoom(zoom);
  const sinLat = Math.sin((Math.max(-85.0511, Math.min(85.0511, lat)) * Math.PI) / 180);
  return {
    x: ((lon + 180) / 360) * scale,
    y: (0.5 - Math.log((1 + sinLat) / (1 - sinLat)) / (4 * Math.PI)) * scale,
  };
}

function unproject(x, y, zoom = state.zoom) {
  const scale = scaleForZoom(zoom);
  const lon = (x / scale) * 360 - 180;
  const n = Math.PI - (2 * Math.PI * y) / scale;
  const lat = (180 / Math.PI) * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
  return { lat, lon: normalizeLon(lon) };
}

function normalizeLon(lon) {
  return ((((lon + 180) % 360) + 360) % 360) - 180;
}

function canvasSize() {
  return {
    width: canvas.clientWidth,
    height: canvas.clientHeight,
    ratio: window.devicePixelRatio || 1,
  };
}

function resizeCanvas() {
  const { width, height, ratio } = canvasSize();
  canvas.width = Math.max(1, Math.floor(width * ratio));
  canvas.height = Math.max(1, Math.floor(height * ratio));
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  scheduleRender();
  scheduleOverlay();
}

function centerWorld() {
  return project(state.center.lat, state.center.lon);
}

function screenPoint(lat, lon) {
  const { width, height } = canvasSize();
  const center = centerWorld();
  const world = scaleForZoom();
  const point = project(lat, lon);
  let x = point.x;
  while (x - center.x > world / 2) x -= world;
  while (x - center.x < -world / 2) x += world;
  return {
    x: x - center.x + width / 2,
    y: point.y - center.y + height / 2,
  };
}

function currentBounds() {
  const { width, height } = canvasSize();
  const center = centerWorld();
  const nw = unproject(center.x - width / 2, center.y - height / 2);
  const se = unproject(center.x + width / 2, center.y + height / 2);
  return {
    south: se.lat,
    west: nw.lon,
    north: nw.lat,
    east: se.lon,
  };
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`请求失败 ${response.status}`);
  }
  return response.json();
}

async function bootstrap() {
  try {
    const [header, offlineStatus] = await Promise.all([
      fetchJson(`${API_ROOT}/header`),
      fetchJson(`${API_ROOT}/offline-maps`),
    ]);
    state.header = header;
    state.offlineStatus = offlineStatus;
    const airac = header.current_airac || header.version || "未知周期";
    const resourceCount = offlineStatus.resources?.length || 0;
    statusEl.textContent = `AIRAC ${airac} · 离线地图资源 ${resourceCount} 个`;
  } catch (error) {
    statusEl.textContent = `本地数据读取失败：${error.message}`;
  }
  postEvent("mapReady");
  scheduleOverlay();
}

function scheduleOverlay() {
  window.clearTimeout(state.overlayTimer);
  state.overlayTimer = window.setTimeout(loadOverlay, 130);
}

async function loadOverlay() {
  state.overlayAbort?.abort();
  const controller = new AbortController();
  state.overlayAbort = controller;
  const bounds = currentBounds();
  const params = new URLSearchParams({
    south: String(bounds.south),
    west: String(bounds.west),
    north: String(bounds.north),
    east: String(bounds.east),
    zoom: String(Math.round(state.zoom)),
  });
  try {
    state.overlay = await fetchJson(`${API_ROOT}/nav-overlay?${params.toString()}`, { signal: controller.signal });
    statusEl.textContent = `缩放 ${state.zoom.toFixed(1)} · 机场 ${state.overlay.airports?.length || 0} · 航路 ${state.overlay.airways?.length || 0}`;
    scheduleRender();
  } catch (error) {
    if (error.name !== "AbortError") {
      statusEl.textContent = `叠加层读取失败：${error.message}`;
    }
  }
}

function scheduleRender() {
  if (state.renderFrame) return;
  state.renderFrame = requestAnimationFrame(() => {
    state.renderFrame = 0;
    draw();
  });
}

function draw() {
  const { width, height } = canvasSize();
  ctx.clearRect(0, 0, width, height);
  drawBaseMap(width, height);
  drawAirways();
  drawRunways();
  drawProcedure();
  drawPoints(state.overlay.navaids || [], "#85d3ff", 3.7);
  drawPoints(state.overlay.waypoints || [], "#d6f6a6", 2.6);
  drawAirports();
}

function drawBaseMap(width, height) {
  const gradient = ctx.createLinearGradient(0, 0, 0, height);
  gradient.addColorStop(0, "#14262e");
  gradient.addColorStop(1, "#0d171c");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  ctx.save();
  ctx.strokeStyle = "rgba(168, 224, 219, 0.11)";
  ctx.lineWidth = 1;
  for (let lon = -180; lon <= 180; lon += 10) {
    const a = screenPoint(-80, lon);
    const b = screenPoint(80, lon);
    drawWrappedLine(a, b);
  }
  for (let lat = -80; lat <= 80; lat += 10) {
    const left = screenPoint(lat, -180);
    const right = screenPoint(lat, 180);
    drawWrappedLine(left, right);
  }
  ctx.restore();
}

function drawWrappedLine(a, b) {
  const { width } = canvasSize();
  ctx.beginPath();
  ctx.moveTo(a.x, a.y);
  let endX = b.x;
  if (endX - a.x > width / 2) endX -= width;
  if (endX - a.x < -width / 2) endX += width;
  ctx.lineTo(endX, b.y);
  ctx.stroke();
}

function drawAirways() {
  ctx.save();
  ctx.strokeStyle = "rgba(78, 191, 178, 0.48)";
  ctx.lineWidth = Math.max(0.8, state.zoom / 4);
  for (const airway of state.overlay.airways || []) {
    drawPath(airway.path, false);
  }
  ctx.restore();
}

function drawRunways() {
  ctx.save();
  ctx.strokeStyle = "rgba(247, 244, 211, 0.82)";
  ctx.lineWidth = 2.4;
  for (const runway of state.overlay.runways || []) {
    drawPath(runway.path, false);
  }
  ctx.restore();
}

function drawProcedure() {
  if (!state.procedure) return;
  const color = state.procedure.type === "approach" ? "#b76dff" : state.procedure.type === "star" ? "#ffb75f" : "#42d8ff";
  ctx.save();
  ctx.strokeStyle = color;
  ctx.lineWidth = 3.2;
  ctx.shadowColor = color;
  ctx.shadowBlur = 10;
  drawPath((state.procedure.payload.primary_path?.length ? state.procedure.payload.primary_path : state.procedure.payload.path) || [], true);
  if (state.procedure.payload.missed_path?.length) {
    ctx.setLineDash([7, 7]);
    drawPath(state.procedure.payload.missed_path, true);
  }
  ctx.restore();
}

function drawPath(path, objects) {
  if (!Array.isArray(path) || path.length < 2) return;
  ctx.beginPath();
  path.forEach((item, index) => {
    const lat = objects ? item.lat : item[0];
    const lon = objects ? item.lon : item[1];
    const p = screenPoint(lat, lon);
    if (index === 0) {
      ctx.moveTo(p.x, p.y);
    } else {
      ctx.lineTo(p.x, p.y);
    }
  });
  ctx.stroke();
}

function drawPoints(points, color, radius) {
  ctx.save();
  ctx.fillStyle = color;
  ctx.strokeStyle = "rgba(6, 20, 23, 0.9)";
  ctx.lineWidth = 1.2;
  for (const point of points) {
    const p = screenPoint(Number(point.lat), Number(point.lon));
    if (!isPointVisible(p)) continue;
    ctx.beginPath();
    ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  }
  ctx.restore();
}

function drawAirports() {
  ctx.save();
  for (const airport of state.overlay.airports || []) {
    const p = screenPoint(Number(airport.lat), Number(airport.lon));
    if (!isPointVisible(p)) continue;
    ctx.fillStyle = airport.iata ? "#fbf4c9" : "#eaf3ec";
    ctx.strokeStyle = "rgba(8, 18, 20, 0.95)";
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.rect(p.x - 4, p.y - 4, 8, 8);
    ctx.fill();
    ctx.stroke();
    if (state.zoom >= 7.5) {
      ctx.fillStyle = "rgba(244, 251, 248, 0.86)";
      ctx.font = "600 11px -apple-system, BlinkMacSystemFont, sans-serif";
      ctx.fillText(airport.ident, p.x + 7, p.y - 7);
    }
  }
  ctx.restore();
}

function isPointVisible(point) {
  const { width, height } = canvasSize();
  return point.x >= -40 && point.x <= width + 40 && point.y >= -40 && point.y <= height + 40;
}

function pointerToCanvas(event) {
  const rect = canvas.getBoundingClientRect();
  return { x: event.clientX - rect.left, y: event.clientY - rect.top };
}

canvas.addEventListener("pointerdown", (event) => {
  state.dragging = true;
  state.dragStart = {
    pointer: pointerToCanvas(event),
    center: centerWorld(),
  };
  canvas.setPointerCapture(event.pointerId);
  popupEl.classList.add("hidden");
});

canvas.addEventListener("pointermove", (event) => {
  if (!state.dragging || !state.dragStart) return;
  const pointer = pointerToCanvas(event);
  const dx = pointer.x - state.dragStart.pointer.x;
  const dy = pointer.y - state.dragStart.pointer.y;
  state.center = unproject(state.dragStart.center.x - dx, state.dragStart.center.y - dy);
  scheduleRender();
  scheduleOverlay();
});

canvas.addEventListener("pointerup", (event) => {
  const moved = state.dragStart ? Math.hypot(pointerToCanvas(event).x - state.dragStart.pointer.x, pointerToCanvas(event).y - state.dragStart.pointer.y) : 0;
  state.dragging = false;
  state.dragStart = null;
  if (moved < 8) {
    handleMapClick(pointerToCanvas(event));
  }
});

canvas.addEventListener("pointercancel", () => {
  state.dragging = false;
  state.dragStart = null;
});

zoomInButton.addEventListener("click", () => setZoom(state.zoom + 0.75));
zoomOutButton.addEventListener("click", () => setZoom(state.zoom - 0.75));

function setZoom(zoom) {
  state.zoom = Math.max(2, Math.min(13.5, zoom));
  scheduleRender();
  scheduleOverlay();
}

function handleMapClick(pointer) {
  const hit = nearestPoint(pointer);
  if (!hit) {
    popupEl.classList.add("hidden");
    return;
  }
  showPopup(hit);
}

function nearestPoint(pointer) {
  const candidates = [
    ...(state.overlay.airports || []),
    ...(state.overlay.navaids || []),
    ...(state.overlay.waypoints || []),
  ];
  let best = null;
  let bestDistance = 18;
  for (const item of candidates) {
    const p = screenPoint(Number(item.lat), Number(item.lon));
    const distance = Math.hypot(pointer.x - p.x, pointer.y - p.y);
    if (distance < bestDistance) {
      bestDistance = distance;
      best = item;
    }
  }
  return best;
}

function showPopup(point) {
  const kind = point.kind || (point.iata !== undefined ? "airport" : "waypoint");
  postEvent(kind === "airport" ? "airportSelected" : "pointSelected", point);
  popupEl.classList.remove("hidden");
  popupEl.innerHTML = `
    <header class="popup-head">
      <div>
        <div class="popup-kicker">${escapeHtml(localizedKind(kind))}</div>
        <div class="popup-title">${escapeHtml(point.ident || "")}</div>
        <div class="popup-subtitle">${escapeHtml(point.name || "")}</div>
      </div>
      <button class="popup-close" type="button" aria-label="关闭">×</button>
    </header>
    <div class="popup-body">
      <div class="popup-row"><span>区域</span><strong>${escapeHtml(point.area_code || point.region || "--")}</strong></div>
      <div class="popup-row"><span>坐标</span><strong>${Number(point.lat).toFixed(4)}, ${Number(point.lon).toFixed(4)}</strong></div>
      ${kind === "airport" ? `<div id="airportExtra">正在读取机场详情...</div>` : ""}
    </div>
  `;
  popupEl.querySelector(".popup-close")?.addEventListener("click", () => popupEl.classList.add("hidden"));
  if (kind === "airport") {
    loadAirportExtra(point.ident);
  }
}

async function loadAirportExtra(ident) {
  const extra = popupEl.querySelector("#airportExtra");
  if (!extra) return;
  try {
    const payload = await fetchJson(`${API_ROOT}/airport/${encodeURIComponent(ident)}`);
    const runways = payload.runways || [];
    const procedures = payload.procedures || {};
    extra.innerHTML = `
      <div class="popup-row"><span>跑道</span><strong>${runways.length}</strong></div>
      ${procedureGroupHtml("SID", "sid", procedures.sid || [], ident)}
      ${procedureGroupHtml("STAR", "star", procedures.star || [], ident)}
      ${procedureGroupHtml("APPROACH", "approach", procedures.approach || [], ident)}
    `;
    extra.querySelectorAll("[data-procedure]").forEach((button) => {
      button.addEventListener("click", () => previewProcedure(button.dataset));
    });
  } catch (error) {
    extra.textContent = `机场详情读取失败：${error.message}`;
  }
}

function procedureGroupHtml(title, type, items, airport) {
  const buttons = items.slice(0, 10).map((item) => {
    const procedure = item.procedure_identifier || "";
    const transition = item.transition_identifier || "ALL";
    return `<button class="${type}" type="button" data-procedure="${escapeHtml(procedure)}" data-transition="${escapeHtml(transition)}" data-type="${type}" data-airport="${escapeHtml(airport)}">${escapeHtml(procedure)} ${escapeHtml(transition)}</button>`;
  }).join("");
  return `
    <div class="procedure-group">
      <div class="procedure-title">${title} ${items.length}</div>
      <div class="procedure-buttons">${buttons || "<span class='popup-subtitle'>无数据</span>"}</div>
    </div>
  `;
}

async function previewProcedure(dataset) {
  const type = dataset.type;
  const airport = dataset.airport;
  const procedure = dataset.procedure;
  const transition = dataset.transition || "ALL";
  try {
    const payload = await fetchJson(`${API_ROOT}/procedure/${type}/${encodeURIComponent(airport)}/${encodeURIComponent(procedure)}/${encodeURIComponent(transition)}`);
    state.procedure = { type, payload };
    statusEl.textContent = `${type.toUpperCase()} ${procedure}/${transition} 已绘制`;
    scheduleRender();
  } catch (error) {
    statusEl.textContent = `Procedure 读取失败：${error.message}`;
  }
}

function localizedKind(kind) {
  if (kind === "airport") return "机场";
  if (kind === "vor") return "VOR";
  if (kind === "ndb") return "NDB";
  return "航点";
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[char]));
}

window.addEventListener("resize", resizeCanvas);
resizeCanvas();
bootstrap();

window.navplannerMap = {
  focus(lat, lon, zoom = state.zoom) {
    state.center = { lat: Number(lat), lon: Number(lon) };
    state.zoom = Math.max(2, Math.min(13.5, Number(zoom)));
    scheduleRender();
    scheduleOverlay();
  },
};

