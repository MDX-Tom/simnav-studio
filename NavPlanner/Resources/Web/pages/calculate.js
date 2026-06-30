const CALC_AIRCRAFT_CATALOG = Object.freeze({
  boeing: {
    label: { "zh-Hans": "波音", en: "Boeing" },
    aircraft: [
      { code: "B738", label: "737-800", econMach: 0.78, maxMach: 0.82, mtowKg: 79015, mlwKg: 66360, zfwKg: 62730, taxiKg: 230, baseFuelKgH: 2500, climbFuelKgH: 4300, descentFuelKgH: 1100, ceilingFt: 41000 },
      { code: "B789", label: "787-9", econMach: 0.85, maxMach: 0.90, mtowKg: 254011, mlwKg: 192776, zfwKg: 181437, taxiKg: 480, baseFuelKgH: 5600, climbFuelKgH: 9700, descentFuelKgH: 2300, ceilingFt: 43100 },
      { code: "B77W", label: "777-300ER", econMach: 0.84, maxMach: 0.89, mtowKg: 351534, mlwKg: 251290, zfwKg: 237682, taxiKg: 620, baseFuelKgH: 7600, climbFuelKgH: 12800, descentFuelKgH: 3100, ceilingFt: 43100 },
    ],
  },
  airbus: {
    label: { "zh-Hans": "空客", en: "Airbus" },
    aircraft: [
      { code: "A20N", label: "A320neo", econMach: 0.78, maxMach: 0.82, mtowKg: 79000, mlwKg: 67400, zfwKg: 64300, taxiKg: 210, baseFuelKgH: 2250, climbFuelKgH: 3950, descentFuelKgH: 950, ceilingFt: 39800 },
      { code: "A333", label: "A330-300", econMach: 0.82, maxMach: 0.86, mtowKg: 242000, mlwKg: 187000, zfwKg: 175000, taxiKg: 430, baseFuelKgH: 5800, climbFuelKgH: 9600, descentFuelKgH: 2400, ceilingFt: 41450 },
      { code: "A359", label: "A350-900", econMach: 0.85, maxMach: 0.89, mtowKg: 280000, mlwKg: 207000, zfwKg: 195700, taxiKg: 500, baseFuelKgH: 6100, climbFuelKgH: 10100, descentFuelKgH: 2500, ceilingFt: 43100 },
    ],
  },
  mcdonnell: {
    label: { "zh-Hans": "麦道", en: "McDonnell Douglas" },
    aircraft: [
      { code: "MD11", label: "MD-11", econMach: 0.82, maxMach: 0.87, mtowKg: 286000, mlwKg: 222900, zfwKg: 202300, taxiKg: 560, baseFuelKgH: 7700, climbFuelKgH: 12300, descentFuelKgH: 3200, ceilingFt: 43000 },
      { code: "MD82", label: "MD-82", econMach: 0.76, maxMach: 0.80, mtowKg: 67812, mlwKg: 58967, zfwKg: 55338, taxiKg: 210, baseFuelKgH: 2700, climbFuelKgH: 4200, descentFuelKgH: 1150, ceilingFt: 37000 },
    ],
  },
  comac: {
    label: { "zh-Hans": "COMAC", en: "COMAC" },
    aircraft: [
      { code: "C919", label: "C919", econMach: 0.78, maxMach: 0.82, mtowKg: 77300, mlwKg: 66600, zfwKg: 62500, taxiKg: 220, baseFuelKgH: 2350, climbFuelKgH: 4000, descentFuelKgH: 980, ceilingFt: 39800 },
      { code: "ARJ21", label: "ARJ21-700", econMach: 0.74, maxMach: 0.78, mtowKg: 43500, mlwKg: 40500, zfwKg: 37400, taxiKg: 150, baseFuelKgH: 1650, climbFuelKgH: 2850, descentFuelKgH: 720, ceilingFt: 39000 },
    ],
  },
});
const CALC_DEFAULT_MANUFACTURER = "boeing";
const CALC_DEFAULT_AIRCRAFT = "B738";
const CALC_WEATHER_SOURCE_LABELS = Object.freeze({
  noaa: "NOAA",
  ecmwf: "ECMWF",
  gfs: "GFS",
});
const CALC_WEATHER_SOURCE_KEYS = new Set(Object.keys(CALC_WEATHER_SOURCE_LABELS));
const CALC_LAYER_KEYS = new Set(["wind", "cloud", "rain"]);
const CALC_PROFILE_SAMPLE_NM = 42;
const CALC_MAX_PROFILE_POINTS = 160;
const CALC_ROUTE_SIGNATURE_LIMIT = 120;

export const CALCULATE_DEFAULTS = Object.freeze({
  manufacturer: CALC_DEFAULT_MANUFACTURER,
  aircraft: CALC_DEFAULT_AIRCRAFT,
  weatherSource: "noaa",
  layers: Object.freeze(Array.from(CALC_LAYER_KEYS)),
});

export function createCalculatePage(context) {
  const {
    state,
    elements,
    t,
    currentLanguage,
    escapeHtml,
    clampNumber,
    withDisplayLongitudes,
    normalizeLongitude,
    greatCircleDistanceNm,
    initialBearingDeg,
    procedureCacheKey,
    formatAltitudeRestriction,
    svgPathForProfile,
  } = context;

  function localizedCatalogLabel(label) {
    if (!label) {
      return "";
    }
    return label[currentLanguage()] || label["zh-Hans"] || label.en || "";
  }

  function calculateManufacturerKeys() {
    return Object.keys(CALC_AIRCRAFT_CATALOG);
  }

  function normalizeCalculateManufacturer(value) {
    return CALC_AIRCRAFT_CATALOG[value] ? value : CALC_DEFAULT_MANUFACTURER;
  }

  function calculateAircraftList(manufacturer = state.calculateManufacturer) {
    return CALC_AIRCRAFT_CATALOG[normalizeCalculateManufacturer(manufacturer)]?.aircraft || [];
  }

  function normalizeCalculateAircraft(value, manufacturer = state.calculateManufacturer) {
    const list = calculateAircraftList(manufacturer);
    return list.some((item) => item.code === value) ? value : (list[0]?.code || CALC_DEFAULT_AIRCRAFT);
  }

  function selectedCalculateAircraft() {
    return calculateAircraftList().find((item) => item.code === state.calculateAircraft)
      || CALC_AIRCRAFT_CATALOG[CALC_DEFAULT_MANUFACTURER].aircraft[0];
  }

  function formatMach(value) {
    const number = Number(value);
    return Number.isFinite(number) ? `M${number.toFixed(2)}` : "M--";
  }

  function formatFlightLevelFromFeet(value) {
    const feet = Number(value);
    if (!Number.isFinite(feet)) {
      return "FL---";
    }
    return `FL${Math.round(feet / 100)}`;
  }

  function formatSignedWindComponent(value) {
    const rounded = Math.round(Math.abs(value || 0));
    return value >= 0
      ? t("calculate.componentTail", { value: rounded })
      : t("calculate.componentHead", { value: rounded });
  }

  function formatFuelTime(minutes) {
    const rounded = Math.max(0, Math.round(Number(minutes) || 0));
    const hours = Math.floor(rounded / 60);
    const mins = rounded % 60;
    return `${String(hours).padStart(2, "0")}${String(mins).padStart(2, "0")}`;
  }

  function formatReadableDuration(minutes) {
    const rounded = Math.max(0, Math.round(Number(minutes) || 0));
    const hours = Math.floor(rounded / 60);
    const mins = rounded % 60;
    return hours > 0 ? `${hours}h ${mins}m` : `${mins}m`;
  }

  function calculateTicksHtml(min, max, interval, formatter) {
    const ticks = [];
    for (let value = min; value <= max + 0.1; value += interval) {
      const position = ((value - min) / Math.max(1, max - min)) * 100;
      ticks.push(`<span style="--tick-position: ${position.toFixed(3)}%;"><i></i><b>${escapeHtml(formatter(value))}</b></span>`);
    }
    return ticks.join("");
  }

  function syncCalculateAircraftControls({ resetMach = false } = {}) {
    const manufacturer = normalizeCalculateManufacturer(state.calculateManufacturer);
    state.calculateManufacturer = manufacturer;
    if (elements.calcManufacturerSelect) {
      elements.calcManufacturerSelect.innerHTML = calculateManufacturerKeys().map((key) => {
        const label = localizedCatalogLabel(CALC_AIRCRAFT_CATALOG[key].label);
        return `<option value="${escapeHtml(key)}"${key === manufacturer ? " selected" : ""}>${escapeHtml(label)}</option>`;
      }).join("");
    }

    const aircraftList = calculateAircraftList(manufacturer);
    state.calculateAircraft = normalizeCalculateAircraft(state.calculateAircraft, manufacturer);
    if (elements.calcAircraftSelect) {
      elements.calcAircraftSelect.innerHTML = aircraftList.map((aircraft) => (
        `<option value="${escapeHtml(aircraft.code)}"${aircraft.code === state.calculateAircraft ? " selected" : ""}>${escapeHtml(`${aircraft.label} (${aircraft.code})`)}</option>`
      )).join("");
    }

    const aircraft = selectedCalculateAircraft();
    if (resetMach || !Number.isFinite(state.calculateCruiseMach)) {
      state.calculateCruiseMach = aircraft.econMach;
    }
    state.calculateCruiseMach = clampNumber(state.calculateCruiseMach, 0.5, aircraft.maxMach);
    if (elements.calcCruiseMachInput) {
      elements.calcCruiseMachInput.max = aircraft.maxMach.toFixed(2);
      elements.calcCruiseMachInput.value = state.calculateCruiseMach.toFixed(2);
    }
    if (elements.calcCruiseMachTicks) {
      const max = Number(aircraft.maxMach.toFixed(2));
      elements.calcCruiseMachTicks.innerHTML = [
        { value: 0.5, label: "M0.50", role: "min" },
        { value: aircraft.econMach, label: `${formatMach(aircraft.econMach)} ECON`, role: "econ" },
        { value: max, label: `${formatMach(max)} MAX`, role: "max" },
      ].map((tick) => {
        const position = ((tick.value - 0.5) / Math.max(0.01, max - 0.5)) * 100;
        const clustered = tick.role === "econ" && (100 - position) < 18;
        return `<span data-tick-role="${tick.role}"${clustered ? " data-edge-cluster=\"true\"" : ""} style="--tick-position: ${position.toFixed(3)}%;"><i></i><b>${escapeHtml(tick.label)}</b></span>`;
      }).join("");
    }
  }

  function syncCalculateControls({ resetMach = false } = {}) {
    syncCalculateAircraftControls({ resetMach });
    const altitudeValue = Number(state.calculateCruiseAltitudeFt);
    const descentRateValue = Number(state.calculateDescentRateFpm);
    state.calculateCruiseAltitudeFt = clampNumber(Number.isFinite(altitudeValue) ? altitudeValue : 30000, 10000, 60000);
    state.calculateDescentRateFpm = clampNumber(Number.isFinite(descentRateValue) ? descentRateValue : 1500, 0, 4000);
    state.calculateProfileZoom = clampNumber(Number(state.calculateProfileZoom) || 1, 1, 4);
    if (elements.calcCruiseAltitudeInput) {
      elements.calcCruiseAltitudeInput.value = String(Math.round(state.calculateCruiseAltitudeFt));
    }
    if (elements.calcCruiseAltitudeValue) {
      elements.calcCruiseAltitudeValue.textContent = formatFlightLevelFromFeet(state.calculateCruiseAltitudeFt);
    }
    if (elements.calcCruiseAltitudeTicks && !elements.calcCruiseAltitudeTicks.childElementCount) {
      elements.calcCruiseAltitudeTicks.innerHTML = calculateTicksHtml(10000, 60000, 5000, (value) => `FL${Math.round(value / 100)}`);
    }
    if (elements.calcCruiseMachValue) {
      elements.calcCruiseMachValue.textContent = formatMach(state.calculateCruiseMach);
    }
    if (elements.calcDescentRateInput) {
      elements.calcDescentRateInput.value = String(Math.round(state.calculateDescentRateFpm));
    }
    if (elements.calcDescentRateValue) {
      elements.calcDescentRateValue.textContent = `${Math.round(state.calculateDescentRateFpm)} fpm`;
    }
    if (elements.calcDescentRateTicks && !elements.calcDescentRateTicks.childElementCount) {
      elements.calcDescentRateTicks.innerHTML = calculateTicksHtml(0, 4000, 500, (value) => String(value));
    }
    if (elements.calcProfileZoomInput) {
      elements.calcProfileZoomInput.value = state.calculateProfileZoom.toFixed(1);
    }
    elements.calcWeatherSourceButtons.forEach((button) => {
      const active = button.dataset.calcWeatherSource === state.calculateWeatherSource;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    elements.calcLayerButtons.forEach((button) => {
      const layer = button.dataset.calcLayer;
      const active = Boolean(state.calculateLayerVisibility[layer]);
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    });
  }

  function calculateRouteSignature(points) {
    return points
      .slice(0, CALC_ROUTE_SIGNATURE_LIMIT)
      .map((point) => [
        point.ident || "",
        Number(point.lat || 0).toFixed(4),
        Number(point.lon || 0).toFixed(4),
      ].join("@"))
      .join("|");
  }

  function interpolateRoutePoint(start, end, ratio) {
    return {
      lat: start.lat + (end.lat - start.lat) * ratio,
      lon: start.lon + (end.lon - start.lon) * ratio,
      originalLon: Number.isFinite(start.originalLon) && Number.isFinite(end.originalLon)
        ? start.originalLon + (normalizeLongitude(end.originalLon - start.originalLon)) * ratio
        : undefined,
    };
  }

  function syntheticTerrainFt(point, totalDistanceNm, distanceNm) {
    const lat = Number(point.lat) || 0;
    const lon = Number.isFinite(point.originalLon) ? Number(point.originalLon) : Number(point.lon) || 0;
    const routeRatio = totalDistanceNm > 0 ? distanceNm / totalDistanceNm : 0;
    const ridge = Math.max(0, Math.sin((lat * 1.7 + lon * 0.8) * Math.PI / 45));
    const wave = Math.max(0, Math.cos((lat * 0.9 - lon * 1.25 + routeRatio * 180) * Math.PI / 70));
    const basin = Math.max(0, Math.sin(routeRatio * Math.PI * 3.4));
    const endTaper = Math.sin(Math.PI * clampNumber(routeRatio, 0, 1)) ** 0.45;
    return Math.round(clampNumber((ridge ** 2 * 5200 + wave ** 3 * 3600 + basin * 900) * endTaper, 0, 14200));
  }

  function buildCalculateRouteSamples() {
    const routePoints = withDisplayLongitudes(state.currentRoutePayload?.points || [])
      .map((point) => ({
        ...point,
        lat: Number(point.lat),
        lon: Number(point.lon),
        originalLon: Number.isFinite(point.originalLon) ? Number(point.originalLon) : Number(point.lon),
      }))
      .filter((point) => Number.isFinite(point.lat) && Number.isFinite(point.lon));
    if (routePoints.length < 2) {
      return null;
    }
    const signature = calculateRouteSignature(routePoints);
    if (signature !== state.calculateRouteSignature) {
      state.calculateAltitudeOverrides.clear();
      state.calculateRouteSignature = signature;
      state.calculateProfileFocusNm = null;
    }
    const segments = [];
    let totalDistanceNm = 0;
    for (let index = 1; index < routePoints.length; index += 1) {
      const start = routePoints[index - 1];
      const end = routePoints[index];
      const distanceNm = greatCircleDistanceNm(start, end);
      if (distanceNm <= 0) {
        continue;
      }
      segments.push({ start, end, startIndex: index - 1, endIndex: index, distanceNm, startDistanceNm: totalDistanceNm });
      totalDistanceNm += distanceNm;
    }
    if (totalDistanceNm <= 0) {
      return null;
    }
    const sampleSpacingNm = Math.max(CALC_PROFILE_SAMPLE_NM, totalDistanceNm / Math.max(1, CALC_MAX_PROFILE_POINTS - 1));
    const samples = [];
    segments.forEach((segment) => {
      const steps = Math.max(1, Math.ceil(segment.distanceNm / sampleSpacingNm));
      for (let step = 0; step <= steps; step += 1) {
        if (samples.length && step === 0) {
          continue;
        }
        const ratio = step / steps;
        const point = interpolateRoutePoint(segment.start, segment.end, ratio);
        const distanceNm = segment.startDistanceNm + segment.distanceNm * ratio;
        samples.push({
          ...point,
          ident: ratio === 0 ? segment.start.ident : ratio === 1 ? segment.end.ident : "",
          sourceIndex: ratio === 0 ? segment.startIndex : ratio === 1 ? segment.endIndex : null,
          legIndex: segment.startIndex,
          distanceNm,
          courseDeg: initialBearingDeg(segment.start, segment.end) || 0,
          terrainFt: syntheticTerrainFt(point, totalDistanceNm, distanceNm),
        });
      }
    });
    return { points: routePoints, samples, totalDistanceNm };
  }

  function speedOfSoundKtAtAltitude(altitudeFt) {
    const altitude = clampNumber(Number(altitudeFt) || 0, 0, 60000);
    const temperatureC = altitude <= 36089 ? 15 - 0.0019812 * altitude : -56.5;
    return 38.967854 * Math.sqrt(Math.max(150, temperatureC + 273.15));
  }

  function calculateAtmosphereAt(sample, altitudeFt, sourceKey = state.calculateWeatherSource) {
    const sourceShift = { noaa: 0, ecmwf: 0.58, gfs: 1.14 }[sourceKey] || 0;
    const lat = Number(sample.lat) || 0;
    const lon = Number.isFinite(sample.originalLon) ? Number(sample.originalLon) : Number(sample.lon) || 0;
    const flightLevel = Math.max(0, altitudeFt / 100);
    const wave = Math.sin((sample.distanceNm * 0.035 + lat * 0.18 + sourceShift) * Math.PI);
    const cross = Math.cos((lon * 0.12 - flightLevel * 0.025 + sourceShift * 1.8) * Math.PI);
    const windSpeedKt = clampNumber(18 + flightLevel * 0.12 + wave * 22 + cross * 11, 0, 145);
    const windDirectionDeg = (sample.courseDeg + 210 + wave * 54 + sourceShift * 38 + lon * 0.08 + 720) % 360;
    const windToDeg = (windDirectionDeg + 180) % 360;
    const tailwindKt = windSpeedKt * Math.cos(((windToDeg - sample.courseDeg) * Math.PI) / 180);
    const cloud = clampNumber(42 + wave * 34 + Math.sin((lat + lon + sourceShift * 44) * Math.PI / 42) * 18, 0, 100);
    const rainMmH = cloud > 60 ? clampNumber(((cloud - 58) / 42) * (1 + Math.max(0, cross)) * 5.2, 0, 12) : 0;
    const isaDeviationC = clampNumber(Math.sin((lat * 0.35 + lon * 0.12 + sourceShift * 40) * Math.PI / 90) * 8 + wave * 3, -18, 18);
    return { windSpeedKt, windDirectionDeg, tailwindKt, cloud, rainMmH, isaDeviationC };
  }

  function calculateBaseAltitudeAtDistance(distanceNm, terrainFt, totalDistanceNm) {
    const cruise = state.calculateCruiseAltitudeFt;
    const climbDistanceNm = clampNumber((cruise / 1800) * (255 / 60), 32, Math.max(42, totalDistanceNm * 0.32));
    const descentRate = Math.max(300, state.calculateDescentRateFpm || 1500);
    const descentDistanceNm = clampNumber((cruise / descentRate) * (290 / 60), 22, Math.max(28, totalDistanceNm * 0.36));
    const todNm = Math.max(0, totalDistanceNm - descentDistanceNm);
    let altitudeFt = cruise;
    let phase = "cruise";
    if (distanceNm < climbDistanceNm) {
      altitudeFt = cruise * (distanceNm / Math.max(1, climbDistanceNm));
      phase = "climb";
    } else if (distanceNm > todNm) {
      altitudeFt = cruise * ((totalDistanceNm - distanceNm) / Math.max(1, totalDistanceNm - todNm));
      phase = "descent";
    }
    altitudeFt = Math.max(terrainFt + 1500, altitudeFt);
    return { altitudeFt: clampNumber(altitudeFt, 0, 60000), phase, todNm, climbDistanceNm, descentDistanceNm };
  }

  function buildCalculateProcedureConstraints(samples) {
    const constraints = [];
    Object.entries(state.selectedProcedures).forEach(([type, selected]) => {
      if (!selected) {
        return;
      }
      const payload = state.procedureCache.get(procedureCacheKey(type, selected.airport, selected.procedure, selected.transition));
      (payload?.items || []).forEach((item) => {
        const lat = Number(item.waypoint_latitude);
        const lon = Number(item.waypoint_longitude);
        const altitude1 = Number(item.altitude1);
        const altitude2 = Number(item.altitude2);
        if (!Number.isFinite(lat) || !Number.isFinite(lon) || (!Number.isFinite(altitude1) && !Number.isFinite(altitude2))) {
          return;
        }
        let best = null;
        let bestDistance = Infinity;
        samples.forEach((sample) => {
          const distance = greatCircleDistanceNm(sample, { lat, lon });
          if (distance < bestDistance) {
            bestDistance = distance;
            best = sample;
          }
        });
        if (!best || bestDistance > 80) {
          return;
        }
        constraints.push({
          type,
          ident: item.waypoint_identifier || "",
          label: formatAltitudeRestriction(item),
          distanceNm: best.distanceNm,
          minFt: Number.isFinite(altitude2) ? altitude2 : altitude1,
          maxFt: Number.isFinite(altitude1) ? altitude1 : altitude2,
        });
      });
    });
    return constraints;
  }

  function buildCalculateProfile() {
    const route = buildCalculateRouteSamples();
    if (!route) {
      return null;
    }
    const aircraft = selectedCalculateAircraft();
    const samples = route.samples.map((sample, index) => {
      const base = calculateBaseAltitudeAtDistance(sample.distanceNm, sample.terrainFt, route.totalDistanceNm);
      const override = state.calculateAltitudeOverrides.get(`leg:${sample.legIndex}`);
      const minAltitude = sample.terrainFt + 1200;
      const altitudeFt = Number.isFinite(override)
        ? clampNumber(override, minAltitude, Math.min(60000, aircraft.ceilingFt + 4000))
        : base.altitudeFt;
      const atmosphere = calculateAtmosphereAt(sample, altitudeFt);
      const mach = state.calculateCruiseMach || aircraft.econMach;
      const cruiseTas = speedOfSoundKtAtAltitude(altitudeFt) * mach;
      const phaseSpeedFactor = base.phase === "climb" ? 0.76 : base.phase === "descent" ? 0.68 : 1;
      const tasKt = clampNumber(cruiseTas * phaseSpeedFactor, base.phase === "cruise" ? 330 : 180, aircraft.maxMach * speedOfSoundKtAtAltitude(altitudeFt));
      const groundSpeedKt = clampNumber(tasKt + atmosphere.tailwindKt, 125, 610);
      return {
        ...sample,
        index,
        altitudeFt,
        phase: base.phase,
        todNm: base.todNm,
        climbDistanceNm: base.climbDistanceNm,
        descentDistanceNm: base.descentDistanceNm,
        tasKt,
        groundSpeedKt,
        verticalSpeedFpm: 0,
        timeMinutes: 0,
        fuelKg: 0,
        ...atmosphere,
      };
    });

    let cumulativeTime = 0;
    let tripFuelKg = 0;
    let weightedWind = 0;
    for (let index = 1; index < samples.length; index += 1) {
      const previous = samples[index - 1];
      const current = samples[index];
      const distanceNm = Math.max(0, current.distanceNm - previous.distanceNm);
      const groundSpeedKt = Math.max(90, (previous.groundSpeedKt + current.groundSpeedKt) / 2);
      const minutes = (distanceNm / groundSpeedKt) * 60;
      const altitudeFt = (previous.altitudeFt + current.altitudeFt) / 2;
      const phase = current.phase;
      const phaseRate = phase === "climb" ? aircraft.climbFuelKgH : phase === "descent" ? aircraft.descentFuelKgH : aircraft.baseFuelKgH;
      const altitudeFactor = clampNumber(1.08 - altitudeFt / 140000, 0.72, 1.14);
      const speedDelta = ((state.calculateCruiseMach || aircraft.econMach) - aircraft.econMach) / 0.04;
      const speedFactor = 1 + Math.max(0, speedDelta) ** 2 * 0.075;
      const fuelKg = phaseRate * altitudeFactor * speedFactor * (minutes / 60);
      cumulativeTime += minutes;
      tripFuelKg += fuelKg;
      weightedWind += ((previous.tailwindKt + current.tailwindKt) / 2) * distanceNm;
      current.timeMinutes = cumulativeTime;
      current.fuelKg = tripFuelKg;
      current.verticalSpeedFpm = minutes > 0 ? ((current.altitudeFt - previous.altitudeFt) / minutes) : 0;
    }
    if (samples.length > 1) {
      samples[0].verticalSpeedFpm = samples[1].verticalSpeedFpm;
    }

    const constraints = buildCalculateProcedureConstraints(samples);
    const avgWindComponentKt = weightedWind / Math.max(1, route.totalDistanceNm);
    const avgIsaDeviationC = samples.reduce((sum, sample) => sum + sample.isaDeviationC, 0) / Math.max(1, samples.length);
    return {
      aircraft,
      route,
      samples,
      constraints,
      totalDistanceNm: route.totalDistanceNm,
      totalTimeMinutes: cumulativeTime,
      tripFuelKg,
      avgWindComponentKt,
      avgIsaDeviationC,
      todNm: samples[0]?.todNm || 0,
    };
  }

  function calculateProfileViewport(totalDistanceNm) {
    const total = Math.max(1, totalDistanceNm);
    const zoom = clampNumber(state.calculateProfileZoom || 1, 1, 4);
    const visible = total / zoom;
    const defaultCenter = total / 2;
    const center = clampNumber(state.calculateProfileFocusNm ?? defaultCenter, visible / 2, total - visible / 2);
    return {
      start: Math.max(0, center - visible / 2),
      end: Math.min(total, center + visible / 2),
    };
  }

  function visibleCalculateSamples(profile) {
    const viewport = calculateProfileViewport(profile.totalDistanceNm);
    const paddedStart = Math.max(0, viewport.start - profile.totalDistanceNm * 0.015);
    const paddedEnd = Math.min(profile.totalDistanceNm, viewport.end + profile.totalDistanceNm * 0.015);
    const visibleSamples = profile.samples.filter((sample) => sample.distanceNm >= paddedStart && sample.distanceNm <= paddedEnd);
    if (!visibleSamples.length && profile.samples.length) {
      const center = (viewport.start + viewport.end) / 2;
      let nearestIndex = 0;
      let nearestDistance = Infinity;
      profile.samples.forEach((sample, index) => {
        const distance = Math.abs(sample.distanceNm - center);
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = index;
        }
      });
      visibleSamples.push(...profile.samples.slice(Math.max(0, nearestIndex - 1), Math.min(profile.samples.length, nearestIndex + 2)));
    }
    return {
      viewport,
      samples: visibleSamples,
    };
  }

  function calculateChartColors() {
    const dayTheme = document.documentElement.dataset.theme === "day";
    return {
      grid: dayTheme ? "rgba(61, 94, 117, 0.18)" : "rgba(183, 204, 224, 0.18)",
      axis: dayTheme ? "rgba(43, 84, 112, 0.46)" : "rgba(183, 204, 224, 0.32)",
      label: dayTheme ? "rgba(32, 54, 73, 0.84)" : "rgba(222, 236, 248, 0.84)",
      muted: dayTheme ? "rgba(55, 78, 96, 0.68)" : "rgba(194, 211, 226, 0.68)",
      plotBg: dayTheme ? "rgba(226, 233, 236, 0.72)" : "rgba(229, 234, 238, 0.14)",
      terrainLow: dayTheme ? "#158346" : "#0d7a36",
      terrainHigh: dayTheme ? "#f1d83d" : "#e9db27",
      route: "#ff2633",
      point: "#fff025",
      speed: "rgba(66, 198, 186, 0.92)",
      speedFill: dayTheme ? "rgba(112, 206, 216, 0.46)" : "rgba(89, 201, 214, 0.34)",
      vs: "rgba(255, 164, 128, 0.94)",
    };
  }

  function svgText(x, y, text, options = {}) {
    return `<text x="${x.toFixed(1)}" y="${y.toFixed(1)}" fill="${options.fill}" font-size="${options.size.toFixed(1)}" font-weight="${options.weight || 760}" text-anchor="${options.anchor || "middle"}">${escapeHtml(text)}</text>`;
  }

  function drawWindBarbSvg(x, y, directionDeg, speedKt, colors) {
    const length = 20;
    const angle = ((directionDeg + 180) * Math.PI) / 180;
    const x2 = x + Math.sin(angle) * length;
    const y2 = y - Math.cos(angle) * length;
    const barbAngle = angle + Math.PI * 0.68;
    const barbCount = Math.max(1, Math.min(5, Math.round(speedKt / 12)));
    const barbs = Array.from({ length: barbCount }, (_, index) => {
      const ratio = 0.2 + index * 0.14;
      const bx = x + (x2 - x) * ratio;
      const by = y + (y2 - y) * ratio;
      const ex = bx + Math.sin(barbAngle) * 8;
      const ey = by - Math.cos(barbAngle) * 8;
      return `<line x1="${bx.toFixed(1)}" y1="${by.toFixed(1)}" x2="${ex.toFixed(1)}" y2="${ey.toFixed(1)}" stroke="${colors.muted}" stroke-width="1.5" stroke-linecap="round" />`;
    }).join("");
    return `
      <line x1="${x.toFixed(1)}" y1="${y.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="${colors.muted}" stroke-width="1.6" stroke-linecap="round" />
      ${barbs}
    `;
  }

  function renderCalculateWeatherProfile(profile) {
    const svg = elements.calcWeatherProfileSvg;
    if (!svg) {
      return;
    }
    if (!profile?.samples?.length) {
      state.calculateWeatherLayout = null;
      svg.innerHTML = `<text x="50%" y="50%" fill="rgba(190,205,220,.78)" font-size="13" font-weight="780" text-anchor="middle">${escapeHtml(t("calculate.statusNoRoute"))}</text>`;
      return;
    }
    const colors = calculateChartColors();
    const chartElement = svg.parentElement || svg;
    const rect = chartElement.getBoundingClientRect();
    const width = Math.round(Math.max(340, rect.width || svg.clientWidth || 760));
    const height = Math.round(Math.max(220, rect.height || svg.clientHeight || 360));
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
    const plot = {
      left: Math.round(clampNumber(width * 0.085, 44, 62)),
      right: Math.round(clampNumber(width * 0.055, 28, 48)),
      top: 20,
      bottom: 38,
    };
    const plotWidth = width - plot.left - plot.right;
    const plotHeight = height - plot.top - plot.bottom;
    const { viewport, samples } = visibleCalculateSamples(profile);
    const xForDistance = (distanceNm) => plot.left + ((distanceNm - viewport.start) / Math.max(1, viewport.end - viewport.start)) * plotWidth;
    const yForAltitude = (altitudeFt) => plot.top + (1 - altitudeFt / 60000) * plotHeight;
    state.calculateWeatherLayout = { width, height, plot, viewport, xForDistance, yForAltitude };

    const grid = [];
    for (let altitude = 0; altitude <= 60000; altitude += 5000) {
      const y = yForAltitude(altitude);
      grid.push(`<line x1="${plot.left}" y1="${y.toFixed(1)}" x2="${(width - plot.right).toFixed(1)}" y2="${y.toFixed(1)}" stroke="${colors.grid}" stroke-width="1" />`);
      if (altitude % 10000 === 0 || altitude === 5000) {
        grid.push(svgText(plot.left - 8, y + 4, String(Math.round(altitude / 100)), { fill: colors.label, size: 10, anchor: "end" }));
        const hpa = altitude >= 45000 ? 150 : altitude >= 35000 ? 250 : altitude >= 25000 ? 400 : altitude >= 15000 ? 600 : altitude >= 5000 ? 850 : 1013;
        grid.push(svgText(width - plot.right + 8, y + 4, String(hpa), { fill: colors.label, size: 9.5, anchor: "start" }));
      }
    }
    const xTickCount = Math.round(clampNumber(plotWidth / 110 + 1, 3, 8));
    for (let index = 0; index < xTickCount; index += 1) {
      const ratio = index / Math.max(1, xTickCount - 1);
      const distance = viewport.start + ratio * (viewport.end - viewport.start);
      const x = xForDistance(distance);
      grid.push(`<line x1="${x.toFixed(1)}" y1="${plot.top}" x2="${x.toFixed(1)}" y2="${(height - plot.bottom).toFixed(1)}" stroke="${colors.grid}" stroke-width="1" />`);
      grid.push(svgText(x, height - 12, `${Math.round(distance)}nm`, { fill: colors.label, size: 9.5 }));
    }

    const terrainPath = samples.map((sample, index) => {
      const x = xForDistance(sample.distanceNm);
      const y = yForAltitude(sample.terrainFt);
      return `${index ? "L" : "M"}${x.toFixed(1)} ${y.toFixed(1)}`;
    }).join(" ");
    const terrainArea = terrainPath
      ? `${terrainPath} L${xForDistance(samples.at(-1).distanceNm).toFixed(1)} ${(height - plot.bottom).toFixed(1)} L${xForDistance(samples[0].distanceNm).toFixed(1)} ${(height - plot.bottom).toFixed(1)} Z`
      : "";
    const plannedPath = svgPathForProfile(samples.map((sample) => ({
      x: xForDistance(sample.distanceNm),
      y: yForAltitude(sample.altitudeFt),
    })), "y");

    const cloudLayer = state.calculateLayerVisibility.cloud
      ? samples.map((sample, index) => {
        if (index % 2 || sample.cloud < 18) {
          return "";
        }
        const x = xForDistance(sample.distanceNm);
        const widthCloud = clampNumber(plotWidth / Math.max(8, samples.length * 0.6), 14, 44);
        const y = yForAltitude(clampNumber(sample.altitudeFt + 9000, 10000, 56000));
        return `<rect x="${(x - widthCloud / 2).toFixed(1)}" y="${(y - 11).toFixed(1)}" width="${widthCloud.toFixed(1)}" height="${clampNumber(sample.cloud / 3, 7, 28).toFixed(1)}" rx="7" fill="rgba(122, 157, 184, ${clampNumber(sample.cloud / 180, 0.12, 0.52).toFixed(2)})" />`;
      }).join("")
      : "";
    const rainLayer = state.calculateLayerVisibility.rain
      ? samples.map((sample, index) => {
        if (index % 2 || sample.rainMmH <= 0.1) {
          return "";
        }
        const x = xForDistance(sample.distanceNm);
        const barHeight = clampNumber(sample.rainMmH * 6, 4, 48);
        return `<line x1="${x.toFixed(1)}" y1="${(height - plot.bottom).toFixed(1)}" x2="${x.toFixed(1)}" y2="${(height - plot.bottom - barHeight).toFixed(1)}" stroke="rgba(58, 142, 255, 0.68)" stroke-width="3" stroke-linecap="round" />`;
      }).join("")
      : "";
    const windLayer = state.calculateLayerVisibility.wind
      ? (() => {
        const levels = [10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000];
        const xSlots = Math.round(clampNumber(plotWidth / 78, 5, 13));
        const pieces = [];
        for (let xi = 0; xi < xSlots; xi += 1) {
          const distance = viewport.start + (xi / Math.max(1, xSlots - 1)) * (viewport.end - viewport.start);
          const nearest = samples.reduce((best, sample) => (Math.abs(sample.distanceNm - distance) < Math.abs(best.distanceNm - distance) ? sample : best), samples[0]);
          levels.forEach((altitude) => {
            const met = calculateAtmosphereAt(nearest, altitude);
            const x = xForDistance(distance);
            const y = yForAltitude(altitude);
            pieces.push(drawWindBarbSvg(x, y + 2, met.windDirectionDeg, met.windSpeedKt, colors));
            pieces.push(svgText(x - 8, y - 3, String(Math.round(met.windSpeedKt)), { fill: colors.muted, size: 8.6, anchor: "end", weight: 720 }));
          });
        }
        return pieces.join("");
      })()
      : "";

    const pointSamples = samples.filter((sample) => sample.ident);
    const pointLabelBudget = Math.max(2, Math.floor(plotWidth / 82));
    const pointLabelStride = Math.max(1, Math.ceil(pointSamples.length / pointLabelBudget));
    const pointMarkers = pointSamples
      .map((sample, index) => {
        const x = xForDistance(sample.distanceNm);
        if (x < plot.left - 2 || x > width - plot.right + 2) {
          return "";
        }
        const y = yForAltitude(sample.altitudeFt);
        const labelY = Math.max(plot.top + 12, y - 15);
        const shouldShowLabel = index === 0 || index === pointSamples.length - 1 || index % pointLabelStride === 0;
        return `
          <rect x="${(x - 3).toFixed(1)}" y="${(y - 3).toFixed(1)}" width="6" height="6" fill="${colors.point}" stroke="rgba(48, 55, 20, 0.8)" stroke-width="0.8" />
          ${shouldShowLabel ? `
            <rect x="${(x - 24).toFixed(1)}" y="${(labelY - 13).toFixed(1)}" width="48" height="16" rx="2" fill="rgba(131, 194, 213, 0.82)" stroke="rgba(34, 83, 104, 0.8)" stroke-width="1" />
            ${svgText(x, labelY - 1, sample.ident, { fill: "rgba(20, 51, 66, 0.96)", size: 8.8, weight: 850 })}
          ` : ""}
        `;
      }).join("");
    const todX = xForDistance(profile.todNm);
    const todMarker = todX >= plot.left && todX <= width - plot.right
      ? `
        <line x1="${todX.toFixed(1)}" y1="${plot.top}" x2="${todX.toFixed(1)}" y2="${(height - plot.bottom).toFixed(1)}" stroke="rgba(255, 209, 102, 0.78)" stroke-width="1.5" stroke-dasharray="6 6" />
        ${svgText(todX + 4, plot.top + 13, t("calculate.tod"), { fill: "rgba(255, 209, 102, 0.95)", size: 9.3, anchor: "start", weight: 850 })}
      `
      : "";
    const constraintMarkers = profile.constraints.map((constraint) => {
      const x = xForDistance(constraint.distanceNm);
      if (x < plot.left || x > width - plot.right) {
        return "";
      }
      const yMin = yForAltitude(clampNumber(constraint.minFt, 0, 60000));
      const yMax = yForAltitude(clampNumber(constraint.maxFt, 0, 60000));
      const yTop = Math.min(yMin, yMax);
      const yBottom = Math.max(yMin, yMax);
      return `
        <line x1="${x.toFixed(1)}" y1="${yTop.toFixed(1)}" x2="${x.toFixed(1)}" y2="${yBottom.toFixed(1)}" stroke="rgba(154, 108, 255, 0.92)" stroke-width="2" />
        <circle cx="${x.toFixed(1)}" cy="${yTop.toFixed(1)}" r="3" fill="rgba(154, 108, 255, 0.92)" />
        ${svgText(x + 5, yTop - 5, constraint.ident || t("calculate.procedureConstraint"), { fill: "rgba(190, 166, 255, 0.96)", size: 8.5, anchor: "start", weight: 820 })}
      `;
    }).join("");

    svg.innerHTML = `
      <defs>
        <linearGradient id="calculateTerrainGradient" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="${colors.terrainHigh}" />
          <stop offset="55%" stop-color="#9bd318" />
          <stop offset="100%" stop-color="${colors.terrainLow}" />
        </linearGradient>
      </defs>
      <rect x="0" y="0" width="${width}" height="${height}" fill="${colors.plotBg}" />
      ${grid.join("")}
      ${cloudLayer}
      ${rainLayer}
      ${windLayer}
      ${terrainArea ? `<path d="${terrainArea}" fill="url(#calculateTerrainGradient)" opacity="0.95" />` : ""}
      ${plannedPath ? `<path d="${plannedPath}" fill="none" stroke="${colors.route}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" />` : ""}
      ${todMarker}
      ${constraintMarkers}
      ${pointMarkers}
      <line x1="${plot.left}" y1="${plot.top}" x2="${plot.left}" y2="${height - plot.bottom}" stroke="${colors.axis}" stroke-width="1.4" />
      <line x1="${plot.left}" y1="${height - plot.bottom}" x2="${width - plot.right}" y2="${height - plot.bottom}" stroke="${colors.axis}" stroke-width="1.4" />
      ${svgText(plot.left + 3, plot.top - 6, "Flightlevel", { fill: colors.label, size: 10, anchor: "start", weight: 860 })}
      ${svgText(width - 4, plot.top - 6, "hPa", { fill: colors.label, size: 10, anchor: "end", weight: 860 })}
    `;
  }

  function renderCalculateSpeedProfile(profile) {
    const svg = elements.calcSpeedProfileSvg;
    if (!svg) {
      return;
    }
    if (!profile?.samples?.length) {
      state.calculateSpeedLayout = null;
      svg.innerHTML = `<text x="50%" y="50%" fill="rgba(190,205,220,.78)" font-size="13" font-weight="780" text-anchor="middle">${escapeHtml(t("calculate.statusNoRoute"))}</text>`;
      return;
    }
    const colors = calculateChartColors();
    const chartElement = svg.parentElement || svg;
    const rect = chartElement.getBoundingClientRect();
    const width = Math.round(Math.max(340, rect.width || svg.clientWidth || 760));
    const height = Math.round(Math.max(150, rect.height || svg.clientHeight || 250));
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
    const plot = {
      left: Math.round(clampNumber(width * 0.085, 45, 64)),
      right: Math.round(clampNumber(width * 0.08, 42, 58)),
      top: 26,
      bottom: 44,
    };
    const plotWidth = width - plot.left - plot.right;
    const plotHeight = height - plot.top - plot.bottom;
    const { viewport, samples } = visibleCalculateSamples(profile);
    const xForDistance = (distanceNm) => plot.left + ((distanceNm - viewport.start) / Math.max(1, viewport.end - viewport.start)) * plotWidth;
    const speedMax = Math.max(500, Math.ceil(Math.max(...samples.map((sample) => sample.groundSpeedKt)) / 50) * 50);
    const yForSpeed = (speed) => plot.top + (1 - speed / speedMax) * plotHeight;
    const yForVS = (vs) => plot.top + (1 - ((clampNumber(vs, -4000, 4000) + 4000) / 8000)) * plotHeight;
    state.calculateSpeedLayout = { width, height, plot, viewport, xForDistance };
    const grid = [];
    for (let speed = 0; speed <= speedMax; speed += 100) {
      const y = yForSpeed(speed);
      grid.push(`<line x1="${plot.left}" y1="${y.toFixed(1)}" x2="${(width - plot.right).toFixed(1)}" y2="${y.toFixed(1)}" stroke="${colors.grid}" stroke-width="1" />`);
      grid.push(svgText(plot.left - 8, y + 4, String(speed), { fill: colors.label, size: 10, anchor: "end" }));
    }
    [-4000, -2000, 0, 2000, 4000].forEach((vs) => {
      const y = yForVS(vs);
      grid.push(`<line x1="${plot.left}" y1="${y.toFixed(1)}" x2="${(width - plot.right).toFixed(1)}" y2="${y.toFixed(1)}" stroke="${vs === 0 ? "rgba(255, 164, 128, 0.42)" : colors.grid}" stroke-width="${vs === 0 ? "1.4" : "1"}" />`);
      grid.push(svgText(width - plot.right + 8, y + 4, String(vs), { fill: vs === 0 ? colors.vs : colors.label, size: 9.5, anchor: "start" }));
    });
    const xTickCount = Math.round(clampNumber(plotWidth / 140 + 1, 3, 7));
    for (let index = 0; index < xTickCount; index += 1) {
      const ratio = index / Math.max(1, xTickCount - 1);
      const distance = viewport.start + ratio * (viewport.end - viewport.start);
      const x = xForDistance(distance);
      grid.push(`<line x1="${x.toFixed(1)}" y1="${plot.top}" x2="${x.toFixed(1)}" y2="${(height - plot.bottom).toFixed(1)}" stroke="${colors.grid}" stroke-width="1" />`);
      grid.push(svgText(x, height - 24, `${Math.round(distance)}`, { fill: colors.label, size: 9.5 }));
    }
    const speedPoints = samples.map((sample) => ({ x: xForDistance(sample.distanceNm), y: yForSpeed(sample.groundSpeedKt) }));
    const speedPath = svgPathForProfile(speedPoints, "y");
    const speedArea = speedPath
      ? `${speedPath} L${xForDistance(samples.at(-1).distanceNm).toFixed(1)} ${(height - plot.bottom).toFixed(1)} L${xForDistance(samples[0].distanceNm).toFixed(1)} ${(height - plot.bottom).toFixed(1)} Z`
      : "";
    const vsPath = svgPathForProfile(samples.map((sample) => ({ x: xForDistance(sample.distanceNm), y: yForVS(sample.verticalSpeedFpm) })), "y");
    svg.innerHTML = `
      <rect x="0" y="0" width="${width}" height="${height}" fill="transparent" />
      ${grid.join("")}
      ${speedArea ? `<path d="${speedArea}" fill="${colors.speedFill}" />` : ""}
      ${speedPath ? `<path d="${speedPath}" fill="none" stroke="${colors.speed}" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round" />` : ""}
      ${vsPath ? `<path d="${vsPath}" fill="none" stroke="${colors.vs}" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round" />` : ""}
      <line x1="${plot.left}" y1="${plot.top}" x2="${plot.left}" y2="${height - plot.bottom}" stroke="${colors.axis}" stroke-width="1.4" />
      <line x1="${plot.left}" y1="${height - plot.bottom}" x2="${width - plot.right}" y2="${height - plot.bottom}" stroke="${colors.axis}" stroke-width="1.4" />
      ${svgText(plot.left, plot.top - 8, "地速 (kt)", { fill: colors.label, size: 10, anchor: "start", weight: 860 })}
      ${svgText(width - plot.right, plot.top - 8, "VS (fpm)", { fill: colors.vs, size: 10, anchor: "end", weight: 860 })}
      ${svgText(width / 2, height - 7, "飞行距离 (NM)", { fill: colors.label, size: 10, weight: 820 })}
    `;
  }

  function routeAirportCode(side) {
    const airport = side === "departure" ? state.departureAirport : state.arrivalAirport;
    return airport?.airport_iata_identifier || airport?.airport_identifier || elements[`${side}Input`]?.value?.trim()?.toUpperCase() || "----";
  }

  function renderCalculateFuel(profile) {
    if (!elements.calcFuelBrief || !elements.calcFuelSummary) {
      return;
    }
    if (!profile) {
      elements.calcFuelSummary.textContent = t("calculate.fuelSummaryInitial");
      elements.calcFuelBrief.textContent = `PLANNED FUEL\n------------------------------\n${t("calculate.noFuel")}`;
      return;
    }
    const aircraft = profile.aircraft;
    const tripFuel = Math.max(0, profile.tripFuelKg);
    const contFuel = Math.max(450, aircraft.baseFuelKgH * 0.25, tripFuel * 0.05);
    const alternateFuel = Math.max(500, aircraft.baseFuelKgH * 0.28);
    const finalReserveFuel = Math.max(900, aircraft.baseFuelKgH * 0.5);
    const taxiFuel = aircraft.taxiKg;
    const offFuel = tripFuel + contFuel + alternateFuel + finalReserveFuel;
    const blockFuel = offFuel + taxiFuel;
    const zfw = Math.min(aircraft.zfwKg, aircraft.zfwKg * 0.92);
    const estimatedTow = Math.min(aircraft.mtowKg, zfw + blockFuel);
    const estimatedLaw = Math.min(aircraft.mlwKg, estimatedTow - tripFuel);
    const dest = routeAirportCode("arrival");
    const dep = routeAirportCode("departure");
    const tripTime = profile.totalTimeMinutes;
    const contTime = 15;
    const alternateTime = 17;
    const finalReserveTime = 30;
    const windCode = `${profile.avgWindComponentKt >= 0 ? "P" : "M"}${String(Math.round(Math.abs(profile.avgWindComponentKt))).padStart(3, "0")}`;
    const isaCode = `${profile.avgIsaDeviationC >= 0 ? "P" : "M"}${String(Math.round(Math.abs(profile.avgIsaDeviationC))).padStart(3, "0")}`;
    const line = (label, arpt, fuel, time) => `${label.padEnd(15, " ")}${String(arpt || "").padEnd(7, " ")}${String(Math.round(fuel)).padStart(7, " ")}  ${formatFuelTime(time)}`;
    const brief = [
      `MAXIMUM    TOW ${String(Math.round(aircraft.mtowKg)).padStart(7, " ")}  LAW ${String(Math.round(aircraft.mlwKg)).padStart(7, " ")}  ZFW ${String(Math.round(aircraft.zfwKg)).padStart(7, " ")}     AVG W/C      ${windCode}`,
      `ESTIMATED  TOW ${String(Math.round(estimatedTow)).padStart(7, " ")}  LAW ${String(Math.round(estimatedLaw)).padStart(7, " ")}  ZFW ${String(Math.round(zfw)).padStart(7, " ")}     AVG ISA      ${isaCode}`,
      "",
      "          PLANNED FUEL",
      "------------------------------",
      "FUEL           ARPT      FUEL  TIME",
      "------------------------------",
      line("TRIP", dest, tripFuel, tripTime),
      line("CONT 15 MIN", "", contFuel, contTime),
      line("ALTN", "ALTN", alternateFuel, alternateTime),
      line("FINRES", "", finalReserveFuel, finalReserveTime),
      "------------------------------",
      line("MINIMUM T/OFF", "", offFuel, tripTime + contTime + alternateTime + finalReserveTime),
      "------------------------------",
      line("EXTRA", "", 0, 0),
      "------------------------------",
      line("T/OFF FUEL", "", offFuel, tripTime + contTime + alternateTime + finalReserveTime),
      line("TAXI", dep, taxiFuel, 20),
      "------------------------------",
      line("BLOCK FUEL", dep, blockFuel, ""),
      "PIC EXTRA       .....",
      "TOTAL FUEL      .....",
      "REASON FOR PIC EXTRA ..........",
      "------------------------------------------------------",
      "FMC INFO:",
      `FINRES+ALTN       ${String(Math.round(finalReserveFuel + alternateFuel)).padStart(7, " ")}`,
      `TRIP+TAXI         ${String(Math.round(tripFuel + taxiFuel)).padStart(7, " ")}`,
      "",
      `MODEL: ${aircraft.code} ${aircraft.label} / ${formatMach(state.calculateCruiseMach || aircraft.econMach)} / ${formatFlightLevelFromFeet(state.calculateCruiseAltitudeFt)}`,
    ].join("\n");
    elements.calcFuelBrief.textContent = brief;
    elements.calcFuelSummary.textContent = t("calculate.fuelSummary", {
      distance: Math.round(profile.totalDistanceNm),
      time: formatReadableDuration(profile.totalTimeMinutes),
      fuel: Math.round(offFuel),
    });
  }

  function nearestCalculateSampleFromEvent(event, layout, profile) {
    if (!layout || !profile?.samples?.length) {
      return null;
    }
    const rect = event.currentTarget.getBoundingClientRect();
    const x = rect.width > 0
      ? ((event.clientX - rect.left) / rect.width) * layout.width
      : layout.plot.left;
    const distanceNm = layout.viewport.start + ((x - layout.plot.left) / Math.max(1, layout.width - layout.plot.left - layout.plot.right)) * (layout.viewport.end - layout.viewport.start);
    return profile.samples.reduce((best, sample) => (
      Math.abs(sample.distanceNm - distanceNm) < Math.abs(best.distanceNm - distanceNm) ? sample : best
    ), profile.samples[0]);
  }

  function updateCalculateReadouts(sample) {
    const profile = state.calculateProfileData;
    if (!profile?.samples?.length) {
      if (elements.calcWeatherReadout) {
        elements.calcWeatherReadout.textContent = t("calculate.weatherReadoutEmpty");
      }
      if (elements.calcSpeedReadout) {
        elements.calcSpeedReadout.textContent = "--";
      }
      return;
    }
    const target = sample || profile.samples[Math.floor(profile.samples.length / 2)];
    if (elements.calcWeatherReadout) {
      elements.calcWeatherReadout.textContent = t("calculate.weatherReadout", {
        distance: Math.round(target.distanceNm),
        flightLevel: Math.round(target.altitudeFt / 100),
        wind: Math.round(target.windSpeedKt),
        component: formatSignedWindComponent(target.tailwindKt),
        cloud: Math.round(target.cloud),
        rain: target.rainMmH.toFixed(1),
      });
    }
    if (elements.calcSpeedReadout) {
      elements.calcSpeedReadout.textContent = t("calculate.speedReadout", {
        distance: Math.round(target.distanceNm),
        groundSpeed: Math.round(target.groundSpeedKt),
        verticalSpeed: Math.round(target.verticalSpeedFpm),
        phase: t(`calculate.phase${target.phase[0].toUpperCase()}${target.phase.slice(1)}`),
      });
    }
  }

  function renderCalculatePanel() {
    syncCalculateControls();
    const profile = buildCalculateProfile();
    state.calculateProfileData = profile;
    if (!profile) {
      if (elements.calcStatusText) {
        elements.calcStatusText.textContent = t("calculate.statusNoRoute");
      }
      renderCalculateWeatherProfile(null);
      renderCalculateSpeedProfile(null);
      renderCalculateFuel(null);
      updateCalculateReadouts(null);
      return;
    }
    if (elements.calcStatusText) {
      elements.calcStatusText.textContent = t("calculate.statusReady", {
        count: profile.samples.length,
        source: CALC_WEATHER_SOURCE_LABELS[state.calculateWeatherSource],
      });
    }
    renderCalculateWeatherProfile(profile);
    renderCalculateSpeedProfile(profile);
    renderCalculateFuel(profile);
    updateCalculateReadouts(profile.samples.find((sample) => sample.distanceNm >= (profile.todNm || 0)) || profile.samples[0]);
  }

  function scheduleCalculateRender(delay = 0) {
    if (delay > 0) {
      window.setTimeout(() => scheduleCalculateRender(), delay);
      return;
    }
    if (state.calculateResizeFrame) {
      window.cancelAnimationFrame(state.calculateResizeFrame);
    }
    state.calculateResizeFrame = window.requestAnimationFrame(() => {
      state.calculateResizeFrame = null;
      renderCalculatePanel();
    });
  }

  function ensureCalculateResizeObserver() {
    if (state.calculateResizeObserver || !window.ResizeObserver) {
      return;
    }
    const targets = new Set([
      elements.detailPanel,
      elements.calculateSection,
      elements.calcWeatherProfileSvg?.parentElement,
      elements.calcSpeedProfileSvg?.parentElement,
    ]);
    state.calculateResizeObserver = new ResizeObserver(() => scheduleCalculateRender());
    targets.forEach((target) => {
      if (target) {
        state.calculateResizeObserver.observe(target);
      }
    });
  }

  function handleCalculateWeatherPointer(event, { commit = false } = {}) {
    const profile = state.calculateProfileData;
    const sample = nearestCalculateSampleFromEvent(event, state.calculateWeatherLayout, profile);
    if (!sample) {
      return;
    }
    event.preventDefault();
    state.calculateProfileFocusNm = sample.distanceNm;
    updateCalculateReadouts(sample);
    if (commit) {
      const layout = state.calculateWeatherLayout;
      const rect = event.currentTarget.getBoundingClientRect();
      const y = rect.height > 0
        ? ((event.clientY - rect.top) / rect.height) * layout.height
        : layout.plot.top;
      const rawAltitude = 60000 * (1 - ((y - layout.plot.top) / Math.max(1, layout.height - layout.plot.top - layout.plot.bottom)));
      const roundedAltitude = Math.round(clampNumber(rawAltitude, sample.terrainFt + 1200, 60000) / 1000) * 1000;
      state.calculateAltitudeOverrides.set(`leg:${sample.legIndex}`, roundedAltitude);
      scheduleCalculateRender();
    }
  }

  function resetCalculateProfileAdjustments() {
    state.calculateAltitudeOverrides.clear();
    state.calculateProfileFocusNm = null;
    state.calculateProfileZoom = 1;
    scheduleCalculateRender();
  }

  function registerEvents() {
    syncCalculateControls({ resetMach: true });
    ensureCalculateResizeObserver();
    elements.calcManufacturerSelect?.addEventListener("change", (event) => {
      state.calculateManufacturer = normalizeCalculateManufacturer(event.target.value);
      state.calculateAircraft = normalizeCalculateAircraft("", state.calculateManufacturer);
      state.calculateCruiseMach = null;
      scheduleCalculateRender();
    });
    elements.calcAircraftSelect?.addEventListener("change", (event) => {
      state.calculateAircraft = normalizeCalculateAircraft(event.target.value, state.calculateManufacturer);
      state.calculateCruiseMach = null;
      scheduleCalculateRender();
    });
    elements.calcCruiseAltitudeInput?.addEventListener("input", (event) => {
      state.calculateCruiseAltitudeFt = clampNumber(Number(event.target.value), 10000, 60000);
      state.calculateProfileFocusNm = null;
      scheduleCalculateRender();
    });
    elements.calcCruiseMachInput?.addEventListener("input", (event) => {
      const aircraft = selectedCalculateAircraft();
      state.calculateCruiseMach = clampNumber(Number(event.target.value), 0.5, aircraft.maxMach);
      scheduleCalculateRender();
    });
    elements.calcDescentRateInput?.addEventListener("input", (event) => {
      state.calculateDescentRateFpm = clampNumber(Number(event.target.value), 0, 4000);
      scheduleCalculateRender();
    });
    elements.calcProfileZoomInput?.addEventListener("input", (event) => {
      state.calculateProfileZoom = clampNumber(Number(event.target.value), 1, 4);
      scheduleCalculateRender();
    });
    elements.calcResetProfileButton?.addEventListener("click", resetCalculateProfileAdjustments);
    elements.calcWeatherSourceButtons.forEach((button) => {
      button.addEventListener("click", () => {
        const source = button.dataset.calcWeatherSource;
        state.calculateWeatherSource = CALC_WEATHER_SOURCE_KEYS.has(source) ? source : "noaa";
        scheduleCalculateRender();
      });
    });
    elements.calcLayerButtons.forEach((button) => {
      button.addEventListener("click", () => {
        const layer = button.dataset.calcLayer;
        if (!CALC_LAYER_KEYS.has(layer)) {
          return;
        }
        state.calculateLayerVisibility[layer] = !state.calculateLayerVisibility[layer];
        scheduleCalculateRender();
      });
    });
    elements.calcWeatherProfileSvg?.addEventListener("pointerdown", (event) => {
      state.calculateWeatherDragging = true;
      elements.calcWeatherProfileSvg.setPointerCapture?.(event.pointerId);
      handleCalculateWeatherPointer(event, { commit: true });
    });
    elements.calcWeatherProfileSvg?.addEventListener("pointermove", (event) => {
      handleCalculateWeatherPointer(event, { commit: state.calculateWeatherDragging });
    });
    elements.calcWeatherProfileSvg?.addEventListener("pointerup", (event) => {
      state.calculateWeatherDragging = false;
      elements.calcWeatherProfileSvg.releasePointerCapture?.(event.pointerId);
    });
    elements.calcWeatherProfileSvg?.addEventListener("pointercancel", () => {
      state.calculateWeatherDragging = false;
    });
    elements.calcSpeedProfileSvg?.addEventListener("pointermove", (event) => {
      const sample = nearestCalculateSampleFromEvent(event, state.calculateSpeedLayout, state.calculateProfileData);
      if (sample) {
        state.calculateProfileFocusNm = sample.distanceNm;
        updateCalculateReadouts(sample);
      }
    });
  }

  return {
    registerEvents,
    syncControls: syncCalculateControls,
    scheduleRender: scheduleCalculateRender,
    ensureResizeObserver: ensureCalculateResizeObserver,
    normalizeManufacturer: normalizeCalculateManufacturer,
    normalizeAircraft: normalizeCalculateAircraft,
    selectedAircraft: selectedCalculateAircraft,
    hasWeatherSource: (value) => CALC_WEATHER_SOURCE_KEYS.has(value),
    forEachLayer: (callback) => CALC_LAYER_KEYS.forEach(callback),
  };
}
