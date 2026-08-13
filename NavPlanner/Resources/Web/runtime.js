(() => {
  "use strict";

  const webKitHandler = () => window.webkit?.messageHandlers?.navplanner ?? null;
  const isWebKit = () => Boolean(webKitHandler());
  const isHTTP = () => window.location.protocol === "http:" || window.location.protocol === "https:";
  const unsafeMethods = new Set(["POST", "PUT", "PATCH", "DELETE"]);

  function writeToken() {
    const token = document.querySelector('meta[name="simnav-write-token"]')?.content || "";
    return token === "__SIMNAV_WRITE_TOKEN__" ? "" : token;
  }

  function authorizeFetchOptions(options = {}) {
    const authorized = { ...options };
    const method = String(authorized.method || "GET").toUpperCase();
    const token = writeToken();
    if (token && unsafeMethods.has(method)) {
      const headers = new Headers(authorized.headers || {});
      headers.set("X-SimNav-Token", token);
      authorized.headers = headers;
    }
    return authorized;
  }

  function postEvent(type, payload = {}) {
    const handler = webKitHandler();
    if (handler) {
      handler.postMessage({ type, payload });
      return true;
    }
    window.dispatchEvent(new CustomEvent("simnav-runtime-event", {
      detail: { type, payload },
    }));
    if (type === "runtimeDiagnostic") {
      const level = payload.level === "error" ? "error" : "warn";
      console[level](payload.message || "SimNav runtime diagnostic", payload);
    }
    return false;
  }

  function filePickerTypes(kind) {
    if (kind === "database") {
      return {
        accept: ".s3db,.sqlite,.sqlite3,.db,application/vnd.sqlite3,application/octet-stream",
        types: [{
          description: "SQLite navigation database",
          accept: {
            "application/octet-stream": [".s3db", ".sqlite", ".sqlite3", ".db"],
          },
        }],
      };
    }
    if (kind === "offline-map") {
      return {
        accept: ".pmtiles,.mbtiles,.sqlite,.sqlite3,application/vnd.sqlite3,application/octet-stream",
        types: [{
          description: "Offline map package",
          accept: {
            "application/octet-stream": [".pmtiles", ".mbtiles", ".sqlite", ".sqlite3"],
          },
        }],
      };
    }
    return {
      accept: ".gpx,application/gpx+xml,application/xml,text/xml",
      types: [{
        description: "GPX track",
        accept: {
          "application/gpx+xml": [".gpx"],
        },
      }],
    };
  }

  async function chooseFile(kind) {
    const picker = filePickerTypes(kind);
    return new Promise((resolve) => {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = picker.accept;
      input.hidden = true;
      document.body.appendChild(input);
      let settled = false;
      const finish = (file) => {
        if (settled) {
          return;
        }
        settled = true;
        window.removeEventListener("focus", detectCancellation, true);
        input.remove();
        resolve(file || null);
      };
      const detectCancellation = () => {
        window.setTimeout(() => finish(input.files?.[0] || null), 300);
      };
      input.addEventListener("change", () => finish(input.files?.[0] || null), { once: true });
      input.addEventListener("cancel", () => finish(null), { once: true });
      window.addEventListener("focus", detectCancellation, { once: true, capture: true });
      input.click();
    });
  }

  async function responseJSON(response) {
    let payload = {};
    try {
      payload = await response.json();
    } catch (_) {
      payload = {};
    }
    if (!response.ok) {
      throw new Error(payload.error || `HTTP ${response.status}`);
    }
    return payload;
  }

  async function selectDatabase() {
    if (isWebKit()) {
      postEvent("selectDatabase");
      return { pending_native: true };
    }
    if (!isHTTP()) {
      throw new Error("Database import requires the SimNav App or Local Web server.");
    }
    const file = await chooseFile("database");
    if (!file) {
      return { local_status: "cancelled", message: "Database selection cancelled." };
    }
    const response = await fetch("/api/databases/import", authorizeFetchOptions({
      method: "POST",
      headers: {
        "Content-Type": "application/octet-stream",
        "X-SimNav-Filename": encodeURIComponent(file.name),
      },
      body: file,
    }));
    return responseJSON(response);
  }

  async function importOfflineMap() {
    if (isWebKit()) {
      postEvent("importOfflineMap");
      return { pending_native: true };
    }
    if (!isHTTP()) {
      throw new Error("Offline map import requires the SimNav App or Local Web server.");
    }
    const file = await chooseFile("offline-map");
    if (!file) {
      return { local_status: "cancelled", message: "Offline map selection cancelled." };
    }
    const response = await fetch("/api/offline-maps/import", authorizeFetchOptions({
      method: "POST",
      headers: {
        "Content-Type": "application/octet-stream",
        "X-SimNav-Filename": encodeURIComponent(file.name),
      },
      body: file,
    }));
    return responseJSON(response);
  }

  function numericText(element) {
    const value = Number(String(element?.textContent || "").trim());
    return Number.isFinite(value) ? value : null;
  }

  function childElements(element) {
    return Array.from(element?.getElementsByTagName("*") || []);
  }

  function parseGPX(data, filename = "track.gpx") {
    const documentNode = new DOMParser().parseFromString(data, "application/xml");
    const parserError = documentNode.querySelector("parsererror");
    if (parserError) {
      throw new Error("GPX XML could not be parsed.");
    }
    const trackNodes = Array.from(documentNode.getElementsByTagNameNS("*", "trkpt"));
    const fallbackNodes = trackNodes.length
      ? trackNodes
      : Array.from(documentNode.getElementsByTagName("trkpt"));
    const trackPoints = fallbackNodes.flatMap((node) => {
      const lat = Number(node.getAttribute("lat"));
      const lon = Number(node.getAttribute("lon"));
      if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
        return [];
      }
      const point = { lat, lon };
      childElements(node).forEach((element) => {
        const name = String(element.localName || element.nodeName || "").toLowerCase();
        if (name === "ele") {
          const meters = numericText(element);
          if (meters !== null) {
            const feet = meters * 3.280839895;
            point.altitude_m = meters;
            point.altitude_ft = feet;
            point.altitude = feet;
          }
        } else if (name === "time") {
          const timestamp = Date.parse(String(element.textContent || "").trim());
          if (Number.isFinite(timestamp)) {
            point.timestamp = Math.floor(timestamp / 1000);
          }
        } else if (name.includes("altitude_ft")) {
          const feet = numericText(element);
          if (feet !== null) {
            point.altitude_ft = feet;
            point.altitude = feet;
          }
        } else if (name.includes("speed_kt") || name.includes("speed_knot")) {
          const knots = numericText(element);
          if (knots !== null) {
            point.speed_kt = knots;
            point.speed = knots;
          }
        } else if (name.includes("speed_mps") || name === "speed") {
          const metersPerSecond = numericText(element);
          if (metersPerSecond !== null) {
            const knots = metersPerSecond / 0.514444;
            point.speed_kt = knots;
            point.speed = knots;
          }
        }
      });
      return [point];
    });
    if (trackPoints.length < 2) {
      throw new Error("The GPX file does not contain enough track points.");
    }
    return {
      filename,
      track_points: trackPoints,
      track_point_count: trackPoints.length,
      message: "GPX track imported.",
    };
  }

  async function importFR24GPX() {
    if (isWebKit()) {
      postEvent("importFR24GPX");
      return { pending_native: true };
    }
    const file = await chooseFile("gpx");
    if (!file) {
      return { cancelled: true, filename: "" };
    }
    return parseGPX(await file.text(), file.name);
  }

  function setBrowserIcon(iconChoice) {
    const normalized = String(iconChoice || "style3-day-medium");
    let link = document.querySelector('link[data-simnav-runtime-icon="true"]');
    if (!link) {
      link = document.createElement("link");
      link.rel = "icon";
      link.dataset.simnavRuntimeIcon = "true";
      document.head.appendChild(link);
    }
    link.href = `/app-icons/${encodeURIComponent(normalized)}.png`;
    return normalized;
  }

  async function setAppIcon(iconChoice) {
    if (isWebKit()) {
      postEvent("setAppIcon", { iconChoice });
      return { pending_native: true };
    }
    const normalized = setBrowserIcon(iconChoice);
    return {
      icon_choice: normalized,
      browser_icon: true,
      message: "Browser tab icon updated; operating-system app icons are managed by the browser.",
    };
  }

  function openFR24Verification() {
    if (isWebKit()) {
      postEvent("openFR24Verification");
      return { pending_native: true };
    }
    const opened = window.open("https://www.flightradar24.com/", "_blank", "noopener,noreferrer");
    return {
      fallback: true,
      opened: Boolean(opened),
      message: "FR24 opened in a separate browser tab. SimNav does not copy browser cookies or bypass verification; use the optional manual session fields if authorized.",
    };
  }

  function syncFR24Session() {
    if (isWebKit()) {
      postEvent("syncFR24Session");
      return { pending_native: true };
    }
    return {
      unsupported: true,
      message: "Local Web cannot read cookies from another browser tab. SimNav does not bypass FR24 or Cloudflare verification.",
    };
  }

  function openFR24CacheDirectory() {
    if (isWebKit()) {
      postEvent("openFR24CacheDirectory");
      return { pending_native: true };
    }
    document.querySelector("#fr24CacheResults")?.scrollIntoView({ behavior: "smooth", block: "start" });
    return {
      browser_cache_list: true,
      message: "Local Web cache files are available from the cached-flight list using Download.",
    };
  }

  async function download(url, filename = "download") {
    const response = await fetch(url, authorizeFetchOptions());
    if (!response.ok) {
      let message = `HTTP ${response.status}`;
      try {
        message = (await response.json()).error || message;
      } catch (_) {
        // Keep the HTTP status when the endpoint is not JSON.
      }
      throw new Error(message);
    }
    const blob = await response.blob();
    const objectURL = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = objectURL;
    link.download = filename;
    link.rel = "noopener";
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(objectURL), 1_000);
    return { downloaded: true, filename };
  }

  async function shareFile({ path = "", title = "", downloadURL = "" } = {}) {
    if (isWebKit()) {
      postEvent("shareFile", { path, title });
      return { pending_native: true };
    }
    if (!downloadURL) {
      throw new Error("This Local Web file does not expose a safe download URL.");
    }
    return download(downloadURL, title || "simnav-download");
  }

  const capabilities = Object.freeze({
    mode: isWebKit() ? "webkit" : "http",
    databaseImport: isWebKit() || isHTTP(),
    offlineMapImport: isWebKit() || isHTTP(),
    gpxImport: true,
    browserFileDownload: !isWebKit(),
    nativeShare: isWebKit(),
    nativeAlternateIcon: isWebKit(),
    browserTabIcon: !isWebKit(),
    fr24EmbeddedVerification: isWebKit(),
    fr24BrowserCookieSync: isWebKit(),
    fr24CompliantFallback: !isWebKit(),
  });

  window.SimNavRuntime = Object.freeze({
    version: 1,
    capabilities,
    authorizeFetchOptions,
    postEvent,
    selectDatabase,
    importOfflineMap,
    importFR24GPX,
    parseGPX,
    setAppIcon,
    openFR24Verification,
    syncFR24Session,
    openFR24CacheDirectory,
    shareFile,
    download,
  });
})();
