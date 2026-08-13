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
      accept: ".gpx,.csv,.kml,application/gpx+xml,application/vnd.google-earth.kml+xml,application/xml,text/xml,text/csv",
      types: [{
        description: "Flight track (GPX, FR24 CSV, or KML)",
        accept: {
          "application/octet-stream": [".gpx", ".csv", ".kml"],
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

  function parseCSVRows(data) {
    const rows = [];
    let row = [];
    let field = "";
    let quoted = false;
    for (let index = 0; index < data.length; index += 1) {
      const character = data[index];
      if (quoted) {
        if (character === '"' && data[index + 1] === '"') {
          field += '"';
          index += 1;
        } else if (character === '"') {
          quoted = false;
        } else {
          field += character;
        }
      } else if (character === '"') {
        quoted = true;
      } else if (character === ",") {
        row.push(field.trim());
        field = "";
      } else if (character === "\n" || character === "\r") {
        if (character === "\r" && data[index + 1] === "\n") {
          index += 1;
        }
        row.push(field.trim());
        if (row.some(Boolean)) {
          rows.push(row);
        }
        row = [];
        field = "";
      } else {
        field += character;
      }
    }
    row.push(field.trim());
    if (row.some(Boolean)) {
      rows.push(row);
    }
    return rows;
  }

  function parseFR24CSV(data, filename = "fr24-track.csv") {
    const rows = parseCSVRows(String(data || "").replace(/^\uFEFF/, ""));
    if (rows.length < 2) {
      throw new Error("The FR24 CSV file does not contain enough rows.");
    }
    const normalizedHeader = rows[0].map((value) => value.toLowerCase().replace(/[^a-z0-9]+/g, ""));
    const headerIndex = (...names) => normalizedHeader.findIndex((value) => names.includes(value));
    const timestampIndex = headerIndex("timestamp", "time", "datetime");
    const positionIndex = headerIndex("position", "latlon", "coordinates", "coordinate");
    const latitudeIndex = headerIndex("latitude", "lat");
    const longitudeIndex = headerIndex("longitude", "lon", "lng", "long");
    const altitudeIndex = headerIndex("altitude", "altitudefeet", "altitudeft", "alt");
    const speedIndex = headerIndex("speed", "groundspeed", "speedknots", "speedkt", "speedkts");
    const hasNamedHeader = timestampIndex >= 0
      || positionIndex >= 0
      || (latitudeIndex >= 0 && longitudeIndex >= 0);
    const dataRows = hasNamedHeader ? rows.slice(1) : rows;
    const points = dataRows.flatMap((columns) => {
      let lat;
      let lon;
      if (latitudeIndex >= 0 && longitudeIndex >= 0) {
        lat = Number(columns[latitudeIndex]);
        lon = Number(columns[longitudeIndex]);
      } else {
        const position = columns[positionIndex >= 0 ? positionIndex : 2] || "";
        const coordinates = position.match(/-?\d+(?:\.\d+)?/g) || [];
        lat = Number(coordinates[0]);
        lon = Number(coordinates[1]);
      }
      if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
        return [];
      }
      const point = { lat, lon };
      const rawTimestamp = columns[timestampIndex >= 0 ? timestampIndex : 0];
      const numericTimestamp = Number(rawTimestamp);
      const parsedTimestamp = Number.isFinite(numericTimestamp)
        ? numericTimestamp
        : Date.parse(rawTimestamp || "") / 1000;
      if (Number.isFinite(parsedTimestamp)) {
        point.timestamp = Math.floor(parsedTimestamp > 1e12 ? parsedTimestamp / 1000 : parsedTimestamp);
      }
      const altitude = Number(columns[altitudeIndex >= 0 ? altitudeIndex : 3]);
      if (Number.isFinite(altitude)) {
        point.altitude = altitude;
        point.altitude_ft = altitude;
      }
      const speed = Number(columns[speedIndex >= 0 ? speedIndex : 4]);
      if (Number.isFinite(speed)) {
        point.speed = speed;
        point.speed_kt = speed;
      }
      return [point];
    });
    if (points.length < 2) {
      throw new Error("The FR24 CSV file does not contain enough valid track points.");
    }
    return {
      filename,
      track_points: points,
      track_point_count: points.length,
      source_format: "fr24_csv",
      message: "FR24 CSV track imported.",
    };
  }

  function parseKML(data, filename = "fr24-track.kml") {
    const documentNode = new DOMParser().parseFromString(data, "application/xml");
    if (documentNode.querySelector("parsererror")) {
      throw new Error("KML XML could not be parsed.");
    }
    const candidates = [];
    const trackNodes = Array.from(documentNode.getElementsByTagNameNS("*", "Track"));
    trackNodes.forEach((trackNode) => {
      const times = Array.from(trackNode.getElementsByTagNameNS("*", "when"))
        .map((node) => Date.parse(String(node.textContent || "").trim()))
        .map((value) => Number.isFinite(value) ? Math.floor(value / 1000) : null);
      const points = Array.from(trackNode.getElementsByTagNameNS("*", "coord")).flatMap((node, index) => {
        const values = String(node.textContent || "").trim().split(/\s+/).map(Number);
        const [lon, lat, altitudeMeters] = values;
        if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
          return [];
        }
        const point = { lat, lon };
        if (Number.isFinite(altitudeMeters)) {
          point.altitude_m = altitudeMeters;
          point.altitude_ft = altitudeMeters * 3.280839895;
          point.altitude = point.altitude_ft;
        }
        if (Number.isFinite(times[index])) {
          point.timestamp = times[index];
        }
        return [point];
      });
      if (points.length >= 2) {
        candidates.push(points);
      }
    });
    Array.from(documentNode.getElementsByTagNameNS("*", "coordinates")).forEach((node) => {
      const points = String(node.textContent || "").trim().split(/\s+/).flatMap((token) => {
        const [lon, lat, altitudeMeters] = token.split(",").map(Number);
        if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
          return [];
        }
        const point = { lat, lon };
        if (Number.isFinite(altitudeMeters)) {
          point.altitude_m = altitudeMeters;
          point.altitude_ft = altitudeMeters * 3.280839895;
          point.altitude = point.altitude_ft;
        }
        return [point];
      });
      if (points.length >= 2) {
        candidates.push(points);
      }
    });
    const points = candidates.sort((left, right) => right.length - left.length)[0] || [];
    if (points.length < 2) {
      throw new Error("The KML file does not contain enough valid track points.");
    }
    return {
      filename,
      track_points: points,
      track_point_count: points.length,
      source_format: "kml",
      message: "KML track imported.",
    };
  }

  function parseFlightTrack(data, filename = "track.gpx") {
    const extension = String(filename).split(".").pop()?.toLowerCase();
    if (extension === "csv") {
      return parseFR24CSV(data, filename);
    }
    if (extension === "kml") {
      return parseKML(data, filename);
    }
    return parseGPX(data, filename);
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
    return parseFlightTrack(await file.text(), file.name);
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

  async function openFR24Verification() {
    if (isWebKit()) {
      postEvent("openFR24Verification");
      return { pending_native: true };
    }
    return responseJSON(await fetch("/api/fr24/browser/open", authorizeFetchOptions({
      method: "POST",
    })));
  }

  async function syncFR24Session() {
    if (isWebKit()) {
      postEvent("syncFR24Session");
      return { pending_native: true };
    }
    return responseJSON(await fetch("/api/fr24/browser/sync", authorizeFetchOptions({
      method: "POST",
    })));
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
    fr24BrowserCookieSync: true,
    fr24ManagedBrowserSession: !isWebKit(),
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
    parseFR24CSV,
    parseKML,
    parseFlightTrack,
    setAppIcon,
    openFR24Verification,
    syncFR24Session,
    openFR24CacheDirectory,
    shareFile,
    download,
  });
})();
