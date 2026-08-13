const CALC_AIRCRAFT_CATALOG = Object.freeze({
  boeing: {
    label: { "zh-Hans": "波音", en: "Boeing" },
    aircraft: [
      { code: "B737", label: "737-700", econMach: 0.78, maxMach: 0.82, mtowKg: 70080, mlwKg: 58059, zfwKg: 54657, oewKg: 37648, maxFuelKg: 20894, taxiKg: 220, baseFuelKgH: 2200, climbFuelKgH: 3800, descentFuelKgH: 900, climbRateFpm: 2550, ceilingFt: 41000 },
      { code: "B738", label: "737-800", econMach: 0.78, maxMach: 0.82, mtowKg: 79015, mlwKg: 66360, zfwKg: 62730, oewKg: 41413, maxFuelKg: 20894, taxiKg: 230, baseFuelKgH: 2500, climbFuelKgH: 4300, descentFuelKgH: 1100, climbRateFpm: 2450, ceilingFt: 41000 },
      { code: "B38M", label: "737 MAX 8", econMach: 0.79, maxMach: 0.82, mtowKg: 82191, mlwKg: 69309, zfwKg: 65952, oewKg: 45300, maxFuelKg: 20894, taxiKg: 230, baseFuelKgH: 2300, climbFuelKgH: 4050, descentFuelKgH: 980, climbRateFpm: 2550, ceilingFt: 41000 },
      { code: "B39M", label: "737 MAX 9", econMach: 0.79, maxMach: 0.82, mtowKg: 88314, mlwKg: 74389, zfwKg: 70600, oewKg: 50100, maxFuelKg: 25800, taxiKg: 250, baseFuelKgH: 2600, climbFuelKgH: 4550, descentFuelKgH: 1100, climbRateFpm: 2350, ceilingFt: 41000 },
      { code: "B752", label: "757-200", econMach: 0.80, maxMach: 0.86, mtowKg: 115680, mlwKg: 89811, zfwKg: 83460, oewKg: 58200, maxFuelKg: 34400, taxiKg: 320, baseFuelKgH: 3900, climbFuelKgH: 6200, descentFuelKgH: 1500, climbRateFpm: 2650, ceilingFt: 42000 },
      { code: "B763", label: "767-300ER", econMach: 0.80, maxMach: 0.86, mtowKg: 186880, mlwKg: 145150, zfwKg: 130635, oewKg: 90400, maxFuelKg: 72400, taxiKg: 420, baseFuelKgH: 5200, climbFuelKgH: 8400, descentFuelKgH: 2100, climbRateFpm: 2050, ceilingFt: 43100 },
      { code: "B764", label: "767-400ER", econMach: 0.80, maxMach: 0.86, mtowKg: 204120, mlwKg: 158757, zfwKg: 140614, oewKg: 103000, maxFuelKg: 91380, taxiKg: 460, baseFuelKgH: 5900, climbFuelKgH: 9300, descentFuelKgH: 2300, climbRateFpm: 1950, ceilingFt: 43100 },
      { code: "B788", label: "787-8", econMach: 0.85, maxMach: 0.90, mtowKg: 227930, mlwKg: 172365, zfwKg: 161025, oewKg: 119950, maxFuelKg: 101456, taxiKg: 450, baseFuelKgH: 5100, climbFuelKgH: 9000, descentFuelKgH: 2150, climbRateFpm: 2150, ceilingFt: 43100 },
      { code: "B789", label: "787-9", econMach: 0.85, maxMach: 0.90, mtowKg: 254011, mlwKg: 192776, zfwKg: 181437, oewKg: 128850, maxFuelKg: 126206, taxiKg: 480, baseFuelKgH: 5600, climbFuelKgH: 9700, descentFuelKgH: 2300, climbRateFpm: 2050, ceilingFt: 43100 },
      { code: "B78X", label: "787-10", econMach: 0.85, maxMach: 0.90, mtowKg: 254011, mlwKg: 201848, zfwKg: 192776, oewKg: 135000, maxFuelKg: 126372, taxiKg: 500, baseFuelKgH: 6200, climbFuelKgH: 10400, descentFuelKgH: 2500, climbRateFpm: 1900, ceilingFt: 43100 },
      { code: "B772", label: "777-200ER", econMach: 0.84, maxMach: 0.89, mtowKg: 297550, mlwKg: 213188, zfwKg: 195044, oewKg: 139225, maxFuelKg: 117300, taxiKg: 560, baseFuelKgH: 6900, climbFuelKgH: 11300, descentFuelKgH: 2800, climbRateFpm: 1850, ceilingFt: 43100 },
      { code: "B77L", label: "777-200LR", econMach: 0.84, maxMach: 0.89, mtowKg: 347815, mlwKg: 223168, zfwKg: 209106, oewKg: 145150, maxFuelKg: 202290, taxiKg: 610, baseFuelKgH: 7600, climbFuelKgH: 12600, descentFuelKgH: 3100, climbRateFpm: 1750, ceilingFt: 43100 },
      { code: "B77W", label: "777-300ER", econMach: 0.84, maxMach: 0.89, mtowKg: 351534, mlwKg: 251290, zfwKg: 237682, oewKg: 167829, maxFuelKg: 181283, taxiKg: 620, baseFuelKgH: 7600, climbFuelKgH: 12800, descentFuelKgH: 3100, climbRateFpm: 1700, ceilingFt: 43100 },
      { code: "B744", label: "747-400", econMach: 0.85, maxMach: 0.92, mtowKg: 396890, mlwKg: 295742, zfwKg: 242672, oewKg: 178800, maxFuelKg: 173240, taxiKg: 760, baseFuelKgH: 10500, climbFuelKgH: 17000, descentFuelKgH: 4300, climbRateFpm: 1450, ceilingFt: 45100 },
      { code: "B748", label: "747-8", econMach: 0.85, maxMach: 0.92, mtowKg: 447700, mlwKg: 346091, zfwKg: 295742, oewKg: 220128, maxFuelKg: 243120, taxiKg: 820, baseFuelKgH: 11000, climbFuelKgH: 18200, descentFuelKgH: 4500, climbRateFpm: 1400, ceilingFt: 43100 },
    ],
  },
  airbus: {
    label: { "zh-Hans": "空客", en: "Airbus" },
    aircraft: [
      { code: "A319", label: "A319", econMach: 0.78, maxMach: 0.82, mtowKg: 75500, mlwKg: 62500, zfwKg: 58500, oewKg: 40700, maxFuelKg: 19000, taxiKg: 200, baseFuelKgH: 2050, climbFuelKgH: 3600, descentFuelKgH: 850, climbRateFpm: 2650, ceilingFt: 39800 },
      { code: "A320", label: "A320", econMach: 0.78, maxMach: 0.82, mtowKg: 78000, mlwKg: 66000, zfwKg: 62500, oewKg: 42600, maxFuelKg: 19000, taxiKg: 210, baseFuelKgH: 2200, climbFuelKgH: 3850, descentFuelKgH: 920, climbRateFpm: 2550, ceilingFt: 39800 },
      { code: "A321", label: "A321", econMach: 0.78, maxMach: 0.82, mtowKg: 93500, mlwKg: 77800, zfwKg: 73800, oewKg: 48500, maxFuelKg: 24200, taxiKg: 240, baseFuelKgH: 2600, climbFuelKgH: 4500, descentFuelKgH: 1050, climbRateFpm: 2300, ceilingFt: 39800 },
      { code: "A20N", label: "A320neo", econMach: 0.78, maxMach: 0.82, mtowKg: 79000, mlwKg: 67400, zfwKg: 64300, oewKg: 44500, maxFuelKg: 20000, taxiKg: 210, baseFuelKgH: 2250, climbFuelKgH: 3950, descentFuelKgH: 950, climbRateFpm: 2600, ceilingFt: 39800 },
      { code: "A21N", label: "A321neo", econMach: 0.78, maxMach: 0.82, mtowKg: 97000, mlwKg: 79200, zfwKg: 75600, oewKg: 50200, maxFuelKg: 26700, taxiKg: 250, baseFuelKgH: 2550, climbFuelKgH: 4400, descentFuelKgH: 1050, climbRateFpm: 2350, ceilingFt: 39800 },
      { code: "A332", label: "A330-200", econMach: 0.82, maxMach: 0.86, mtowKg: 242000, mlwKg: 182000, zfwKg: 170000, oewKg: 120600, maxFuelKg: 109185, taxiKg: 420, baseFuelKgH: 5600, climbFuelKgH: 9200, descentFuelKgH: 2300, climbRateFpm: 1900, ceilingFt: 41450 },
      { code: "A333", label: "A330-300", econMach: 0.82, maxMach: 0.86, mtowKg: 242000, mlwKg: 187000, zfwKg: 175000, oewKg: 124500, maxFuelKg: 97530, taxiKg: 430, baseFuelKgH: 5800, climbFuelKgH: 9600, descentFuelKgH: 2400, climbRateFpm: 1850, ceilingFt: 41450 },
      { code: "A339", label: "A330-900neo", econMach: 0.82, maxMach: 0.86, mtowKg: 251000, mlwKg: 191000, zfwKg: 181000, oewKg: 132000, maxFuelKg: 111000, taxiKg: 440, baseFuelKgH: 5500, climbFuelKgH: 9200, descentFuelKgH: 2200, climbRateFpm: 1900, ceilingFt: 41450 },
      { code: "A343", label: "A340-300", econMach: 0.82, maxMach: 0.86, mtowKg: 276500, mlwKg: 192000, zfwKg: 178000, oewKg: 130000, maxFuelKg: 141500, taxiKg: 540, baseFuelKgH: 7600, climbFuelKgH: 12200, descentFuelKgH: 3100, climbRateFpm: 1550, ceilingFt: 41000 },
      { code: "A346", label: "A340-600", econMach: 0.83, maxMach: 0.86, mtowKg: 380000, mlwKg: 259000, zfwKg: 241000, oewKg: 177000, maxFuelKg: 204500, taxiKg: 680, baseFuelKgH: 11200, climbFuelKgH: 17400, descentFuelKgH: 4300, climbRateFpm: 1350, ceilingFt: 41000 },
      { code: "A359", label: "A350-900", econMach: 0.85, maxMach: 0.89, mtowKg: 280000, mlwKg: 207000, zfwKg: 195700, oewKg: 142000, maxFuelKg: 138000, taxiKg: 500, baseFuelKgH: 6100, climbFuelKgH: 10100, descentFuelKgH: 2500, climbRateFpm: 2000, ceilingFt: 43100 },
      { code: "A35K", label: "A350-1000", econMach: 0.85, maxMach: 0.89, mtowKg: 319000, mlwKg: 236000, zfwKg: 223000, oewKg: 155000, maxFuelKg: 156000, taxiKg: 560, baseFuelKgH: 7200, climbFuelKgH: 11700, descentFuelKgH: 2900, climbRateFpm: 1850, ceilingFt: 43100 },
      { code: "A388", label: "A380-800", econMach: 0.85, maxMach: 0.89, mtowKg: 575000, mlwKg: 394000, zfwKg: 361000, oewKg: 277000, maxFuelKg: 253983, taxiKg: 980, baseFuelKgH: 13800, climbFuelKgH: 21900, descentFuelKgH: 5500, climbRateFpm: 1250, ceilingFt: 43100 },
    ],
  },
  embraer: {
    label: { "zh-Hans": "巴航工业", en: "Embraer" },
    aircraft: [
      { code: "E170", label: "E170", econMach: 0.76, maxMach: 0.82, mtowKg: 37200, mlwKg: 34200, zfwKg: 30700, oewKg: 21000, maxFuelKg: 9420, taxiKg: 150, baseFuelKgH: 1350, climbFuelKgH: 2300, descentFuelKgH: 620, climbRateFpm: 2450, ceilingFt: 41000 },
      { code: "E175", label: "E175", econMach: 0.76, maxMach: 0.82, mtowKg: 38790, mlwKg: 34200, zfwKg: 31750, oewKg: 21800, maxFuelKg: 9420, taxiKg: 150, baseFuelKgH: 1450, climbFuelKgH: 2400, descentFuelKgH: 650, climbRateFpm: 2350, ceilingFt: 41000 },
      { code: "E190", label: "E190", econMach: 0.78, maxMach: 0.82, mtowKg: 51800, mlwKg: 44400, zfwKg: 40900, oewKg: 28200, maxFuelKg: 12970, taxiKg: 170, baseFuelKgH: 1850, climbFuelKgH: 3150, descentFuelKgH: 760, climbRateFpm: 2250, ceilingFt: 41000 },
      { code: "E195", label: "E195", econMach: 0.78, maxMach: 0.82, mtowKg: 52290, mlwKg: 45000, zfwKg: 41800, oewKg: 28900, maxFuelKg: 12970, taxiKg: 180, baseFuelKgH: 1950, climbFuelKgH: 3250, descentFuelKgH: 780, climbRateFpm: 2150, ceilingFt: 41000 },
      { code: "E290", label: "E190-E2", econMach: 0.78, maxMach: 0.82, mtowKg: 56400, mlwKg: 49000, zfwKg: 45000, oewKg: 29600, maxFuelKg: 13900, taxiKg: 170, baseFuelKgH: 1700, climbFuelKgH: 2950, descentFuelKgH: 710, climbRateFpm: 2300, ceilingFt: 41000 },
      { code: "E295", label: "E195-E2", econMach: 0.78, maxMach: 0.82, mtowKg: 62300, mlwKg: 54000, zfwKg: 50000, oewKg: 33000, maxFuelKg: 13900, taxiKg: 180, baseFuelKgH: 1900, climbFuelKgH: 3200, descentFuelKgH: 760, climbRateFpm: 2150, ceilingFt: 41000 },
    ],
  },
  bombardier: {
    label: { "zh-Hans": "庞巴迪", en: "Bombardier" },
    aircraft: [
      { code: "CRJ7", label: "CRJ700", econMach: 0.78, maxMach: 0.83, mtowKg: 34020, mlwKg: 30390, zfwKg: 29100, oewKg: 19700, maxFuelKg: 8880, taxiKg: 130, baseFuelKgH: 1300, climbFuelKgH: 2150, descentFuelKgH: 560, climbRateFpm: 2350, ceilingFt: 41000 },
      { code: "CRJ9", label: "CRJ900", econMach: 0.78, maxMach: 0.83, mtowKg: 38330, mlwKg: 33340, zfwKg: 31800, oewKg: 21400, maxFuelKg: 8880, taxiKg: 140, baseFuelKgH: 1450, climbFuelKgH: 2350, descentFuelKgH: 610, climbRateFpm: 2200, ceilingFt: 41000 },
      { code: "CRJX", label: "CRJ1000", econMach: 0.78, maxMach: 0.83, mtowKg: 41277, mlwKg: 36100, zfwKg: 34473, oewKg: 23500, maxFuelKg: 8880, taxiKg: 150, baseFuelKgH: 1600, climbFuelKgH: 2550, descentFuelKgH: 660, climbRateFpm: 2050, ceilingFt: 41000 },
      { code: "BCS1", label: "A220-100", econMach: 0.78, maxMach: 0.82, mtowKg: 63100, mlwKg: 52000, zfwKg: 50000, oewKg: 35700, maxFuelKg: 21918, taxiKg: 180, baseFuelKgH: 1800, climbFuelKgH: 3150, descentFuelKgH: 760, climbRateFpm: 2450, ceilingFt: 41000 },
      { code: "BCS3", label: "A220-300", econMach: 0.78, maxMach: 0.82, mtowKg: 70900, mlwKg: 58700, zfwKg: 55700, oewKg: 39000, maxFuelKg: 21918, taxiKg: 190, baseFuelKgH: 2050, climbFuelKgH: 3500, descentFuelKgH: 820, climbRateFpm: 2300, ceilingFt: 41000 },
    ],
  },
  mcdonnell: {
    label: { "zh-Hans": "麦道", en: "McDonnell Douglas" },
    aircraft: [
      { code: "DC10", label: "DC-10-30", econMach: 0.82, maxMach: 0.88, mtowKg: 263085, mlwKg: 190510, zfwKg: 164654, oewKg: 120700, maxFuelKg: 138700, taxiKg: 600, baseFuelKgH: 8500, climbFuelKgH: 13400, descentFuelKgH: 3400, climbRateFpm: 1450, ceilingFt: 42000 },
      { code: "MD11", label: "MD-11", econMach: 0.82, maxMach: 0.87, mtowKg: 286000, mlwKg: 222900, zfwKg: 202300, oewKg: 130165, maxFuelKg: 146173, taxiKg: 560, baseFuelKgH: 7700, climbFuelKgH: 12300, descentFuelKgH: 3200, climbRateFpm: 1500, ceilingFt: 43000 },
      { code: "MD82", label: "MD-82", econMach: 0.76, maxMach: 0.80, mtowKg: 67812, mlwKg: 58967, zfwKg: 55338, oewKg: 35400, maxFuelKg: 17600, taxiKg: 210, baseFuelKgH: 2700, climbFuelKgH: 4200, descentFuelKgH: 1150, climbRateFpm: 2100, ceilingFt: 37000 },
      { code: "MD88", label: "MD-88", econMach: 0.76, maxMach: 0.80, mtowKg: 67812, mlwKg: 58967, zfwKg: 55338, oewKg: 36000, maxFuelKg: 17700, taxiKg: 210, baseFuelKgH: 2650, climbFuelKgH: 4150, descentFuelKgH: 1120, climbRateFpm: 2050, ceilingFt: 37000 },
      { code: "MD90", label: "MD-90", econMach: 0.76, maxMach: 0.80, mtowKg: 70760, mlwKg: 63500, zfwKg: 59000, oewKg: 39200, maxFuelKg: 17100, taxiKg: 220, baseFuelKgH: 2500, climbFuelKgH: 4000, descentFuelKgH: 1050, climbRateFpm: 2050, ceilingFt: 37000 },
      { code: "B712", label: "717-200", econMach: 0.76, maxMach: 0.82, mtowKg: 54885, mlwKg: 49170, zfwKg: 42900, oewKg: 31100, maxFuelKg: 13800, taxiKg: 190, baseFuelKgH: 2150, climbFuelKgH: 3450, descentFuelKgH: 860, climbRateFpm: 2250, ceilingFt: 37000 },
    ],
  },
  comac: {
    label: { "zh-Hans": "COMAC", en: "COMAC" },
    aircraft: [
      { code: "C919", label: "C919", econMach: 0.78, maxMach: 0.82, mtowKg: 77300, mlwKg: 66600, zfwKg: 62500, oewKg: 42600, maxFuelKg: 19000, taxiKg: 220, baseFuelKgH: 2350, climbFuelKgH: 4000, descentFuelKgH: 980, climbRateFpm: 2450, ceilingFt: 39800 },
      { code: "ARJ21", label: "ARJ21-700", econMach: 0.74, maxMach: 0.78, mtowKg: 43500, mlwKg: 40500, zfwKg: 37400, oewKg: 25150, maxFuelKg: 10100, taxiKg: 150, baseFuelKgH: 1650, climbFuelKgH: 2850, descentFuelKgH: 720, climbRateFpm: 2100, ceilingFt: 39000 },
    ],
  },
});
const KG_TO_LB = 2.2046226218;
const CALC_DEFAULT_MANUFACTURER = "boeing";
const CALC_DEFAULT_AIRCRAFT = "B738";
const CALC_WEATHER_SOURCE_LABELS = Object.freeze({
  ecmwf: "ECMWF",
  gfs: "GFS",
});
const CALC_WEATHER_SOURCE_KEYS = new Set(Object.keys(CALC_WEATHER_SOURCE_LABELS));
const CALC_LAYER_KEYS = new Set(["wind", "cloud", "rain"]);
const CALC_PROFILE_SAMPLE_NM = 8;
const CALC_MAX_PROFILE_POINTS = 420;
const CALC_ROUTE_SIGNATURE_LIMIT = 120;
const CALC_TERRAIN_TILE_ZOOM = 10;
const CALC_TERRAIN_FALLBACK_MAX_FT = 16800;
const CALC_TERRAIN_MAX_RETRIES = 8;
const calculateTerrainRetryCount = new Map();
const calculateTerrainRetryAfter = new Map();
const CALC_WEATHER_LEVELS = Object.freeze([
  { pressure: 900, altitudeFt: 3000 },
  { pressure: 800, altitudeFt: 6400 },
  { pressure: 700, altitudeFt: 10000 },
  { pressure: 600, altitudeFt: 14000 },
  { pressure: 500, altitudeFt: 18000 },
  { pressure: 400, altitudeFt: 24000 },
  { pressure: 300, altitudeFt: 30000 },
  { pressure: 250, altitudeFt: 34000 },
  { pressure: 200, altitudeFt: 39000 },
  { pressure: 150, altitudeFt: 45000 },
]);
const CALC_WEATHER_MODELS = Object.freeze({
  ecmwf: "ecmwf_ifs025",
  gfs: "gfs_seamless",
});
const CALC_WEATHER_MODEL_LABELS = Object.freeze({
  gfs_seamless: "GFS seamless",
  ecmwf_ifs025: "ECMWF IFS 0.25",
});
const CALC_WEATHER_MAX_POINTS = 22;

export const CALCULATE_DEFAULTS = Object.freeze({
  manufacturer: CALC_DEFAULT_MANUFACTURER,
  aircraft: CALC_DEFAULT_AIRCRAFT,
  weatherSource: "ecmwf",
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
    deviceFontSizeReductionPx,
    withDisplayLongitudes,
    normalizeLongitude,
    greatCircleDistanceNm,
    initialBearingDeg,
    procedureCacheKey,
    formatAltitudeRestriction,
    svgPathForProfile,
    apiResourceUrl,
  } = context;
  let calculateSliderFrame = null;

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

  function currentWeightUnit() {
    return state.weightUnit === "kg" ? "kg" : "lb";
  }

  function displayWeightValue(kg) {
    const value = Number(kg);
    if (!Number.isFinite(value)) {
      return NaN;
    }
    return currentWeightUnit() === "lb" ? value * KG_TO_LB : value;
  }

  function formatWeight(kg, { compact = false } = {}) {
    const value = displayWeightValue(kg);
    if (!Number.isFinite(value)) {
      return "--";
    }
    const rounded = compact
      ? Math.round(value / 100) * 100
      : Math.round(value);
    return `${rounded.toLocaleString("en-US")} ${currentWeightUnit()}`;
  }

  function currentPressureUnit() {
    return state.pressureUnit === "hpa" ? "hpa" : "in";
  }

  function formatPressure(hpa) {
    const value = Number(hpa);
    if (!Number.isFinite(value)) {
      return "--";
    }
    if (currentPressureUnit() === "hpa") {
      return `${Math.round(value)} hPa`;
    }
    return `${(value * 0.0295299830714).toFixed(2)} inHg`;
  }

  function formatWeatherTime(iso) {
    if (!iso) {
      return "--";
    }
    const normalized = String(iso).endsWith("Z") ? String(iso) : `${iso}Z`;
    const date = new Date(normalized);
    if (Number.isNaN(date.getTime())) {
      return String(iso).replace("T", " ");
    }
    return `${date.toISOString().slice(0, 16).replace("T", " ")}Z`;
  }

  function formatSignedWindComponent(value) {
    const rounded = Math.round(Math.abs(Number(value) || 0));
    return Number(value) >= 0
      ? t("calculate.componentTail", { value: rounded })
      : t("calculate.componentHead", { value: rounded });
  }

  function windComponentsForCourse(speedKt, windFromDeg, courseDeg) {
    const speed = Math.max(0, Number(speedKt) || 0);
    const fromDeg = ((Number(windFromDeg) || 0) % 360 + 360) % 360;
    const course = ((Number(courseDeg) || 0) % 360 + 360) % 360;
    const relativeWindFromDeg = ((fromDeg - course) % 360 + 360) % 360;
    const relativeWindFromSignedDeg = ((relativeWindFromDeg + 540) % 360) - 180;
    const relativeFromRad = (relativeWindFromSignedDeg * Math.PI) / 180;
    const headwindKt = speed * Math.cos(relativeFromRad);
    const crosswindKt = speed * Math.sin(relativeFromRad);
    const windToDeg = (fromDeg + 180) % 360;
    return {
      windSpeedKt: speed,
      windDirectionDeg: fromDeg,
      windToDeg,
      headwindKt,
      tailwindKt: -headwindKt,
      crosswindKt,
      relativeWindSpeedKt: speed,
      relativeWindDeg: relativeWindFromDeg,
      relativeWindFromDeg,
      relativeWindFromSignedDeg,
    };
  }

  function formatRelativeWindLabel(components, compact = false) {
    const speed = Math.round(Math.max(0, Number(components.windSpeedKt) || 0));
    const signed = Number.isFinite(Number(components.relativeWindFromSignedDeg))
      ? Number(components.relativeWindFromSignedDeg)
      : (((Number(components.relativeWindDeg) || 0) + 540) % 360) - 180;
    const absolute = Math.round(Math.abs(signed));
    let direction;
    if (absolute <= 7) {
      direction = compact ? "F" : "前";
    } else if (absolute >= 173) {
      direction = compact ? "A" : "后";
    } else {
      direction = `${signed > 0 ? (compact ? "R" : "右") : (compact ? "L" : "左")}${absolute}°`;
    }
    return `${direction} ${speed}kt`;
  }

  function interpolateNumber(left, right, ratio) {
    const a = Number(left);
    const b = Number(right);
    if (Number.isFinite(a) && Number.isFinite(b)) {
      return a + (b - a) * ratio;
    }
    return Number.isFinite(a) ? a : b;
  }

  function interpolateDirectionDeg(left, right, ratio) {
    const a = Number(left);
    const b = Number(right);
    if (!Number.isFinite(a) || !Number.isFinite(b)) {
      return Number.isFinite(a) ? ((a % 360) + 360) % 360 : ((b % 360) + 360) % 360;
    }
    const ar = (a * Math.PI) / 180;
    const br = (b * Math.PI) / 180;
    const x = Math.cos(ar) * (1 - ratio) + Math.cos(br) * ratio;
    const y = Math.sin(ar) * (1 - ratio) + Math.sin(br) * ratio;
    return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
  }

  function interpolateWeatherLevel(leftLevel, rightLevel, ratio) {
    if (!leftLevel && !rightLevel) {
      return null;
    }
    const speedKt = interpolateNumber(leftLevel?.speedKt, rightLevel?.speedKt, ratio);
    const directionDeg = interpolateDirectionDeg(leftLevel?.directionDeg, rightLevel?.directionDeg, ratio);
    const cloud = interpolateNumber(leftLevel?.cloud, rightLevel?.cloud, ratio);
    const level = {};
    if (Number.isFinite(speedKt)) {
      level.speedKt = speedKt;
    }
    if (Number.isFinite(directionDeg)) {
      level.directionDeg = directionDeg;
    }
    if (Number.isFinite(cloud)) {
      level.cloud = clampNumber(cloud, 0, 100);
    }
    return Object.keys(level).length ? level : null;
  }

  function formatBriefWeight(kg) {
    const value = displayWeightValue(kg);
    return Number.isFinite(value) ? String(Math.round(value)).padStart(8, " ") : "      --";
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

  function updateCalculateSliderProgress(input) {
    if (!input) {
      return;
    }
    const min = Number(input.min);
    const max = Number(input.max);
    const value = Number(input.value);
    const range = Math.max(0.0001, max - min);
    const progressRatio = clampNumber((value - min) / range, 0, 1);
    const progress = progressRatio * 100;
    input.style.setProperty("--slider-progress", `${progress.toFixed(3)}%`);
    input.style.setProperty("--slider-progress-ratio", progressRatio.toFixed(5));
    input.parentElement?.style.setProperty("--slider-progress", `${progress.toFixed(3)}%`);
    input.parentElement?.style.setProperty("--slider-progress-ratio", progressRatio.toFixed(5));
    const control = input.closest?.(".calculate-slider-control") || input.parentElement;
    if (control) {
      const width = control.getBoundingClientRect?.().width || control.clientWidth || 0;
      const styles = window.getComputedStyle(control);
      const inset = Number.parseFloat(styles.getPropertyValue("--calculate-track-inset")) || 0;
      const thumbSize = Number.parseFloat(styles.getPropertyValue("--calculate-thumb-size")) || 0;
      const trackLength = Math.max(0, width - inset * 2);
      if (trackLength <= 0) {
        return;
      }
      const safeMin = Math.max(inset, thumbSize / 2);
      const safeMax = Math.min(width - inset, width - thumbSize / 2);
      const thumbX = clampNumber(inset + trackLength * progressRatio, safeMin, safeMax);
      control.style.setProperty("--slider-progress-length", `${(trackLength * progressRatio).toFixed(2)}px`);
      control.style.setProperty("--slider-thumb-x", `${thumbX.toFixed(2)}px`);
    }
  }

  function updateCalculateSliderProgresses() {
    [
      elements.calcZfwInput,
      elements.calcFuelInput,
      elements.calcCruiseAltitudeInput,
      elements.calcCruiseMachInput,
      elements.calcDescentRateInput,
      elements.calcProfileZoomInput,
      elements.calcProfilePanInput,
    ].forEach(updateCalculateSliderProgress);
  }

  function scheduleCalculateSliderProgresses() {
    updateCalculateSliderProgresses();
    if (calculateSliderFrame) {
      window.cancelAnimationFrame(calculateSliderFrame);
    }
    calculateSliderFrame = window.requestAnimationFrame(() => {
      calculateSliderFrame = null;
      updateCalculateSliderProgresses();
    });
  }

  function calculateTicksHtml(min, max, interval, formatter) {
    const ticks = [];
    for (let value = min; value <= max + 0.1; value += interval) {
      const position = ((value - min) / Math.max(1, max - min)) * 100;
      ticks.push(`<span style="--tick-position: ${position.toFixed(3)}%;"><i></i><b>${escapeHtml(formatter(value))}</b></span>`);
    }
    return ticks.join("");
  }

  function cruiseAltitudeMaxFt(aircraft = selectedCalculateAircraft()) {
    return clampNumber(Math.round((aircraft.ceilingFt || 60000) / 100) * 100, 10000, 60000);
  }

  function calculateCruiseAltitudeTicksHtml(min, max, formatter) {
    const ticks = [];
    for (let value = min; value <= max + 0.1; value += 10000) {
      ticks.push(value);
    }
    if (!ticks.length || Math.abs(ticks.at(-1) - max) > 100) {
      if (ticks.length > 1 && max - ticks.at(-1) < 4000) {
        ticks.pop();
      }
      ticks.push(max);
    }
    return ticks.map((value) => {
      const position = ((value - min) / Math.max(1, max - min)) * 100;
      return `<span style="--tick-position: ${position.toFixed(3)}%;"><i></i><b>${escapeHtml(formatter(value))}</b></span>`;
    }).join("");
  }

  function calculateMinMaxTicksHtml(min, max, formatter) {
    return [
      { value: min, position: 0 },
      { value: max, position: 100 },
    ].map((tick) => (
      `<span style="--tick-position: ${tick.position.toFixed(3)}%;"><i></i><b>${escapeHtml(formatter(tick.value))}</b></span>`
    )).join("");
  }

  function defaultZfwKg(aircraft) {
    return clampNumber(
      aircraft.oewKg + (aircraft.zfwKg - aircraft.oewKg) * 0.58,
      aircraft.oewKg,
      aircraft.zfwKg,
    );
  }

  function fuelMaxForZfwKg(aircraft, zfwKg) {
    return Math.max(0, Math.min(aircraft.maxFuelKg, aircraft.mtowKg - zfwKg + aircraft.taxiKg));
  }

  function defaultFuelKg(aircraft, zfwKg) {
    const maxFuel = fuelMaxForZfwKg(aircraft, zfwKg);
    return clampNumber(
      Math.max(aircraft.taxiKg + aircraft.baseFuelKgH * 1.6, maxFuel * 0.42),
      0,
      maxFuel,
    );
  }

  function normalizeCalculateWeights({ reset = false } = {}) {
    const aircraft = selectedCalculateAircraft();
    const zfwRaw = state.calculateZfwKg;
    const zfw = Number(zfwRaw);
    const hasZfw = zfwRaw !== null && zfwRaw !== undefined && zfwRaw !== "" && Number.isFinite(zfw);
    state.calculateZfwKg = reset || !hasZfw
      ? defaultZfwKg(aircraft)
      : clampNumber(zfw, aircraft.oewKg, aircraft.zfwKg);
    const maxFuel = fuelMaxForZfwKg(aircraft, state.calculateZfwKg);
    const fuelRaw = state.calculateFuelKg;
    const fuel = Number(fuelRaw);
    const hasFuel = fuelRaw !== null && fuelRaw !== undefined && fuelRaw !== "" && Number.isFinite(fuel);
    state.calculateFuelKg = reset || !hasFuel
      ? defaultFuelKg(aircraft, state.calculateZfwKg)
      : clampNumber(fuel, 0, maxFuel);
  }

  function calculateTakeoffWeightKg(aircraft = selectedCalculateAircraft()) {
    normalizeCalculateWeights();
    return state.calculateZfwKg + Math.max(0, state.calculateFuelKg - aircraft.taxiKg);
  }

  function estimateRangeNm(aircraft = selectedCalculateAircraft(), fuelKg = state.calculateFuelKg) {
    const usableFuel = Math.max(0, fuelKg - aircraft.taxiKg - Math.max(aircraft.baseFuelKgH * 0.75, aircraft.maxFuelKg * 0.08));
    const cruiseAltitude = clampNumber(state.calculateCruiseAltitudeFt || 30000, 10000, Math.min(60000, aircraft.ceilingFt + 4000));
    const altitudeFactor = clampNumber(1.1 - cruiseAltitude / 150000, 0.72, 1.12);
    const speedDelta = ((state.calculateCruiseMach || aircraft.econMach) - aircraft.econMach) / 0.04;
    const speedFactor = 1 + Math.max(0, speedDelta) ** 2 * 0.075;
    const burnKgH = aircraft.baseFuelKgH * altitudeFactor * speedFactor;
    const tasKt = speedOfSoundKtAtAltitude(cruiseAltitude) * (state.calculateCruiseMach || aircraft.econMach);
    return Math.max(0, (usableFuel / Math.max(1, burnKgH)) * tasKt);
  }

  function updateCalculateWeightSummary(profile = state.calculateProfileData) {
    if (!elements.calcWeightSummary) {
      return;
    }
    const aircraft = selectedCalculateAircraft();
    normalizeCalculateWeights();
    const towKg = calculateTakeoffWeightKg(aircraft);
    const tripFuelKg = Math.max(0, profile?.tripFuelKg || 0);
    const ldwKg = clampNumber(towKg - tripFuelKg, state.calculateZfwKg, towKg);
    const rangeNm = estimateRangeNm(aircraft);
    elements.calcWeightSummary.textContent = t("calculate.weightSummary", {
      tow: formatWeight(towKg, { compact: true }),
      ldw: profile ? formatWeight(ldwKg, { compact: true }) : "--",
      range: Math.round(rangeNm).toLocaleString("en-US"),
    });
    const overLimit = towKg > aircraft.mtowKg || ldwKg > aircraft.mlwKg || state.calculateZfwKg > aircraft.zfwKg;
    elements.calcWeightSummary.classList.toggle("is-warning", overLimit);
  }

  function updateCalculateAircraftLimits() {
    const aircraft = selectedCalculateAircraft();
    if (elements.calcAircraftLimits) {
      elements.calcAircraftLimits.textContent = t("calculate.aircraftLimits", {
        mtow: formatWeight(aircraft.mtowKg, { compact: true }),
        mlw: formatWeight(aircraft.mlwKg, { compact: true }),
        mzfw: formatWeight(aircraft.zfwKg, { compact: true }),
        oew: formatWeight(aircraft.oewKg, { compact: true }),
        fuel: formatWeight(aircraft.maxFuelKg, { compact: true }),
        ceiling: formatFlightLevelFromFeet(aircraft.ceilingFt),
      });
    }
  }

  function syncCalculateAircraftControls({ resetMach = false, resetWeights = false } = {}) {
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
    normalizeCalculateWeights({ reset: resetWeights });
    updateCalculateAircraftLimits();
    if (elements.calcCruiseMachInput) {
      elements.calcCruiseMachInput.max = aircraft.maxMach.toFixed(2);
      elements.calcCruiseMachInput.value = state.calculateCruiseMach.toFixed(2);
    }
    if (elements.calcCruiseMachTicks) {
      const max = Number(aircraft.maxMach.toFixed(2));
      elements.calcCruiseMachTicks.innerHTML = [
        { value: 0.5, label: "M0.5", role: "min" },
        { value: aircraft.econMach, label: formatMach(aircraft.econMach), marker: "ECON", role: "econ" },
        { value: max, label: formatMach(max), marker: "MAX", role: "max" },
      ].map((tick) => {
        const position = ((tick.value - 0.5) / Math.max(0.01, max - 0.5)) * 100;
        const marker = tick.marker ? `<em>${escapeHtml(tick.marker)}</em>` : "";
        return `<span data-tick-role="${tick.role}" style="--tick-position: ${position.toFixed(3)}%;">${marker}<i></i><b>${escapeHtml(tick.label)}</b></span>`;
      }).join("");
    }
    updateCalculateSliderProgress(elements.calcCruiseMachInput);
  }

  function syncCalculateControls({ resetMach = false, resetWeights = false } = {}) {
    syncCalculateAircraftControls({ resetMach, resetWeights });
    if (!CALC_WEATHER_SOURCE_KEYS.has(state.calculateWeatherSource)) {
      state.calculateWeatherSource = CALCULATE_DEFAULTS.weatherSource;
    }
    const altitudeValue = Number(state.calculateCruiseAltitudeFt);
    const descentRateValue = Number(state.calculateDescentRateFpm);
    const aircraft = selectedCalculateAircraft();
    const altitudeMax = cruiseAltitudeMaxFt(aircraft);
    state.calculateCruiseAltitudeFt = clampNumber(Number.isFinite(altitudeValue) ? altitudeValue : 30000, 10000, altitudeMax);
    state.calculateDescentRateFpm = clampNumber(Number.isFinite(descentRateValue) ? descentRateValue : 1500, 0, 4000);
    const zoomValue = Number(state.calculateProfileZoom);
    const panValue = Number(state.calculateProfilePanRatio);
    state.calculateProfileZoom = clampNumber(Number.isFinite(zoomValue) ? zoomValue : 1, 1, 4);
    state.calculateProfilePanRatio = clampNumber(Number.isFinite(panValue) ? panValue : 0.5, 0, 1);
    const fuelMax = fuelMaxForZfwKg(aircraft, state.calculateZfwKg);
    if (elements.calcZfwInput) {
      elements.calcZfwInput.min = String(Math.round(aircraft.oewKg));
      elements.calcZfwInput.max = String(Math.round(aircraft.zfwKg));
      elements.calcZfwInput.step = "100";
      elements.calcZfwInput.value = String(Math.round(state.calculateZfwKg));
    }
    if (elements.calcZfwValue) {
      elements.calcZfwValue.textContent = formatWeight(state.calculateZfwKg, { compact: true });
    }
    if (elements.calcZfwTicks) {
      elements.calcZfwTicks.innerHTML = calculateMinMaxTicksHtml(aircraft.oewKg, aircraft.zfwKg, (value) => formatWeight(value, { compact: true }));
    }
    if (elements.calcFuelInput) {
      elements.calcFuelInput.min = "0";
      elements.calcFuelInput.max = String(Math.round(fuelMax));
      elements.calcFuelInput.step = "100";
      elements.calcFuelInput.value = String(Math.round(state.calculateFuelKg));
    }
    if (elements.calcFuelValue) {
      elements.calcFuelValue.textContent = formatWeight(state.calculateFuelKg, { compact: true });
    }
    if (elements.calcFuelTicks) {
      elements.calcFuelTicks.innerHTML = calculateMinMaxTicksHtml(0, fuelMax, (value) => formatWeight(value, { compact: true }));
    }
    if (elements.calcCruiseAltitudeInput) {
      elements.calcCruiseAltitudeInput.max = String(altitudeMax);
      elements.calcCruiseAltitudeInput.value = String(Math.round(state.calculateCruiseAltitudeFt));
    }
    if (elements.calcCruiseAltitudeValue) {
      elements.calcCruiseAltitudeValue.textContent = formatFlightLevelFromFeet(state.calculateCruiseAltitudeFt);
    }
    if (elements.calcCruiseAltitudeTicks) {
      elements.calcCruiseAltitudeTicks.innerHTML = calculateCruiseAltitudeTicksHtml(10000, altitudeMax, (value) => `FL${Math.round(value / 100)}`);
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
      elements.calcDescentRateTicks.innerHTML = calculateTicksHtml(0, 4000, 1000, (value) => String(value));
    }
    if (elements.calcProfileZoomInput) {
      elements.calcProfileZoomInput.value = state.calculateProfileZoom.toFixed(1);
    }
    if (elements.calcProfilePanInput) {
      elements.calcProfilePanInput.value = String(Math.round(state.calculateProfilePanRatio * 100));
      elements.calcProfilePanInput.disabled = state.calculateProfileZoom <= 1.01;
    }
    updateCalculateWeightSummary();
    scheduleCalculateSliderProgresses();
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
    const startLat = (Number(start.lat) * Math.PI) / 180;
    const endLat = (Number(end.lat) * Math.PI) / 180;
    const startLon = (normalizeLongitude(Number(start.originalLon ?? start.lon) || 0) * Math.PI) / 180;
    const endLon = (normalizeLongitude(Number(end.originalLon ?? end.lon) || 0) * Math.PI) / 180;
    const angularDistance = Math.acos(clampNumber(
      Math.sin(startLat) * Math.sin(endLat)
        + Math.cos(startLat) * Math.cos(endLat) * Math.cos(endLon - startLon),
      -1,
      1,
    ));
    if (!Number.isFinite(angularDistance) || angularDistance < 1e-7) {
      const originalLon = normalizeLongitude((Number(start.originalLon ?? start.lon) || 0)
        + normalizeLongitude((Number(end.originalLon ?? end.lon) || 0) - (Number(start.originalLon ?? start.lon) || 0)) * ratio);
      return {
        lat: Number(start.lat) + (Number(end.lat) - Number(start.lat)) * ratio,
        lon: originalLon,
        originalLon,
      };
    }
    const sinDistance = Math.sin(angularDistance);
    const startWeight = Math.sin((1 - ratio) * angularDistance) / sinDistance;
    const endWeight = Math.sin(ratio * angularDistance) / sinDistance;
    const x = startWeight * Math.cos(startLat) * Math.cos(startLon) + endWeight * Math.cos(endLat) * Math.cos(endLon);
    const y = startWeight * Math.cos(startLat) * Math.sin(startLon) + endWeight * Math.cos(endLat) * Math.sin(endLon);
    const z = startWeight * Math.sin(startLat) + endWeight * Math.sin(endLat);
    const originalLon = normalizeLongitude((Math.atan2(y, x) * 180) / Math.PI);
    return {
      lat: (Math.atan2(z, Math.hypot(x, y)) * 180) / Math.PI,
      lon: originalLon,
      originalLon,
    };
  }

  function terrainSampleKey(point) {
    const lon = Number.isFinite(point.originalLon) ? Number(point.originalLon) : Number(point.lon) || 0;
    return `${(Number(point.lat) || 0).toFixed(4)},${lon.toFixed(4)}`;
  }

  function explicitTerrainFt(point) {
    const explicit = [
      point.elevation,
      point.elevation_ft,
      point.airport_elevation,
      point.field_elevation_ft,
    ].map((value) => (value === null || value === "" || value === undefined ? Number.NaN : Number(value))).find(Number.isFinite);
    return Number.isFinite(explicit) ? Math.round(clampNumber(explicit, -1200, 29000)) : null;
  }

  function fallbackTerrainFt(point, totalDistanceNm, distanceNm) {
    const lat = Number(point.lat) || 0;
    const lon = Number.isFinite(point.originalLon) ? Number(point.originalLon) : Number(point.lon) || 0;
    const routeRatio = totalDistanceNm > 0 ? distanceNm / totalDistanceNm : 0;
    const absLat = Math.abs(lat);
    const tibetPlateau = Math.exp(-(((lat - 32) ** 2) / 95 + ((lon - 88) ** 2) / 360)) * 11800;
    const andes = Math.exp(-(((lat + 18) ** 2) / 150 + ((lon + 70) ** 2) / 58)) * 10500;
    const rockies = Math.exp(-(((lat - 42) ** 2) / 180 + ((lon + 112) ** 2) / 95)) * 7600;
    const alps = Math.exp(-(((lat - 46) ** 2) / 20 + ((lon - 10) ** 2) / 45)) * 5400;
    const coastalBias = Math.max(0, Math.cos((lon + routeRatio * 18) * Math.PI / 90)) * Math.max(0, 38 - absLat) * 18;
    return Math.round(clampNumber(Math.max(tibetPlateau, andes, rockies, alps) + coastalBias, 0, CALC_TERRAIN_FALLBACK_MAX_FT));
  }

  function terrainTileForPoint(point, zoom = CALC_TERRAIN_TILE_ZOOM) {
    const lat = clampNumber(Number(point.lat) || 0, -85.0511, 85.0511);
    const lon = normalizeLongitude(Number.isFinite(point.originalLon) ? Number(point.originalLon) : Number(point.lon) || 0);
    const scale = 2 ** zoom;
    const xFloat = ((lon + 180) / 360) * scale;
    const sinLat = Math.sin((lat * Math.PI) / 180);
    const yFloat = (0.5 - Math.log((1 + sinLat) / (1 - sinLat)) / (4 * Math.PI)) * scale;
    const x = clampNumber(Math.floor(xFloat), 0, scale - 1);
    const y = clampNumber(Math.floor(yFloat), 0, scale - 1);
    return {
      zoom,
      x,
      y,
      px: clampNumber((xFloat - x) * 256, 0, 255),
      py: clampNumber((yFloat - y) * 256, 0, 255),
    };
  }

  function terrariumPixelToFeet(r, g, b) {
    const meters = (r * 256 + g + b / 256) - 32768;
    return meters * 3.280839895;
  }

  function terrariumSampleFeet(tileData, px, py) {
    const x0 = clampNumber(Math.floor(px), 0, 255);
    const y0 = clampNumber(Math.floor(py), 0, 255);
    const x1 = clampNumber(x0 + 1, 0, 255);
    const y1 = clampNumber(y0 + 1, 0, 255);
    const fx = clampNumber(px - x0, 0, 1);
    const fy = clampNumber(py - y0, 0, 1);
    const read = (x, y) => {
      const offset = ((y * 256) + x) * 4;
      return terrariumPixelToFeet(tileData[offset], tileData[offset + 1], tileData[offset + 2]);
    };
    const top = read(x0, y0) * (1 - fx) + read(x1, y0) * fx;
    const bottom = read(x0, y1) * (1 - fx) + read(x1, y1) * fx;
    return top * (1 - fy) + bottom * fy;
  }

  async function decodeTerrainTile(blob) {
    const source = typeof window.createImageBitmap === "function"
      ? await window.createImageBitmap(blob)
      : await new Promise((resolve, reject) => {
        const image = new Image();
        const url = URL.createObjectURL(blob);
        image.onload = () => {
          URL.revokeObjectURL(url);
          resolve(image);
        };
        image.onerror = () => {
          URL.revokeObjectURL(url);
          reject(new Error("terrain image decode failed"));
        };
        image.src = url;
      });
    const canvas = document.createElement("canvas");
    canvas.width = 256;
    canvas.height = 256;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    ctx.drawImage(source, 0, 0, 256, 256);
    source.close?.();
    return ctx.getImageData(0, 0, 256, 256).data;
  }

  function queueTerrainTile(tile) {
    const key = `${tile.zoom}/${tile.x}/${tile.y}`;
    const retryAfter = calculateTerrainRetryAfter.get(key) || 0;
    if (state.calculateTerrainTileCache.has(key)
      || state.calculateTerrainPendingTiles.has(key)
      || Date.now() < retryAfter
      || !apiResourceUrl) {
      return;
    }
    state.calculateTerrainPendingTiles.add(key);
    const url = apiResourceUrl(`/api/terrain/terrarium/${tile.zoom}/${tile.x}/${tile.y}.png`);
    fetch(url)
      .then((response) => {
        if (!response.ok) {
          throw new Error(`terrain ${response.status}`);
        }
        const cacheState = String(response.headers.get("X-Map-Cache") || "HIT").toUpperCase();
        if (cacheState !== "HIT") {
          const error = new Error(`terrain cache ${cacheState}`);
          error.terrainPending = cacheState === "QUEUED" || cacheState === "PENDING";
          throw error;
        }
        return response.blob();
      })
      .then(decodeTerrainTile)
      .then((data) => {
        if (!data?.length || (data[3] === 0 && data[(128 * 256 + 128) * 4 + 3] === 0)) {
          const error = new Error("terrain placeholder tile");
          error.terrainPending = true;
          throw error;
        }
        state.calculateTerrainTileCache.set(key, data);
        calculateTerrainRetryCount.delete(key);
        calculateTerrainRetryAfter.delete(key);
        scheduleCalculateRender(40);
      })
      .catch((error) => {
        const attempt = (calculateTerrainRetryCount.get(key) || 0) + 1;
        calculateTerrainRetryCount.set(key, attempt);
        const pending = Boolean(error?.terrainPending);
        const delay = pending
          ? clampNumber(280 + attempt * 180, 350, 1800)
          : clampNumber(1800 * attempt, 2500, 12000);
        const cooldown = attempt <= CALC_TERRAIN_MAX_RETRIES ? delay : 5 * 60 * 1000;
        calculateTerrainRetryAfter.set(key, Date.now() + cooldown);
        if (attempt <= CALC_TERRAIN_MAX_RETRIES) {
          window.setTimeout(() => {
            calculateTerrainRetryAfter.delete(key);
            queueTerrainTile(tile);
          }, delay);
        }
      })
      .finally(() => {
        state.calculateTerrainPendingTiles.delete(key);
      });
  }

  function terrainSampleForPoint(point, totalDistanceNm, distanceNm) {
    const key = terrainSampleKey(point);
    const cached = state.calculateTerrainCache.get(key);
    if (Number.isFinite(cached)) {
      return { elevationFt: cached, source: "dem" };
    }
    const tile = terrainTileForPoint(point);
    const tileKey = `${tile.zoom}/${tile.x}/${tile.y}`;
    const tileData = state.calculateTerrainTileCache.get(tileKey);
    if (tileData) {
      const elevationFt = terrariumSampleFeet(tileData, tile.px, tile.py);
      const normalized = Math.round(clampNumber(elevationFt, -1400, 29000));
      state.calculateTerrainCache.set(key, normalized);
      return { elevationFt: normalized, source: "dem" };
    }
    queueTerrainTile(tile);
    const explicit = explicitTerrainFt(point);
    if (Number.isFinite(explicit)) {
      return { elevationFt: explicit, source: "navdata" };
    }
    return { elevationFt: fallbackTerrainFt(point, totalDistanceNm, distanceNm), source: "estimated" };
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
    const pointDistances = new Array(routePoints.length).fill(null);
    let totalDistanceNm = 0;
    for (let index = 1; index < routePoints.length; index += 1) {
      const start = routePoints[index - 1];
      const end = routePoints[index];
      const distanceNm = greatCircleDistanceNm(start, end);
      if (distanceNm <= 0) {
        continue;
      }
      if (pointDistances[index - 1] === null) {
        pointDistances[index - 1] = totalDistanceNm;
      }
      segments.push({ start, end, startIndex: index - 1, endIndex: index, distanceNm, startDistanceNm: totalDistanceNm });
      totalDistanceNm += distanceNm;
      pointDistances[index] = totalDistanceNm;
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
        const interpolatedPoint = interpolateRoutePoint(segment.start, segment.end, ratio);
        const point = ratio === 0
          ? { ...segment.start, ...interpolatedPoint }
          : (ratio === 1 ? { ...segment.end, ...interpolatedPoint } : interpolatedPoint);
        const distanceNm = segment.startDistanceNm + segment.distanceNm * ratio;
        const terrain = terrainSampleForPoint(point, totalDistanceNm, distanceNm);
        samples.push({
          ...point,
          ident: ratio === 0 ? segment.start.ident : ratio === 1 ? segment.end.ident : "",
          sourceIndex: ratio === 0 ? segment.startIndex : ratio === 1 ? segment.endIndex : null,
          legIndex: segment.startIndex,
          distanceNm,
          courseDeg: 0,
          terrainFt: terrain.elevationFt,
          terrainSource: terrain.source,
        });
      }
    });
    samples.forEach((sample, index) => {
      const next = samples[index + 1];
      const previous = samples[index - 1];
      sample.courseDeg = next
        ? (initialBearingDeg(sample, next) || 0)
        : (previous ? (initialBearingDeg(previous, sample) || 0) : 0);
    });
    const legAnnotations = buildCalculateLegAnnotations(routePoints, pointDistances);
    const adjustablePoints = buildCalculateAdjustablePoints(routePoints, pointDistances, legAnnotations);
    return { points: routePoints, samples, totalDistanceNm, pointDistances, legAnnotations, adjustablePoints };
  }

  function buildCalculateLegAnnotations(routePoints, pointDistances) {
    const legs = (state.currentRoutePayload?.legs || [])
      .filter((leg) => ["airway", "direct"].includes(leg.type));
    const usedRanges = [];
    const findIndexAfter = (ident, afterIndex = 0) => routePoints.findIndex((point, index) => index >= afterIndex && point.ident === ident);
    return legs.map((leg) => {
      const startIndex = findIndexAfter(leg.entry);
      const endIndex = startIndex >= 0 ? findIndexAfter(leg.exit, startIndex) : -1;
      if (startIndex < 0 || endIndex < 0 || endIndex <= startIndex) {
        return null;
      }
      const startNm = Number(pointDistances[startIndex]);
      const endNm = Number(pointDistances[endIndex]);
      if (!Number.isFinite(startNm) || !Number.isFinite(endNm) || endNm <= startNm) {
        return null;
      }
      const duplicate = usedRanges.some((range) => Math.abs(range.startNm - startNm) < 0.1 && Math.abs(range.endNm - endNm) < 0.1);
      if (duplicate) {
        return null;
      }
      const annotation = {
        label: leg.type === "airway" ? leg.name : "DCT",
        entry: leg.entry,
        exit: leg.exit,
        startIndex,
        endIndex,
        startNm,
        endNm,
        midNm: (startNm + endNm) / 2,
        type: leg.type,
      };
      usedRanges.push(annotation);
      return annotation;
    }).filter(Boolean);
  }

  function buildCalculateAdjustablePoints(routePoints, pointDistances, legAnnotations) {
    const byIndex = new Map();
    const preferredLegs = (legAnnotations || []).filter((leg) => leg.type === "airway");
    const sourceLegs = preferredLegs.length ? preferredLegs : (legAnnotations || []);
    sourceLegs.forEach((leg) => {
      [leg.startIndex, leg.endIndex].forEach((index) => {
        if (!routePoints[index] || !Number.isFinite(pointDistances[index])) {
          return;
        }
        const point = routePoints[index];
        byIndex.set(index, {
          ...point,
          sourceIndex: index,
          distanceNm: Number(pointDistances[index]),
          key: `point:${index}`,
        });
      });
    });
    if (!byIndex.size && routePoints[0] && Number.isFinite(pointDistances[0])) {
      byIndex.set(0, { ...routePoints[0], sourceIndex: 0, distanceNm: pointDistances[0], key: "point:0" });
    }
    const lastIndex = routePoints.length - 1;
    if (!byIndex.size && routePoints[lastIndex] && Number.isFinite(pointDistances[lastIndex])) {
      byIndex.set(lastIndex, { ...routePoints[lastIndex], sourceIndex: lastIndex, distanceNm: pointDistances[lastIndex], key: `point:${lastIndex}` });
    }
    return Array.from(byIndex.values()).sort((a, b) => a.distanceNm - b.distanceNm);
  }

  function weatherRequestSignature(route) {
    const source = CALC_WEATHER_SOURCE_KEYS.has(state.calculateWeatherSource)
      ? state.calculateWeatherSource
      : CALCULATE_DEFAULTS.weatherSource;
    const model = CALC_WEATHER_MODELS[source] || CALC_WEATHER_MODELS[CALCULATE_DEFAULTS.weatherSource];
    const hour = new Date().toISOString().slice(0, 13);
    const points = (route?.points || [])
      .filter((_, index) => index === 0 || index === route.points.length - 1 || index % 6 === 0)
      .map((point) => `${(Number(point.lat) || 0).toFixed(2)},${(Number(point.originalLon ?? point.lon) || 0).toFixed(2)}`)
      .join("|");
    return `${source}:${model}:${hour}:${points}`;
  }

  function selectWeatherRequestSamples(route) {
    if (!route?.samples?.length) {
      return [];
    }
    const selected = [];
    const slots = Math.min(CALC_WEATHER_MAX_POINTS, Math.max(3, Math.ceil(route.totalDistanceNm / 85)));
    for (let index = 0; index < slots; index += 1) {
      const ratio = index / Math.max(1, slots - 1);
      const distance = ratio * route.totalDistanceNm;
      const nearest = route.samples.reduce((best, sample) => (
        Math.abs(sample.distanceNm - distance) < Math.abs(best.distanceNm - distance) ? sample : best
      ), route.samples[0]);
      if (!selected.some((item) => Math.abs(item.distanceNm - nearest.distanceNm) < 0.5)) {
        selected.push(nearest);
      }
    }
    return selected;
  }

  function nearestWeatherHourIndex(times = []) {
    const now = Date.now();
    let bestIndex = 0;
    let bestDistance = Infinity;
    times.forEach((time, index) => {
      const date = new Date(`${time}${String(time).endsWith("Z") ? "" : "Z"}`);
      const stamp = date.getTime();
      if (!Number.isFinite(stamp)) {
        return;
      }
      const distance = stamp <= now ? now - stamp : (stamp - now) + 3_600_000;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    });
    return bestIndex;
  }

  function normalizeWeatherPayload(payload, requestSamples, source, updatedHeader) {
    const payloads = Array.isArray(payload) ? payload : [payload];
    const points = payloads.map((item, index) => {
      const hourly = item?.hourly || {};
      const times = hourly.time || [];
      const timeIndex = nearestWeatherHourIndex(times);
      const sourceSample = requestSamples[index] || requestSamples.at(-1) || {};
      const levels = {};
      CALC_WEATHER_LEVELS.forEach((level) => {
        const speed = Number(hourly[`wind_speed_${level.pressure}hPa`]?.[timeIndex]);
        const direction = Number(hourly[`wind_direction_${level.pressure}hPa`]?.[timeIndex]);
        const cloudLevel = Number(hourly[`cloud_cover_${level.pressure}hPa`]?.[timeIndex]);
        if (Number.isFinite(speed) || Number.isFinite(direction) || Number.isFinite(cloudLevel)) {
          const levelData = {};
          if (Number.isFinite(speed)) {
            levelData.speedKt = speed;
          }
          if (Number.isFinite(direction)) {
            levelData.directionDeg = ((direction % 360) + 360) % 360;
          }
          if (Number.isFinite(cloudLevel)) {
            levelData.cloud = clampNumber(cloudLevel, 0, 100);
          }
          levels[level.pressure] = levelData;
        }
      });
      const precipitation = Number(hourly.precipitation?.[timeIndex]);
      const rain = Number(hourly.rain?.[timeIndex]);
      const showers = Number(hourly.showers?.[timeIndex]);
      const cape = Number(hourly.cape?.[timeIndex]);
      const pressureMsl = Number(hourly.pressure_msl?.[timeIndex]);
      const cloudRaw = Number(hourly.cloud_cover?.[timeIndex]);
      const cloudLowRaw = Number(hourly.cloud_cover_low?.[timeIndex]);
      const cloudMidRaw = Number(hourly.cloud_cover_mid?.[timeIndex]);
      const cloudHighRaw = Number(hourly.cloud_cover_high?.[timeIndex]);
      const cloud = clampNumber(Number.isFinite(cloudRaw) ? cloudRaw : 0, 0, 100);
      return {
        distanceNm: Number(sourceSample.distanceNm) || 0,
        lat: Number(item?.latitude) || Number(sourceSample.lat) || 0,
        lon: Number(item?.longitude) || Number(sourceSample.originalLon ?? sourceSample.lon) || 0,
        elevationFt: Number.isFinite(Number(item?.elevation)) ? Number(item.elevation) * 3.280839895 : NaN,
        weatherTime: times[timeIndex] || "",
        cloud,
        cloudLow: Number.isFinite(cloudLowRaw) ? clampNumber(cloudLowRaw, 0, 100) : clampNumber(cloud * 0.46, 0, 100),
        cloudMid: Number.isFinite(cloudMidRaw) ? clampNumber(cloudMidRaw, 0, 100) : clampNumber(cloud * 0.36, 0, 100),
        cloudHigh: Number.isFinite(cloudHighRaw) ? clampNumber(cloudHighRaw, 0, 100) : clampNumber(cloud * 0.28, 0, 100),
        rainMmH: clampNumber(Number.isFinite(precipitation) ? precipitation : Number.isFinite(rain) ? rain : 0, 0, 80),
        convectiveRainMmH: clampNumber(Number.isFinite(showers) ? showers : 0, 0, 80),
        cape: Number.isFinite(cape) ? cape : 0,
        qnhHpa: Number.isFinite(pressureMsl) ? pressureMsl : NaN,
        levels,
      };
    }).filter((point) => Object.keys(point.levels).length);
    return {
      source,
      model: CALC_WEATHER_MODELS[source] || CALC_WEATHER_MODELS[CALCULATE_DEFAULTS.weatherSource],
      updatedAt: updatedHeader || new Date().toUTCString(),
      weatherTime: points.find((point) => point.weatherTime)?.weatherTime || "",
      points,
    };
  }

  async function requestCalculateOnlineWeather(route, signature) {
    const source = CALC_WEATHER_SOURCE_KEYS.has(state.calculateWeatherSource)
      ? state.calculateWeatherSource
      : CALCULATE_DEFAULTS.weatherSource;
    const requestSamples = selectWeatherRequestSamples(route);
    if (!requestSamples.length) {
      return;
    }
      const hourly = [
      ...CALC_WEATHER_LEVELS.flatMap((level) => [
        `wind_speed_${level.pressure}hPa`,
        `wind_direction_${level.pressure}hPa`,
        `cloud_cover_${level.pressure}hPa`,
      ]),
      "cloud_cover",
      "cloud_cover_low",
      "cloud_cover_mid",
      "cloud_cover_high",
      "precipitation",
      "rain",
      "showers",
      "cape",
      "surface_pressure",
      "pressure_msl",
    ].join(",");
    const params = new URLSearchParams({
      latitude: requestSamples.map((sample) => Number(sample.lat).toFixed(4)).join(","),
      longitude: requestSamples.map((sample) => Number(sample.originalLon ?? sample.lon).toFixed(4)).join(","),
      hourly,
      forecast_days: "1",
      timezone: "UTC",
      wind_speed_unit: "kn",
      precipitation_unit: "mm",
      models: CALC_WEATHER_MODELS[source] || CALC_WEATHER_MODELS[CALCULATE_DEFAULTS.weatherSource],
    });
    state.calculateOnlineWeatherPending = true;
    state.calculateOnlineWeatherError = "";
    try {
      const response = await fetch(apiResourceUrl(`/api/weather/open-meteo?${params.toString()}`));
      const updatedHeader = response.headers.get("X-Weather-Updated") || response.headers.get("Date") || "";
      if (!response.ok) {
        throw new Error(`weather ${response.status}`);
      }
      const payload = await response.json();
      const normalized = normalizeWeatherPayload(payload, requestSamples, source, updatedHeader);
      if (state.calculateOnlineWeatherSignature === signature && normalized.points.length) {
        state.calculateOnlineWeather = normalized;
        state.calculateOnlineWeatherError = "";
      }
    } catch (error) {
      if (state.calculateOnlineWeatherSignature === signature) {
        state.calculateOnlineWeather = null;
        state.calculateOnlineWeatherError = error?.message || "weather request failed";
      }
    } finally {
      if (state.calculateOnlineWeatherSignature === signature) {
        state.calculateOnlineWeatherPending = false;
      }
      scheduleCalculateRender(40);
    }
  }

  function ensureCalculateOnlineWeather(route) {
    const signature = weatherRequestSignature(route);
    if (state.calculateOnlineWeatherSignature === signature) {
      return;
    }
    state.calculateOnlineWeatherSignature = signature;
    state.calculateOnlineWeather = null;
    state.calculateOnlineWeatherError = "";
    requestCalculateOnlineWeather(route, signature);
  }

  function onlineWeatherPointForDistance(distanceNm) {
    const points = [...(state.calculateOnlineWeather?.points || [])]
      .filter((point) => Number.isFinite(Number(point.distanceNm)))
      .sort((left, right) => left.distanceNm - right.distanceNm);
    if (!points.length) {
      return null;
    }
    const targetDistance = Number(distanceNm) || 0;
    if (targetDistance <= points[0].distanceNm || points.length === 1) {
      return points[0];
    }
    const lastPoint = points.at(-1);
    if (targetDistance >= lastPoint.distanceNm) {
      return lastPoint;
    }
    let rightIndex = points.findIndex((point) => point.distanceNm >= targetDistance);
    if (rightIndex <= 0) {
      rightIndex = 1;
    }
    const left = points[rightIndex - 1];
    const right = points[rightIndex];
    const ratio = clampNumber((targetDistance - left.distanceNm) / Math.max(0.001, right.distanceNm - left.distanceNm), 0, 1);
    const levels = {};
    CALC_WEATHER_LEVELS.forEach((level) => {
      const interpolated = interpolateWeatherLevel(left.levels?.[level.pressure], right.levels?.[level.pressure], ratio);
      if (interpolated) {
        levels[level.pressure] = interpolated;
      }
    });
    return {
      ...left,
      distanceNm: targetDistance,
      lat: interpolateNumber(left.lat, right.lat, ratio),
      lon: interpolateNumber(left.lon, right.lon, ratio),
      elevationFt: interpolateNumber(left.elevationFt, right.elevationFt, ratio),
      cloud: clampNumber(interpolateNumber(left.cloud, right.cloud, ratio) || 0, 0, 100),
      cloudLow: clampNumber(interpolateNumber(left.cloudLow, right.cloudLow, ratio) || 0, 0, 100),
      cloudMid: clampNumber(interpolateNumber(left.cloudMid, right.cloudMid, ratio) || 0, 0, 100),
      cloudHigh: clampNumber(interpolateNumber(left.cloudHigh, right.cloudHigh, ratio) || 0, 0, 100),
      rainMmH: clampNumber(interpolateNumber(left.rainMmH, right.rainMmH, ratio) || 0, 0, 80),
      convectiveRainMmH: clampNumber(interpolateNumber(left.convectiveRainMmH, right.convectiveRainMmH, ratio) || 0, 0, 80),
      cape: clampNumber(interpolateNumber(left.cape, right.cape, ratio) || 0, 0, 8000),
      qnhHpa: interpolateNumber(left.qnhHpa, right.qnhHpa, ratio),
      weatherTime: ratio < 0.5 ? left.weatherTime : right.weatherTime,
      levels,
    };
  }

  function onlineWindAt(sample, altitudeFt) {
    const point = onlineWeatherPointForDistance(sample.distanceNm);
    if (!point) {
      return null;
    }
    const windLevels = CALC_WEATHER_LEVELS
      .map((item) => ({ level: item, wind: point.levels[item.pressure] }))
      .filter((item) => Number.isFinite(item.wind?.speedKt) && Number.isFinite(item.wind?.directionDeg));
    if (!windLevels.length) {
      return null;
    }
    const { level, wind } = windLevels.reduce((best, item) => (
      Math.abs(item.level.altitudeFt - altitudeFt) < Math.abs(best.level.altitudeFt - altitudeFt) ? item : best
    ), windLevels[0]);
    const components = windComponentsForCourse(wind.speedKt, wind.directionDeg, sample.courseDeg);
    return {
      ...components,
      cloud: Number.isFinite(wind.cloud) ? wind.cloud : point.cloud,
      cloudLow: point.cloudLow,
      cloudMid: point.cloudMid,
      cloudHigh: point.cloudHigh,
      cloudLevels: point.levels,
      rainMmH: point.rainMmH,
      convectiveRainMmH: point.convectiveRainMmH,
      cape: point.cape,
      qnhHpa: point.qnhHpa,
      weatherTime: point.weatherTime,
      levelPressure: level.pressure,
    };
  }

  function speedOfSoundKtAtAltitude(altitudeFt) {
    const altitude = clampNumber(Number(altitudeFt) || 0, 0, 60000);
    const temperatureC = altitude <= 36089 ? 15 - 0.0019812 * altitude : -56.5;
    return 38.967854 * Math.sqrt(Math.max(150, temperatureC + 273.15));
  }

  function calculateAtmosphereAt(sample, altitudeFt, sourceKey = state.calculateWeatherSource) {
    const online = onlineWindAt(sample, altitudeFt);
    if (online) {
      const isaDeviationC = clampNumber(Math.sin(((Number(sample.lat) || 0) * 0.4 + altitudeFt / 9000) * Math.PI / 12) * 4, -12, 12);
      return {
        ...online,
        isaDeviationC,
      };
    }
    const sourceShift = { ecmwf: 0.58, gfs: 1.14 }[sourceKey] || 0.58;
    const lat = Number(sample.lat) || 0;
    const lon = Number.isFinite(sample.originalLon) ? Number(sample.originalLon) : Number(sample.lon) || 0;
    const flightLevel = Math.max(0, altitudeFt / 100);
    const wave = Math.sin((sample.distanceNm * 0.035 + lat * 0.18 + sourceShift) * Math.PI);
    const cross = Math.cos((lon * 0.12 - flightLevel * 0.025 + sourceShift * 1.8) * Math.PI);
    const windSpeedKt = clampNumber(18 + flightLevel * 0.12 + wave * 22 + cross * 11, 0, 145);
    const windDirectionDeg = (sample.courseDeg + 210 + wave * 54 + sourceShift * 38 + lon * 0.08 + 720) % 360;
    const wind = windComponentsForCourse(windSpeedKt, windDirectionDeg, sample.courseDeg);
    const cloud = clampNumber(42 + wave * 34 + Math.sin((lat + lon + sourceShift * 44) * Math.PI / 42) * 18, 0, 100);
    const rainMmH = cloud > 60 ? clampNumber(((cloud - 58) / 42) * (1 + Math.max(0, cross)) * 5.2, 0, 12) : 0;
    const convectiveRainMmH = rainMmH > 0 ? clampNumber(rainMmH * Math.max(0, cross), 0, 12) : 0;
    const isaDeviationC = clampNumber(Math.sin((lat * 0.35 + lon * 0.12 + sourceShift * 40) * Math.PI / 90) * 8 + wave * 3, -18, 18);
    const cloudLow = clampNumber(cloud * (rainMmH > 0 ? 0.72 : 0.34) + Math.max(0, cross) * 12, 0, 100);
    const cloudMid = clampNumber(cloud * 0.54 + Math.max(0, wave) * 18, 0, 100);
    const cloudHigh = clampNumber(cloud * 0.42 + Math.max(0, -cross) * 16, 0, 100);
    return { ...wind, cloud, cloudLow, cloudMid, cloudHigh, rainMmH, convectiveRainMmH, isaDeviationC };
  }

  function calculateClimbRateFpm(aircraft, altitudeFt, weightKg = calculateTakeoffWeightKg(aircraft)) {
    const altitudeFactor = clampNumber(1.08 - (Number(altitudeFt) || 0) / Math.max(52000, aircraft.ceilingFt * 1.35), 0.44, 1.08);
    const weightRatio = clampNumber((weightKg - aircraft.oewKg) / Math.max(1, aircraft.mtowKg - aircraft.oewKg), 0, 1.2);
    const weightFactor = clampNumber(1.08 - weightRatio * 0.34, 0.62, 1.08);
    return clampNumber((aircraft.climbRateFpm || 2000) * altitudeFactor * weightFactor, 450, 3600);
  }

  function calculateBaseAltitudeAtDistance(distanceNm, terrainFt, totalDistanceNm, aircraft) {
    const cruise = state.calculateCruiseAltitudeFt;
    const takeoffWeight = calculateTakeoffWeightKg(aircraft);
    const avgClimbRate = calculateClimbRateFpm(aircraft, cruise * 0.52, takeoffWeight);
    const climbSpeed = clampNumber(speedOfSoundKtAtAltitude(cruise * 0.45) * Math.min(state.calculateCruiseMach || aircraft.econMach, aircraft.econMach), 230, 340);
    const climbDistanceNm = clampNumber((cruise / Math.max(450, avgClimbRate)) * (climbSpeed / 60), 24, Math.max(34, totalDistanceNm * 0.35));
    const descentRate = Math.max(300, state.calculateDescentRateFpm || 1500);
    const descentSpeed = clampNumber(speedOfSoundKtAtAltitude(cruise * 0.55) * Math.min(state.calculateCruiseMach || aircraft.econMach, 0.80), 240, 340);
    const descentDistanceNm = clampNumber((cruise / descentRate) * (descentSpeed / 60), 22, Math.max(28, totalDistanceNm * 0.38));
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
        const altitude1 = item.altitude1 === null || item.altitude1 === "" ? null : Number(item.altitude1);
        const altitude2 = item.altitude2 === null || item.altitude2 === "" ? null : Number(item.altitude2);
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
        if (!best || bestDistance > 30) {
          return;
        }
        const descriptor = String(item.altitude_description || "").trim();
        let kind = "exact";
        let minFt = null;
        let maxFt = null;
        if (descriptor === "+") {
          kind = "above";
          minFt = altitude1;
        } else if (descriptor === "-") {
          kind = "below";
          maxFt = altitude1;
        } else if (descriptor === "B" && Number.isFinite(altitude1) && Number.isFinite(altitude2)) {
          kind = "between";
          minFt = Math.min(altitude1, altitude2);
          maxFt = Math.max(altitude1, altitude2);
        } else {
          const exactFt = Number.isFinite(altitude1) ? altitude1 : altitude2;
          minFt = exactFt;
          maxFt = exactFt;
        }
        constraints.push({
          type,
          ident: item.waypoint_identifier || "",
          label: formatAltitudeRestriction(item),
          distanceNm: best.distanceNm,
          kind,
          minFt,
          maxFt,
        });
      });
    });
    const deduplicated = new Map();
    constraints
      .sort((left, right) => left.distanceNm - right.distanceNm)
      .forEach((constraint) => {
        const key = [
          constraint.type,
          constraint.kind,
          Math.round((constraint.minFt || 0) / 50),
          Math.round((constraint.maxFt || 0) / 50),
          Math.round(constraint.distanceNm / 2),
        ].join(":");
        if (!deduplicated.has(key)) {
          deduplicated.set(key, { ...constraint, mergedCount: 1 });
        } else {
          deduplicated.get(key).mergedCount += 1;
        }
      });
    return Array.from(deduplicated.values());
  }

  function buildCalculateProfile() {
    const route = buildCalculateRouteSamples();
    if (!route) {
      return null;
    }
    ensureCalculateOnlineWeather(route);
    const aircraft = selectedCalculateAircraft();
    normalizeCalculateWeights();
    const takeoffWeightKg = calculateTakeoffWeightKg(aircraft);
    const samples = route.samples.map((sample, index) => {
      const base = calculateBaseAltitudeAtDistance(sample.distanceNm, sample.terrainFt, route.totalDistanceNm, aircraft);
      const profileLeg = route.legAnnotations.find((leg) => sample.distanceNm >= leg.startNm - 0.1 && sample.distanceNm <= leg.endNm + 0.1);
      const profileLegKey = profileLeg ? `leg:${profileLeg.startIndex}:${profileLeg.endIndex}` : `leg:${sample.legIndex}`;
      const override = state.calculateAltitudeOverrides.get(profileLegKey);
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
        profileLegKey,
        altitudeFt,
        phase: base.phase,
        todNm: base.todNm,
        climbDistanceNm: base.climbDistanceNm,
        descentDistanceNm: base.descentDistanceNm,
        tasKt,
        groundSpeedKt,
        verticalSpeedFpm: base.phase === "climb"
          ? calculateClimbRateFpm(aircraft, altitudeFt, takeoffWeightKg)
          : (base.phase === "descent" ? -Math.max(300, state.calculateDescentRateFpm || 1500) : 0),
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
      const weightRatio = clampNumber(((state.calculateZfwKg + Math.max(0, state.calculateFuelKg - previous.fuelKg)) - aircraft.oewKg) / Math.max(1, aircraft.mtowKg - aircraft.oewKg), 0, 1.15);
      const weightFactor = clampNumber(0.86 + weightRatio * 0.28, 0.9, 1.18);
      const fuelKg = phaseRate * altitudeFactor * speedFactor * weightFactor * (minutes / 60);
      cumulativeTime += minutes;
      tripFuelKg += fuelKg;
      weightedWind += ((previous.tailwindKt + current.tailwindKt) / 2) * distanceNm;
      current.timeMinutes = cumulativeTime;
      current.fuelKg = tripFuelKg;
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
      weatherMeta: state.calculateOnlineWeather,
      weatherOnline: Boolean(state.calculateOnlineWeather?.points?.length),
      todNm: samples[0]?.todNm || 0,
      tocNm: samples[0]?.climbDistanceNm || 0,
      zfwKg: state.calculateZfwKg,
      blockFuelKg: state.calculateFuelKg,
      takeoffWeightKg,
      landingWeightKg: clampNumber(takeoffWeightKg - tripFuelKg, state.calculateZfwKg, takeoffWeightKg),
    };
  }

  function calculateProfileViewport(totalDistanceNm) {
    const total = Math.max(1, totalDistanceNm);
    const zoom = clampNumber(state.calculateProfileZoom || 1, 1, 4);
    const visible = total / zoom;
    const minCenter = visible / 2;
    const maxCenter = total - visible / 2;
    const panValue = Number(state.calculateProfilePanRatio);
    const panRatio = zoom <= 1.01 ? 0.5 : clampNumber(Number.isFinite(panValue) ? panValue : 0.5, 0, 1);
    const center = minCenter + (maxCenter - minCenter) * panRatio;
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
      grid: dayTheme ? "rgba(58, 74, 88, 0.105)" : "rgba(214, 226, 238, 0.15)",
      gridStrong: dayTheme ? "rgba(58, 74, 88, 0.17)" : "rgba(214, 226, 238, 0.22)",
      axis: dayTheme ? "rgba(18, 30, 42, 0.53)" : "rgba(226, 239, 250, 0.48)",
      label: dayTheme ? "rgba(18, 29, 40, 0.81)" : "rgba(224, 238, 250, 0.84)",
      muted: dayTheme ? "rgba(43, 55, 66, 0.59)" : "rgba(216, 228, 238, 0.66)",
      plotBg: "transparent",
      terrainLow: dayTheme ? "#22a987" : "#168148",
      terrainMid: dayTheme ? "#6bd0bc" : "#54be9d",
      terrainHigh: dayTheme ? "#b7ece1" : "#96e0c8",
      terrainStroke: dayTheme ? "rgba(24, 145, 126, 0.88)" : "rgba(107, 226, 188, 0.84)",
      route: "#b00018",
      point: "#fff025",
      speed: "rgba(26, 148, 140, 0.84)",
      speedFill: dayTheme ? "rgba(112, 206, 216, 0.21)" : "rgba(89, 201, 214, 0.20)",
      vs: "rgba(245, 133, 93, 0.84)",
      cloud: dayTheme ? "rgba(202, 222, 250, 0.34)" : "rgba(180, 205, 238, 0.22)",
      cloudCore: dayTheme ? "rgba(176, 207, 246, 0.40)" : "rgba(205, 222, 246, 0.28)",
      cloudDense: dayTheme ? "rgba(145, 189, 238, 0.44)" : "rgba(224, 234, 250, 0.34)",
      cloudStroke: dayTheme ? "rgba(126, 170, 224, 0.22)" : "rgba(216, 230, 250, 0.22)",
      rain: "rgba(46, 122, 255, 0.86)",
      convectiveRain: "rgba(154, 59, 238, 0.88)",
      rainLabel: dayTheme ? "rgba(0, 42, 150, 0.94)" : "rgba(151, 190, 255, 0.96)",
      convectiveRainLabel: dayTheme ? "rgba(104, 35, 168, 0.94)" : "rgba(220, 180, 255, 0.96)",
      wind: dayTheme ? "rgba(21, 29, 37, 0.74)" : "rgba(230, 238, 246, 0.76)",
      windTail: dayTheme ? "rgba(21, 29, 37, 0.74)" : "rgba(230, 238, 246, 0.76)",
      windHead: dayTheme ? "rgba(21, 29, 37, 0.74)" : "rgba(230, 238, 246, 0.76)",
      constraint: dayTheme ? "rgba(136, 91, 242, 0.64)" : "rgba(176, 142, 255, 0.70)",
    };
  }

  function svgText(x, y, text, options = {}) {
    const family = options.family ? ` font-family="${escapeHtml(options.family)}"` : "";
    const size = Math.max(1, options.size - deviceFontSizeReductionPx());
    return `<text x="${x.toFixed(1)}" y="${y.toFixed(1)}" fill="${options.fill}" font-size="${size.toFixed(1)}" font-weight="${options.weight || 760}" text-anchor="${options.anchor || "middle"}"${family}>${escapeHtml(text)}</text>`;
  }

  function drawRelativeWindBarbSvg(x, y, components, colors) {
    const speedKt = Math.max(0, Number(components.windSpeedKt) || 0);
    const length = clampNumber(7.5 + speedKt * 0.075, 10, 16);
    const angle = ((Number(components.relativeWindDeg) || 0) * Math.PI) / 180;
    const stroke = components.tailwindKt >= 0 ? colors.windTail : colors.windHead;
    const x2 = x + Math.sin(angle) * length;
    const y2 = y - Math.cos(angle) * length;
    const featherCount = clampNumber(Math.round(speedKt / 22), 1, 3);
    const featherPieces = [];
    for (let index = 0; index < featherCount; index += 1) {
      const ratio = 0.34 + index * 0.17;
      const bx = x + (x2 - x) * ratio;
      const by = y + (y2 - y) * ratio;
      const sideAngle = angle + Math.PI * 0.72;
      const featherLength = 3.4 + Math.min(5.4, speedKt / 24);
      const fx = bx + Math.sin(sideAngle) * featherLength;
      const fy = by - Math.cos(sideAngle) * featherLength;
      featherPieces.push(`<line x1="${bx.toFixed(1)}" y1="${by.toFixed(1)}" x2="${fx.toFixed(1)}" y2="${fy.toFixed(1)}" stroke="${stroke}" stroke-width="0.82" stroke-linecap="round" />`);
    }
    return `
      <line x1="${x.toFixed(1)}" y1="${y.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="${stroke}" stroke-width="0.96" stroke-linecap="round" />
      ${featherPieces.join("")}
    `;
  }

  function calculateProfileAltitudeMax(profile) {
    const sampleMax = Math.max(
      0,
      ...(profile?.samples || []).map((sample) => Number(sample.altitudeFt) || 0),
      ...(profile?.constraints || []).map((constraint) => Math.max(Number(constraint.maxFt) || 0, Number(constraint.minFt) || 0)),
      Number(state.calculateCruiseAltitudeFt) || 0,
    );
    const desired = Math.ceil((sampleMax + 3000) / 5000) * 5000;
    return clampNumber(Math.max(45000, desired), 45000, 60000);
  }

  function calculateWeatherCycleLabel(profile) {
    const source = CALC_WEATHER_SOURCE_LABELS[state.calculateWeatherSource] || "ECMWF";
    const time = profile?.weatherMeta?.weatherTime;
    if (!time) {
      return profile?.weatherOnline ? source : `${source} / 本地估算`;
    }
    const formatted = formatWeatherTime(time);
    const hour = formatted.match(/(\d{2}):00Z$/)?.[1];
    return hour ? `${source} ${hour}Z` : `${source} ${formatted}`;
  }

  function altitudeFeetForPressureHpa(pressureHpa) {
    const pressure = clampNumber(Number(pressureHpa) || 1013.25, 1, 1100);
    const altitudeMeters = 44330.77 * (1 - Math.pow(pressure / 1013.25, 0.190263));
    return altitudeMeters * 3.28084;
  }

  function nearestProfileSample(samples, distanceNm) {
    return samples.reduce((best, sample) => (
      Math.abs(sample.distanceNm - distanceNm) < Math.abs(best.distanceNm - distanceNm) ? sample : best
    ), samples[0]);
  }

  function cloudValueForBand(sample, key) {
    const value = Number(sample[key]);
    if (Number.isFinite(value)) {
      return clampNumber(value, 0, 100);
    }
    const total = clampNumber(Number(sample.cloud) || 0, 0, 100);
    if (key === "cloudLow") {
      return clampNumber(total * (sample.rainMmH > 0.05 ? 0.74 : 0.36), 0, 100);
    }
    if (key === "cloudMid") {
      return clampNumber(total * 0.54, 0, 100);
    }
    return clampNumber(total * 0.42, 0, 100);
  }

  function cloudBandBounds(sample, band, coverage) {
    const wave = Math.sin((sample.distanceNm * 0.026 + band.phase) * Math.PI) * band.waveFt;
    if (band.key === "cloudLow") {
      const lower = clampNumber(Math.max(sample.terrainFt + 700, 1400 + wave * 0.2), 800, 9200);
      const upper = clampNumber(lower + 1100 + coverage * 55 + (sample.rainMmH || 0) * 90, lower + 800, 13200);
      return { lower, upper };
    }
    const center = band.centerFt + wave + (coverage - 45) * band.coverLiftFt;
    const thickness = band.minThicknessFt + coverage * band.thicknessScaleFt;
    return {
      lower: clampNumber(center - thickness / 2, band.minFt, band.maxFt - 600),
      upper: clampNumber(center + thickness / 2, band.minFt + 600, band.maxFt),
    };
  }

  function smoothSvgPathForPoints(points, { omitMove = false } = {}) {
    const safePoints = points.filter((point) => Number.isFinite(point.x) && Number.isFinite(point.y));
    if (!safePoints.length) {
      return "";
    }
    if (safePoints.length === 1) {
      return `${omitMove ? "L" : "M"}${safePoints[0].x.toFixed(1)} ${safePoints[0].y.toFixed(1)}`;
    }
    const pieces = omitMove
      ? [`L${safePoints[0].x.toFixed(1)} ${safePoints[0].y.toFixed(1)}`]
      : [`M${safePoints[0].x.toFixed(1)} ${safePoints[0].y.toFixed(1)}`];
    for (let index = 1; index < safePoints.length - 1; index += 1) {
      const current = safePoints[index];
      const next = safePoints[index + 1];
      const midX = (current.x + next.x) / 2;
      const midY = (current.y + next.y) / 2;
      pieces.push(`Q${current.x.toFixed(1)} ${current.y.toFixed(1)} ${midX.toFixed(1)} ${midY.toFixed(1)}`);
    }
    const last = safePoints.at(-1);
    pieces.push(`L${last.x.toFixed(1)} ${last.y.toFixed(1)}`);
    return pieces.join(" ");
  }

  function hasPressureCloudData(sample) {
    return CALC_WEATHER_LEVELS.some((level) => Number.isFinite(Number(sample.cloudLevels?.[level.pressure]?.cloud)));
  }

  function cloudCoverageForPressureLevel(sample, level) {
    const pressureValue = Number(sample.cloudLevels?.[level.pressure]?.cloud);
    if (Number.isFinite(pressureValue)) {
      return clampNumber(pressureValue, 0, 100);
    }
    const altitude = level.altitudeFt;
    if (altitude < 8000) {
      return cloudValueForBand(sample, "cloudLow");
    }
    if (altitude < 22000) {
      return cloudValueForBand(sample, "cloudMid");
    }
    return cloudValueForBand(sample, "cloudHigh");
  }

  function smoothCloudCoverage(samples, sampleIndex, level) {
    let weighted = 0;
    let totalWeight = 0;
    for (let offset = -2; offset <= 2; offset += 1) {
      const sample = samples[sampleIndex + offset];
      if (!sample) {
        continue;
      }
      const coverage = cloudCoverageForPressureLevel(sample, level);
      const weight = 1 / (1 + Math.abs(offset));
      weighted += coverage * weight;
      totalWeight += weight;
    }
    return totalWeight ? weighted / totalWeight : 0;
  }

  function renderCloudBands(samples, xForDistance, yForAltitude, colors) {
    const onlinePressureClouds = samples.some(hasPressureCloudData);
    const cloudLevels = onlinePressureClouds
      ? CALC_WEATHER_LEVELS
      : [
        { pressure: 850, altitudeFt: 6200 },
        { pressure: 700, altitudeFt: 12500 },
        { pressure: 500, altitudeFt: 20500 },
        { pressure: 300, altitudeFt: 33000 },
      ];
    const pieces = [];
    const tiers = [
      { threshold: 40, fill: colors.cloud, opacity: 0.40, lift: -80, halfBase: 230, halfScale: 7.0, maxHalf: 760 },
      { threshold: 66, fill: colors.cloudCore, opacity: 0.38, lift: 8, halfBase: 185, halfScale: 5.0, maxHalf: 560 },
      { threshold: 84, fill: colors.cloudDense, opacity: 0.34, lift: 78, halfBase: 145, halfScale: 3.5, maxHalf: 420 },
    ];
    const cloudEnvelopePath = (segment, level, tier) => {
      const upperPoints = [];
      const lowerPoints = [];
      segment.forEach((item) => {
        const coverageExcess = Math.max(0, item.coverage - tier.threshold);
        const terrainFloor = Number(item.sample.terrainFt || 0) + 420;
        const wave = Math.sin((item.sample.distanceNm * 0.018 + level.pressure * 0.013 + tier.threshold * 0.031) * Math.PI)
          * clampNumber(36 + item.coverage * 1.15, 52, 170);
        const centerFt = level.altitudeFt + wave + tier.lift;
        const halfHeightFt = clampNumber(tier.halfBase + coverageExcess * tier.halfScale, 150, tier.maxHalf);
        const lowerFt = Math.max(terrainFloor, centerFt - halfHeightFt);
        const upperFt = Math.max(lowerFt + 420, centerFt + halfHeightFt);
        upperPoints.push({
          x: xForDistance(item.sample.distanceNm),
          y: yForAltitude(upperFt),
        });
        lowerPoints.push({
          x: xForDistance(item.sample.distanceNm),
          y: yForAltitude(lowerFt),
        });
      });
      if (upperPoints.length < 2 || lowerPoints.length < 2) {
        return "";
      }
      const top = smoothSvgPathForPoints(upperPoints);
      const bottom = smoothSvgPathForPoints(lowerPoints.reverse(), { omitMove: true });
      return top && bottom ? `${top} ${bottom} Z` : "";
    };
    const flushSegment = (segment, level, tier) => {
      if (segment.length < 2) {
        return;
      }
      const path = cloudEnvelopePath(segment, level, tier);
      if (!path) {
        return;
      }
      pieces.push(`<path d="${path}" fill="${tier.fill}" stroke="${colors.cloudStroke}" stroke-width="0.22" opacity="${tier.opacity.toFixed(2)}" />`);
    };
    cloudLevels.forEach((level) => {
      tiers.forEach((tier) => {
        let segment = [];
        samples.forEach((sample, index) => {
          const coverage = smoothCloudCoverage(samples, index, level);
          const usable = coverage >= tier.threshold && level.altitudeFt >= Number(sample.terrainFt || 0) + 350;
          if (usable) {
            segment.push({ sample, coverage });
            return;
          }
          flushSegment(segment, level, tier);
          segment = [];
        });
        flushSegment(segment, level, tier);
      });
    });
    return pieces.length
      ? `<g filter="url(#calculateCloudSoftBlur)" opacity="0.88">${pieces.join("")}</g>`
      : "";
  }

  function renderPrecipitationBars(samples, xForDistance, colors, precipPlot) {
    const pieces = [];
    const averageStep = samples.length > 1
      ? Math.abs(xForDistance(samples[1].distanceNm) - xForDistance(samples[0].distanceNm))
      : 7;
    const bucketWidth = clampNumber(averageStep * 1.9, 18, 42);
    const buckets = new Map();
    samples.forEach((sample, index) => {
      const rain = Math.max(0, Number(sample.rainMmH) || 0);
      const convective = Math.max(0, Number(sample.convectiveRainMmH) || 0);
      if (rain <= 0.04 && convective <= 0.04) {
        return;
      }
      const x = xForDistance(sample.distanceNm);
      const total = rain + convective;
      const bucketKey = Math.round((x - precipPlot.left) / bucketWidth);
      const existing = buckets.get(bucketKey);
      if (!existing || total > existing.total || (Math.abs(total - existing.total) < 0.05 && index > existing.index)) {
        buckets.set(bucketKey, { x, rain, convective, total, index });
      }
    });
    let lastLabelX = -Infinity;
    Array.from(buckets.values())
      .sort((left, right) => left.x - right.x)
      .forEach((item) => {
      const total = item.total;
      const barTop = precipPlot.top + 10;
      const availableHeight = Math.max(8, precipPlot.bottom - barTop);
      const barHeight = clampNumber(total * 2.4 + Math.sqrt(total) * 2.4, 3.5, availableHeight);
      const barWidth = clampNumber(bucketWidth * 0.62, 7, 18);
      const bottomY = precipPlot.bottom;
      const y = Math.max(barTop, bottomY - barHeight);
      const rainHeight = barHeight * (item.rain / Math.max(0.001, total));
      const convectiveHeight = barHeight - rainHeight;
      const x = clampNumber(item.x, precipPlot.left + barWidth / 2, precipPlot.right - barWidth / 2);
      if (rainHeight > 1) {
        pieces.push(`<rect x="${(x - barWidth / 2).toFixed(1)}" y="${(y + convectiveHeight).toFixed(1)}" width="${barWidth.toFixed(1)}" height="${rainHeight.toFixed(1)}" rx="0.9" fill="${colors.rain}" opacity="0.92" />`);
      }
      if (convectiveHeight > 1) {
        pieces.push(`<rect x="${(x - barWidth / 2).toFixed(1)}" y="${y.toFixed(1)}" width="${barWidth.toFixed(1)}" height="${convectiveHeight.toFixed(1)}" rx="0.9" fill="${colors.convectiveRain}" opacity="0.94" />`);
      }
      if (total >= 0.12 && x - lastLabelX >= 34) {
        lastLabelX = x;
        const label = total >= 10 ? Math.round(total).toString() : total.toFixed(1);
        pieces.push(svgText(x, precipPlot.top + 7, label, { fill: colors.rainLabel, size: 6.8, weight: 840 }));
      }
    });
    return pieces.length ? `<g class="calculate-rain-bars" filter="url(#calculateRainSoftGlow)">${pieces.join("")}</g>` : "";
  }

  function renderCalculateWeatherProfile(profile) {
    const svg = elements.calcWeatherProfileSvg;
    if (!svg) {
      return;
    }
    if (!profile?.samples?.length) {
      state.calculateWeatherLayout = null;
      svg.innerHTML = `<text x="50%" y="50%" fill="rgba(190,205,220,.78)" font-size="${Math.max(1, 13 - deviceFontSizeReductionPx())}" font-weight="780" text-anchor="middle">${escapeHtml(t("calculate.statusNoRoute"))}</text>`;
      return;
    }
    const colors = calculateChartColors();
    const chartElement = svg.parentElement || svg;
    const rect = chartElement.getBoundingClientRect();
    // 外部 viewBox 必须和 SVG 的布局视口保持同一比例。iPad 横屏右侧栏
    // 只有约 262px 可见宽度；旧的 340px 宽度下限配合
    // preserveAspectRatio="none" 会把坐标轴与文字横向挤窄。
    // clientWidth/clientHeight 是 CSS zoom 前的布局尺寸，外层缩放会继续
    // 对两轴使用相同倍率；最小绘图区只应由下方 plot margin 控制。
    const width = Math.max(1, Math.round(svg.clientWidth || chartElement.clientWidth || rect.width || 760));
    const height = Math.max(1, Math.round(svg.clientHeight || chartElement.clientHeight || rect.height || 390));
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`);

    const lowerReserved = Math.round(clampNumber(height * 0.38, 140, 176));
    const mainBottom = Math.round(height - lowerReserved);
    const terrainPlot = {
      left: Math.round(clampNumber(width * 0.085, 44, 62)),
      right: width - Math.round(clampNumber(width * 0.055, 28, 48)),
      top: mainBottom + 18,
      bottom: height - 92,
    };
    const precipPlot = {
      left: terrainPlot.left,
      right: terrainPlot.right,
      top: height - 84,
      bottom: height - 55,
    };
    const plot = {
      left: terrainPlot.left,
      right: width - terrainPlot.right,
      top: 50,
      bottom: height - mainBottom,
    };
    const plotWidth = width - plot.left - plot.right;
    const plotHeight = mainBottom - plot.top;
    const { viewport, samples } = visibleCalculateSamples(profile);
    const altitudeMaxFt = calculateProfileAltitudeMax(profile);
    const xForDistance = (distanceNm) => plot.left + ((distanceNm - viewport.start) / Math.max(1, viewport.end - viewport.start)) * plotWidth;
    const yForAltitude = (altitudeFt) => plot.top + (1 - clampNumber(altitudeFt, 0, altitudeMaxFt) / altitudeMaxFt) * plotHeight;
    state.calculateWeatherLayout = { width, height, plot, viewport, xForDistance, yForAltitude, altitudeMaxFt };
    const tickLabelY = height - 43;
    const distanceLabelY = height - 26;
    const footerY = height - 8;

    const terrainValues = samples.map((sample) => Math.max(0, Number(sample.terrainFt) || 0));
    const terrainMaxFt = clampNumber(Math.ceil((Math.max(1500, ...terrainValues) + 800) / 1000) * 1000, 3000, 18000);
    const yForTerrain = (altitudeFt) => terrainPlot.bottom - (clampNumber(altitudeFt, 0, terrainMaxFt) / terrainMaxFt) * Math.max(1, terrainPlot.bottom - terrainPlot.top);
    const terrainMidFt = Math.round((terrainMaxFt / 2) / 500) * 500;
    const formatTerrainTick = (altitudeFt) => {
      if (altitudeFt >= 1000) {
        const thousands = altitudeFt / 1000;
        return `${Number.isInteger(thousands) ? thousands.toFixed(0) : thousands.toFixed(1)}k`;
      }
      return String(Math.round(altitudeFt));
    };

    const grid = [];
    const legend = [];
    const cycleLabel = calculateWeatherCycleLabel(profile);
    legend.push(svgText(width / 2, 14, cycleLabel, { fill: colors.muted, size: width < 420 ? 8.6 : 9.5, weight: 820 }));
    legend.push(svgText(plot.left, 14, "FL", { fill: colors.label, size: 10, anchor: "start", weight: 860 }));
    legend.push(svgText(width - plot.right, 14, "hPa", { fill: colors.label, size: 10, anchor: "end", weight: 860 }));
    const legendY = 27;
    const legendSize = width < 430 ? 7.1 : 8.4;
    const legendItems = width < 430
      ? [
        { key: "route", label: "航路", width: 39 },
        { key: "constraint", label: "约束", width: 43 },
        { key: "cloud", label: "云层", width: 42 },
        { key: "wind", label: "相对风", width: 48 },
        { key: "rain", label: "降水", width: 43 },
      ]
      : [
        { key: "route", label: "航路高度", width: 78 },
        { key: "constraint", label: "约束高度", width: 84 },
        { key: "cloud", label: "云层", width: 56 },
        { key: "wind", label: "相对来风 kt", width: 92 },
        { key: "rain", label: "降水", width: 58 },
      ];
    const legendGap = width < 430 ? 4 : 10;
    const legendTotalWidth = legendItems.reduce((sum, item) => sum + item.width, 0) + legendGap * (legendItems.length - 1);
    let legendCursor = clampNumber((width - legendTotalWidth) / 2, plot.left + 16, Math.max(plot.left + 16, width - plot.right - legendTotalWidth));
    legendItems.forEach((item) => {
      const x = legendCursor;
      if (item.key === "route") {
        legend.push(`<line x1="${x.toFixed(1)}" y1="${legendY.toFixed(1)}" x2="${(x + 16).toFixed(1)}" y2="${legendY.toFixed(1)}" stroke="${colors.route}" stroke-width="1.4" />`);
        legend.push(svgText(x + 18, legendY + 3, item.label, { fill: colors.muted, size: legendSize, anchor: "start", weight: 760 }));
      } else if (item.key === "constraint") {
        legend.push(`<line x1="${x.toFixed(1)}" y1="${legendY.toFixed(1)}" x2="${(x + 16).toFixed(1)}" y2="${legendY.toFixed(1)}" stroke="${colors.constraint}" stroke-width="1.15" stroke-dasharray="4 3" />`);
        legend.push(svgText(x + 18, legendY + 3, item.label, { fill: colors.muted, size: legendSize, anchor: "start", weight: 760 }));
      } else if (item.key === "cloud") {
        legend.push(`<rect x="${x.toFixed(1)}" y="${(legendY - 5.5).toFixed(1)}" width="15" height="7" rx="2" fill="${colors.cloudDense}" stroke="${colors.cloudStroke}" stroke-width="0.35" />`);
        legend.push(svgText(x + 17, legendY + 3, item.label, { fill: colors.muted, size: legendSize, anchor: "start", weight: 760 }));
      } else if (item.key === "wind") {
        legend.push(`<g transform="translate(${(x + 4).toFixed(1)} ${legendY.toFixed(1)}) scale(${width < 430 ? "0.82" : "0.92"})">${drawRelativeWindBarbSvg(0, 0, { windSpeedKt: 42, relativeWindDeg: 115, tailwindKt: -18 }, colors)}</g>`);
        legend.push(svgText(x + 19, legendY + 3, item.label, { fill: colors.muted, size: legendSize, anchor: "start", weight: 760 }));
      } else if (item.key === "rain") {
        legend.push(`<rect x="${x.toFixed(1)}" y="${(legendY - 5.5).toFixed(1)}" width="8" height="7" rx="1" fill="${colors.rain}" /><rect x="${(x + 9.5).toFixed(1)}" y="${(legendY - 5.5).toFixed(1)}" width="8" height="7" rx="1" fill="${colors.convectiveRain}" />`);
        legend.push(svgText(x + 20, legendY + 3, item.label, { fill: colors.muted, size: legendSize, anchor: "start", weight: 760 }));
      }
      legendCursor += item.width + legendGap;
    });

    const altitudeLabelStep = altitudeMaxFt > 50000 ? 10000 : 5000;
    for (let altitude = 0; altitude <= altitudeMaxFt; altitude += 5000) {
      const y = yForAltitude(altitude);
      const major = altitude % altitudeLabelStep === 0 || altitude === altitudeMaxFt || altitude === 0;
      grid.push(`<line x1="${plot.left}" y1="${y.toFixed(1)}" x2="${(width - plot.right).toFixed(1)}" y2="${y.toFixed(1)}" stroke="${major ? colors.gridStrong : colors.grid}" stroke-width="${major ? "0.78" : "0.52"}" stroke-dasharray="${major ? "3 2.5" : "2 3"}" />`);
      if (major) {
        const label = altitude === 0 ? "SFC" : `FL${String(Math.round(altitude / 100)).padStart(3, "0")}`;
        const numericLabel = altitude === 0 ? "0" : String(Math.round(altitude / 100));
        grid.push(svgText(plot.left - 13, y + 3.2, numericLabel, { fill: colors.label, size: width < 420 ? 6.8 : 7.8, anchor: "end", weight: 720 }));
        grid.push(svgText(plot.left + 2, y + 3.0, label, { fill: colors.muted, size: width < 420 ? 5.9 : 6.8, anchor: "start", weight: 620 }));
      }
    }
    const pressureAxisTicks = [150, 175, 200, 225, 250, 275, 300, 350, 400, 450, 500, 600, 700, 850, 1000];
    pressureAxisTicks.forEach((pressure) => {
      const altitudeFt = altitudeFeetForPressureHpa(pressure);
      if (altitudeFt < -500 || altitudeFt > altitudeMaxFt + 800) {
        return;
      }
      const y = yForAltitude(altitudeFt);
      grid.push(svgText(width - plot.right + 7, y + 2.8, String(pressure), { fill: colors.muted, size: width < 420 ? 6.3 : 7.1, anchor: "start", weight: 650 }));
    });

    const xTickCount = Math.round(clampNumber(plotWidth / 116 + 1, 3, 8));
    for (let index = 0; index < xTickCount; index += 1) {
      const ratio = index / Math.max(1, xTickCount - 1);
      const distance = viewport.start + ratio * (viewport.end - viewport.start);
      const x = xForDistance(distance);
      grid.push(`<line x1="${x.toFixed(1)}" y1="${plot.top}" x2="${x.toFixed(1)}" y2="${precipPlot.bottom.toFixed(1)}" stroke="${colors.grid}" stroke-width="0.58" stroke-dasharray="2 3.5" />`);
      grid.push(svgText(x, tickLabelY, String(Math.round(distance)), { fill: colors.label, size: width < 420 ? 7.4 : 8.4, weight: 720 }));
    }
    grid.push(svgText(width / 2, distanceLabelY, "飞行距离 (NM)", { fill: colors.muted, size: width < 420 ? 7.4 : 8.4, weight: 780 }));

    const terrainPath = samples.map((sample, index) => {
      const x = xForDistance(sample.distanceNm);
      const y = yForTerrain(Math.max(0, sample.terrainFt));
      return `${index ? "L" : "M"}${x.toFixed(1)} ${y.toFixed(1)}`;
    }).join(" ");
    const terrainArea = terrainPath
      ? `${terrainPath} L${xForDistance(samples.at(-1).distanceNm).toFixed(1)} ${terrainPlot.bottom.toFixed(1)} L${xForDistance(samples[0].distanceNm).toFixed(1)} ${terrainPlot.bottom.toFixed(1)} Z`
      : "";
    const plannedPath = svgPathForProfile(samples.map((sample) => ({
      x: xForDistance(sample.distanceNm),
      y: yForAltitude(sample.altitudeFt),
    })), "y");
    const waitingForOnlineWeather = state.calculateOnlineWeatherPending && !profile.weatherOnline;
    const cruiseSamples = profile.samples.filter((sample) => sample.phase === "cruise");
    const avgCruiseFl = Math.round((cruiseSamples.reduce((sum, sample) => sum + sample.altitudeFt, 0) / Math.max(1, cruiseSamples.length)) / 100);

    const cloudLayer = state.calculateLayerVisibility.cloud
      ? renderCloudBands(samples, xForDistance, yForAltitude, colors)
      : "";
    const rainLayer = state.calculateLayerVisibility.rain
      ? renderPrecipitationBars(samples, xForDistance, colors, precipPlot)
      : "";
    const windLayer = state.calculateLayerVisibility.wind
      ? (() => {
        const windLevels = CALC_WEATHER_LEVELS.filter((level) => level.altitudeFt >= 3000 && level.altitudeFt <= altitudeMaxFt);
        const xSlots = Math.round(clampNumber(plotWidth / (width < 430 ? 58 : 78), width < 430 ? 5 : 4, width < 430 ? 7 : 11));
        const pieces = [];
        for (let xi = 0; xi < xSlots; xi += 1) {
          const slotRatio = (xi + 0.5) / Math.max(1, xSlots);
          const distance = viewport.start + slotRatio * (viewport.end - viewport.start);
          const nearest = nearestProfileSample(samples, distance);
          windLevels.forEach((level) => {
            const met = profile.weatherOnline
              ? onlineWindAt(nearest, level.altitudeFt)
              : calculateAtmosphereAt(nearest, level.altitudeFt);
            if (!met) {
              return;
            }
            const x = xForDistance(distance);
            const y = yForAltitude(level.altitudeFt);
            pieces.push(`<g opacity="0.90">${drawRelativeWindBarbSvg(x, y, met, colors)}</g>`);
            pieces.push(svgText(x, y - 4.1, formatRelativeWindLabel(met, width < 430), { fill: colors.wind, size: width < 420 ? 5.0 : 5.8, weight: 740 }));
          });
        }
        return pieces.join("");
      })()
      : "";

    const showLegLabels = (state.calculateProfileZoom || 1) >= 2.05;
    const legMarkers = (profile.route.legAnnotations || [])
      .map((leg) => {
        if (leg.endNm < viewport.start || leg.startNm > viewport.end) {
          return "";
        }
        const startX = xForDistance(clampNumber(leg.startNm, viewport.start, viewport.end));
        const endX = xForDistance(clampNumber(leg.endNm, viewport.start, viewport.end));
        const midX = xForDistance(clampNumber(leg.midNm, viewport.start, viewport.end));
        const visibleWidth = Math.max(0, endX - startX);
        const labelWidth = clampNumber(String(leg.label || "").length * 6.5 + 12, 32, Math.max(34, visibleWidth - 8));
        const labelY = plot.top + 18;
        const label = showLegLabels && visibleWidth >= 74
          ? `
            <rect x="${(midX - labelWidth / 2).toFixed(1)}" y="${(labelY - 12).toFixed(1)}" width="${labelWidth.toFixed(1)}" height="16" rx="2" fill="rgba(131, 194, 213, 0.82)" stroke="rgba(34, 83, 104, 0.82)" stroke-width="1" />
            ${svgText(midX, labelY, leg.label, { fill: "rgba(20, 51, 66, 0.96)", size: 8.4, weight: 860 })}
          `
          : "";
        return `
          <line x1="${startX.toFixed(1)}" y1="${plot.top}" x2="${startX.toFixed(1)}" y2="${precipPlot.bottom.toFixed(1)}" stroke="rgba(38, 80, 99, ${showLegLabels ? "0.13" : "0.055"})" stroke-width="0.72" stroke-dasharray="3 7" />
          <line x1="${endX.toFixed(1)}" y1="${plot.top}" x2="${endX.toFixed(1)}" y2="${precipPlot.bottom.toFixed(1)}" stroke="rgba(38, 80, 99, ${showLegLabels ? "0.10" : "0.045"})" stroke-width="0.72" stroke-dasharray="3 7" />
          ${label}
        `;
      }).join("");
    const showAdjustableLabels = width >= 700 || (state.calculateProfileZoom || 1) >= 1.65;
    let lastAdjustableLabelX = -Infinity;
    const adjustableLabelGap = showAdjustableLabels
      ? (width < 430 ? 74 : 66)
      : (width < 430 ? 58 : 62);
    const visibleAdjustableEntries = (profile.route.adjustablePoints || []).map((point, index) => {
      const sample = nearestProfileSample(profile.samples, point.distanceNm);
      if (!sample) {
        return null;
      }
      const x = xForDistance(point.distanceNm);
      if (x < plot.left - 2 || x > width - plot.right + 2 || !point.ident) {
        return null;
      }
      return { point, sample, x, index };
    }).filter(Boolean);
    const defaultAdjustableLabelIndexes = new Set();
    if (!showAdjustableLabels && visibleAdjustableEntries.length) {
      const preferred = visibleAdjustableEntries.filter((entry) => (
        entry.sample.altitudeFt >= 5000
        || entry.index === 0
        || entry.index === profile.route.adjustablePoints.length - 1
      ));
      const sourceEntries = preferred.length >= 3 ? preferred : visibleAdjustableEntries;
      const targetCount = Math.min(width < 430 ? 6 : 10, sourceEntries.length);
      for (let cursor = 0; cursor < targetCount; cursor += 1) {
        const sourceIndex = targetCount === 1
          ? 0
          : Math.round((cursor / Math.max(1, targetCount - 1)) * (sourceEntries.length - 1));
        defaultAdjustableLabelIndexes.add(sourceEntries[sourceIndex].index);
      }
    }
    const adjustablePointMarkers = (profile.route.adjustablePoints || []).map((point, index) => {
      const sample = nearestProfileSample(profile.samples, point.distanceNm);
      if (!sample) {
        return "";
      }
      const x = xForDistance(point.distanceNm);
      if (x < plot.left - 2 || x > width - plot.right + 2) {
        return "";
      }
      const y = yForAltitude(sample.altitudeFt);
      const shouldLabelPoint = showAdjustableLabels || defaultAdjustableLabelIndexes.has(index);
      const canPlaceLabel = shouldLabelPoint && point.ident && x - lastAdjustableLabelX >= adjustableLabelGap;
      if (canPlaceLabel) {
        lastAdjustableLabelX = x;
      }
      const labelAbove = y > plot.top + 40;
      const labelHeight = width < 430 ? 16 : 18;
      const labelTop = labelAbove
        ? Math.max(plot.top + 2, y - labelHeight - 5 - (index % 2) * 7)
        : Math.min(mainBottom - labelHeight - 2, y + 5 + (index % 2) * 7);
      const labelWidth = clampNumber(String(point.ident || "").length * 6.0 + 10, 30, width < 430 ? 50 : 56);
      const altitudeLabel = `FL${String(Math.round(sample.altitudeFt / 100)).padStart(3, "0")}`;
      return `
        <rect x="${(x - 2.1).toFixed(1)}" y="${(y - 2.1).toFixed(1)}" width="4.2" height="4.2" rx="0.8" fill="${colors.point}" stroke="rgba(48, 55, 20, 0.78)" stroke-width="0.72" />
        ${canPlaceLabel ? `
          <rect x="${(x - labelWidth / 2).toFixed(1)}" y="${labelTop.toFixed(1)}" width="${labelWidth.toFixed(1)}" height="${labelHeight}" rx="1.8" fill="rgba(195, 225, 237, 0.94)" stroke="rgba(42, 100, 123, 0.76)" stroke-width="0.7" />
          ${svgText(x, labelTop + (width < 430 ? 6.3 : 7.0), point.ident, { fill: "rgba(18, 51, 66, 0.96)", size: width < 430 ? 6.8 : 7.5, weight: 860 })}
          ${svgText(x, labelTop + (width < 430 ? 12.3 : 14.0), altitudeLabel, { fill: colors.muted, size: width < 430 ? 4.9 : 5.5, weight: 740 })}
        ` : ""}
      `;
    }).join("");
    const markerLine = (distanceNm, label, color) => {
      const markerX = xForDistance(distanceNm);
      if (markerX < plot.left || markerX > width - plot.right) {
        return "";
      }
      const anchor = markerX > width - plot.right - 44 ? "end" : "start";
      const labelX = anchor === "end" ? markerX - 4 : markerX + 4;
      return `
        <line x1="${markerX.toFixed(1)}" y1="${plot.top}" x2="${markerX.toFixed(1)}" y2="${mainBottom.toFixed(1)}" stroke="${color}" stroke-width="0.95" stroke-opacity="0.78" stroke-dasharray="5 6" />
        ${svgText(labelX, plot.top + 12, label, { fill: color, size: width < 420 ? 7.4 : 8.0, anchor, weight: 840 })}
      `;
    };
    const tocMarker = markerLine(profile.tocNm || 0, "TOC", "rgba(40, 142, 202, 0.86)");
    const todMarker = markerLine(profile.todNm, t("calculate.tod"), "rgba(255, 170, 64, 0.88)");
    const showConstraintLabels = (state.calculateProfileZoom || 1) >= 2.4;
    let lastConstraintLabelX = -Infinity;
    const constraintMarkers = profile.constraints.map((constraint) => {
      const x = xForDistance(constraint.distanceNm);
      if (x < plot.left || x > width - plot.right) {
        return "";
      }
      const sample = nearestProfileSample(profile.samples, constraint.distanceNm);
      const referenceFt = Number.isFinite(constraint.minFt)
        ? constraint.minFt
        : (Number.isFinite(constraint.maxFt) ? constraint.maxFt : sample?.altitudeFt || 0);
      const yMin = yForAltitude(clampNumber(Number.isFinite(constraint.minFt) ? constraint.minFt : referenceFt, 0, altitudeMaxFt));
      const yMax = yForAltitude(clampNumber(Number.isFinite(constraint.maxFt) ? constraint.maxFt : referenceFt, 0, altitudeMaxFt));
      const yTop = Math.min(yMin, yMax);
      const yBottom = Math.max(yMin, yMax);
      const canLabel = showConstraintLabels && constraint.ident && x - lastConstraintLabelX >= 62;
      if (canLabel) {
        lastConstraintLabelX = x;
      }
      const labelAnchor = x > width - plot.right - 82 ? "end" : "start";
      const labelX = labelAnchor === "end" ? x - 7 : x + 7;
      let glyph = "";
      if (constraint.kind === "between" && yBottom - yTop >= 2) {
        glyph = `
          <line x1="${x.toFixed(1)}" y1="${yTop.toFixed(1)}" x2="${x.toFixed(1)}" y2="${yBottom.toFixed(1)}" stroke="${colors.constraint}" stroke-width="0.82" />
          <line x1="${(x - 3.2).toFixed(1)}" y1="${yTop.toFixed(1)}" x2="${(x + 3.2).toFixed(1)}" y2="${yTop.toFixed(1)}" stroke="${colors.constraint}" stroke-width="0.82" />
          <line x1="${(x - 3.2).toFixed(1)}" y1="${yBottom.toFixed(1)}" x2="${(x + 3.2).toFixed(1)}" y2="${yBottom.toFixed(1)}" stroke="${colors.constraint}" stroke-width="0.82" />
        `;
      } else if (constraint.kind === "above") {
        glyph = `
          <line x1="${(x - 3.2).toFixed(1)}" y1="${yMin.toFixed(1)}" x2="${(x + 3.2).toFixed(1)}" y2="${yMin.toFixed(1)}" stroke="${colors.constraint}" stroke-width="0.82" />
          <path d="M${x.toFixed(1)} ${yMin.toFixed(1)} L${x.toFixed(1)} ${(yMin - 5.5).toFixed(1)} M${(x - 2).toFixed(1)} ${(yMin - 3.4).toFixed(1)} L${x.toFixed(1)} ${(yMin - 5.5).toFixed(1)} L${(x + 2).toFixed(1)} ${(yMin - 3.4).toFixed(1)}" fill="none" stroke="${colors.constraint}" stroke-width="0.82" stroke-linecap="round" stroke-linejoin="round" />
        `;
      } else if (constraint.kind === "below") {
        glyph = `
          <line x1="${(x - 3.2).toFixed(1)}" y1="${yMax.toFixed(1)}" x2="${(x + 3.2).toFixed(1)}" y2="${yMax.toFixed(1)}" stroke="${colors.constraint}" stroke-width="0.82" />
          <path d="M${x.toFixed(1)} ${yMax.toFixed(1)} L${x.toFixed(1)} ${(yMax + 5.5).toFixed(1)} M${(x - 2).toFixed(1)} ${(yMax + 3.4).toFixed(1)} L${x.toFixed(1)} ${(yMax + 5.5).toFixed(1)} L${(x + 2).toFixed(1)} ${(yMax + 3.4).toFixed(1)}" fill="none" stroke="${colors.constraint}" stroke-width="0.82" stroke-linecap="round" stroke-linejoin="round" />
        `;
      } else {
        const exactY = (yMin + yMax) / 2;
        glyph = `
          <line x1="${(x - 3.8).toFixed(1)}" y1="${exactY.toFixed(1)}" x2="${(x + 3.8).toFixed(1)}" y2="${exactY.toFixed(1)}" stroke="${colors.constraint}" stroke-width="0.82" />
          <path d="M${x.toFixed(1)} ${(exactY - 1.8).toFixed(1)} L${(x + 1.8).toFixed(1)} ${exactY.toFixed(1)} L${x.toFixed(1)} ${(exactY + 1.8).toFixed(1)} L${(x - 1.8).toFixed(1)} ${exactY.toFixed(1)} Z" fill="${colors.constraint}" />
        `;
      }
      return `
        <g opacity="0.76">${glyph}</g>
        ${canLabel ? svgText(labelX, Math.max(plot.top + 9, yTop - 4), `${constraint.ident} ${constraint.label}`, { fill: colors.constraint, size: 6.7, anchor: labelAnchor, weight: 780 }) : ""}
      `;
    }).join("");

    svg.innerHTML = `
      <defs>
        <filter id="calculateCloudSoftBlur" x="-8%" y="-12%" width="116%" height="124%">
          <feGaussianBlur stdDeviation="3.2" />
        </filter>
        <filter id="calculateRainSoftGlow" x="-12%" y="-18%" width="124%" height="136%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="0.22" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        <linearGradient id="calculateTerrainGradient" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="${colors.terrainHigh}" />
          <stop offset="48%" stop-color="${colors.terrainMid}" />
          <stop offset="100%" stop-color="${colors.terrainLow}" />
        </linearGradient>
      </defs>
      ${legend.join("")}
      ${grid.join("")}
      ${cloudLayer}
      ${windLayer}
      ${waitingForOnlineWeather ? svgText(plot.left + 12, plot.top + 18, t("calculate.weatherLoading"), { fill: colors.muted, size: width < 420 ? 7.2 : 8.2, anchor: "start", weight: 780 }) : ""}
      ${plannedPath ? `<path d="${plannedPath}" fill="none" stroke="${colors.route}" stroke-width="1.24" stroke-linecap="round" stroke-linejoin="round" />` : ""}
      ${tocMarker}
      ${todMarker}
      ${constraintMarkers}
      ${legMarkers}
      ${adjustablePointMarkers}
      <line x1="${plot.left}" y1="${plot.top}" x2="${plot.left}" y2="${mainBottom}" stroke="${colors.axis}" stroke-width="1.05" />
      <line x1="${plot.left}" y1="${mainBottom}" x2="${width - plot.right}" y2="${mainBottom}" stroke="${colors.axis}" stroke-width="0.95" />
      <line x1="${width - plot.right}" y1="${plot.top}" x2="${width - plot.right}" y2="${mainBottom}" stroke="${colors.axis}" stroke-width="0.85" />
      <line x1="${terrainPlot.left}" y1="${terrainPlot.top}" x2="${terrainPlot.left}" y2="${terrainPlot.bottom}" stroke="${colors.axis}" stroke-width="0.78" />
      <line x1="${terrainPlot.left}" y1="${terrainPlot.bottom}" x2="${terrainPlot.right}" y2="${terrainPlot.bottom}" stroke="${colors.axis}" stroke-width="0.85" />
      ${terrainArea ? `<path d="${terrainArea}" fill="url(#calculateTerrainGradient)" opacity="0.92" />` : ""}
      ${terrainPath ? `<path d="${terrainPath}" fill="none" stroke="${colors.terrainStroke}" stroke-width="1.05" stroke-linejoin="round" />` : ""}
      ${svgText(terrainPlot.left - 7, terrainPlot.top - 5, "地形高度 (ft)", { fill: colors.muted, size: width < 420 ? 5.9 : 6.8, anchor: "end", weight: 760 })}
      <line x1="${terrainPlot.left - 3}" y1="${terrainPlot.top}" x2="${terrainPlot.left}" y2="${terrainPlot.top}" stroke="${colors.axis}" stroke-width="0.72" />
      <line x1="${terrainPlot.left - 3}" y1="${yForTerrain(terrainMidFt).toFixed(1)}" x2="${terrainPlot.left}" y2="${yForTerrain(terrainMidFt).toFixed(1)}" stroke="${colors.axis}" stroke-width="0.72" />
      <line x1="${terrainPlot.left - 3}" y1="${terrainPlot.bottom}" x2="${terrainPlot.left}" y2="${terrainPlot.bottom}" stroke="${colors.axis}" stroke-width="0.72" />
      ${svgText(terrainPlot.left - 5, terrainPlot.top + 2.5, formatTerrainTick(terrainMaxFt), { fill: colors.muted, size: width < 420 ? 6.0 : 6.8, anchor: "end", weight: 700 })}
      ${svgText(terrainPlot.left - 5, yForTerrain(terrainMidFt) + 2.5, formatTerrainTick(terrainMidFt), { fill: colors.muted, size: width < 420 ? 6.0 : 6.8, anchor: "end", weight: 700 })}
      ${svgText(terrainPlot.left - 5, terrainPlot.bottom + 2.5, "0", { fill: colors.muted, size: width < 420 ? 6.0 : 6.8, anchor: "end", weight: 700 })}
      <line x1="${precipPlot.left}" y1="${precipPlot.bottom}" x2="${precipPlot.right}" y2="${precipPlot.bottom}" stroke="${colors.axis}" stroke-width="0.75" />
      ${rainLayer}
      ${svgText(plot.left - 8, precipPlot.bottom - 1, "降水 (mm)", { fill: colors.muted, size: width < 420 ? 6.4 : 7.4, anchor: "end", weight: 760 })}
      ${svgText(plot.left, footerY, `总里程：${Math.round(profile.totalDistanceNm).toLocaleString("en-US")} NM`, { fill: colors.label, size: width < 420 ? 7.4 : 8.4, anchor: "start", weight: 780 })}
      ${svgText(width / 2, footerY, `总飞行时间：${formatReadableDuration(profile.totalTimeMinutes)}`, { fill: colors.label, size: width < 420 ? 7.4 : 8.4, weight: 780 })}
      ${svgText(width - plot.right, footerY, `平均巡航：FL${avgCruiseFl}`, { fill: colors.label, size: width < 420 ? 7.4 : 8.4, anchor: "end", weight: 780 })}
    `;
  }

  function renderCalculateSpeedProfile(profile) {
    const svg = elements.calcSpeedProfileSvg;
    if (!svg) {
      return;
    }
    if (!profile?.samples?.length) {
      state.calculateSpeedLayout = null;
      svg.innerHTML = `<text x="50%" y="50%" fill="rgba(190,205,220,.78)" font-size="${Math.max(1, 13 - deviceFontSizeReductionPx())}" font-weight="780" text-anchor="middle">${escapeHtml(t("calculate.statusNoRoute"))}</text>`;
      return;
    }
    const colors = calculateChartColors();
    const chartElement = svg.parentElement || svg;
    const rect = chartElement.getBoundingClientRect();
    const width = Math.max(1, Math.round(svg.clientWidth || chartElement.clientWidth || rect.width || 760));
    const height = Math.max(1, Math.round(svg.clientHeight || chartElement.clientHeight || rect.height || 250));
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
    const plot = {
      left: Math.round(clampNumber(width * 0.085, 45, 64)),
      right: Math.round(clampNumber(width * 0.08, 42, 58)),
      top: 38,
      bottom: 58,
    };
    const plotWidth = width - plot.left - plot.right;
    const plotHeight = height - plot.top - plot.bottom;
    const { viewport, samples } = visibleCalculateSamples(profile);
    const xForDistance = (distanceNm) => plot.left + ((distanceNm - viewport.start) / Math.max(1, viewport.end - viewport.start)) * plotWidth;
    const speedMax = Math.max(500, Math.ceil(Math.max(...samples.map((sample) => sample.groundSpeedKt)) / 50) * 50);
    const yForSpeed = (speed) => plot.top + (1 - speed / speedMax) * plotHeight;
    const maxAbsVerticalSpeed = Math.max(...samples.map((sample) => Math.abs(Number(sample.verticalSpeedFpm) || 0)));
    const vsMax = clampNumber(Math.ceil(Math.max(3000, maxAbsVerticalSpeed) / 500) * 500, 3000, 4000);
    const yForVS = (vs) => plot.top + (1 - ((clampNumber(vs, -vsMax, vsMax) + vsMax) / (vsMax * 2))) * plotHeight;
    state.calculateSpeedLayout = { width, height, plot, viewport, xForDistance };
    const grid = [];
    for (let speed = 0; speed <= speedMax; speed += 100) {
      const y = yForSpeed(speed);
      grid.push(`<line x1="${plot.left}" y1="${y.toFixed(1)}" x2="${(width - plot.right).toFixed(1)}" y2="${y.toFixed(1)}" stroke="${colors.grid}" stroke-width="0.72" />`);
      grid.push(svgText(plot.left - 8, y + 4, String(speed), { fill: colors.label, size: width < 420 ? 8.8 : 9.7, anchor: "end", weight: 720 }));
    }
    const vsTicks = vsMax <= 3000
      ? [-3000, -1000, 0, 1000, 3000]
      : [-4000, -2000, 0, 2000, 4000];
    vsTicks.forEach((vs) => {
      const y = yForVS(vs);
      grid.push(`<line x1="${plot.left}" y1="${y.toFixed(1)}" x2="${(width - plot.right).toFixed(1)}" y2="${y.toFixed(1)}" stroke="${vs === 0 ? "rgba(255, 145, 104, 0.32)" : colors.grid}" stroke-width="${vs === 0 ? "1.05" : "0.72"}" stroke-dasharray="${vs === 0 ? "5 4" : "none"}" />`);
      grid.push(svgText(width - plot.right + 8, y + 4, String(vs), { fill: vs === 0 ? colors.vs : colors.label, size: width < 420 ? 8.5 : 9.3, anchor: "start", weight: 720 }));
    });
    const xTickCount = Math.round(clampNumber(plotWidth / 140 + 1, 3, 7));
    for (let index = 0; index < xTickCount; index += 1) {
      const ratio = index / Math.max(1, xTickCount - 1);
      const distance = viewport.start + ratio * (viewport.end - viewport.start);
      const x = xForDistance(distance);
      grid.push(`<line x1="${x.toFixed(1)}" y1="${plot.top}" x2="${x.toFixed(1)}" y2="${(height - plot.bottom).toFixed(1)}" stroke="${colors.grid}" stroke-width="0.72" />`);
      grid.push(svgText(x, height - 39, `${Math.round(distance)}`, { fill: colors.label, size: width < 420 ? 7.6 : 8.8, weight: 720 }));
    }
    const speedPoints = samples.map((sample) => ({ x: xForDistance(sample.distanceNm), y: yForSpeed(sample.groundSpeedKt) }));
    const speedPath = svgPathForProfile(speedPoints, "y");
    const speedArea = speedPath
      ? `${speedPath} L${xForDistance(samples.at(-1).distanceNm).toFixed(1)} ${(height - plot.bottom).toFixed(1)} L${xForDistance(samples[0].distanceNm).toFixed(1)} ${(height - plot.bottom).toFixed(1)} Z`
      : "";
    const vsPath = svgPathForProfile(samples.map((sample) => ({ x: xForDistance(sample.distanceNm), y: yForVS(sample.verticalSpeedFpm) })), "y");
    const avgGroundSpeed = samples.reduce((sum, sample) => sum + sample.groundSpeedKt, 0) / Math.max(1, samples.length);
    const maxGroundSpeed = Math.max(...samples.map((sample) => sample.groundSpeedKt));
    const maxDescentRate = Math.min(...samples.map((sample) => sample.verticalSpeedFpm));
    const legendY = 17;
    const legendCenter = width / 2;
    svg.innerHTML = `
      <defs>
        <linearGradient id="calculateSpeedFillGradient" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="${colors.speed}" stop-opacity="0.24" />
          <stop offset="70%" stop-color="${colors.speed}" stop-opacity="0.12" />
          <stop offset="100%" stop-color="${colors.speed}" stop-opacity="0.035" />
        </linearGradient>
      </defs>
      <rect x="0" y="0" width="${width}" height="${height}" fill="transparent" />
      <line x1="${(legendCenter - 88).toFixed(1)}" y1="${legendY}" x2="${(legendCenter - 64).toFixed(1)}" y2="${legendY}" stroke="${colors.speed}" stroke-width="1.8" />
      ${svgText(legendCenter - 42, legendY + 3, "地速 (kt)", { fill: colors.muted, size: width < 420 ? 7.4 : 8.5, weight: 780 })}
      <line x1="${(legendCenter + 28).toFixed(1)}" y1="${legendY}" x2="${(legendCenter + 52).toFixed(1)}" y2="${legendY}" stroke="${colors.vs}" stroke-width="1.45" />
      ${svgText(legendCenter + 88, legendY + 3, "垂直速度 (fpm)", { fill: colors.muted, size: width < 420 ? 7.4 : 8.5, weight: 780 })}
      ${grid.join("")}
      ${speedArea ? `<path d="${speedArea}" fill="url(#calculateSpeedFillGradient)" />` : ""}
      ${speedPath ? `<path d="${speedPath}" fill="none" stroke="${colors.speed}" stroke-width="1.45" stroke-linejoin="round" stroke-linecap="round" />` : ""}
      ${vsPath ? `<path d="${vsPath}" fill="none" stroke="${colors.vs}" stroke-width="1.25" stroke-linejoin="round" stroke-linecap="round" />` : ""}
      <line x1="${plot.left}" y1="${plot.top}" x2="${plot.left}" y2="${height - plot.bottom}" stroke="${colors.axis}" stroke-width="1.05" />
      <line x1="${plot.left}" y1="${height - plot.bottom}" x2="${width - plot.right}" y2="${height - plot.bottom}" stroke="${colors.axis}" stroke-width="1.05" />
      ${svgText(plot.left, plot.top - 8, "地速 (kt)", { fill: colors.label, size: width < 420 ? 8.2 : 9.4, anchor: "start", weight: 820 })}
      ${svgText(width - plot.right, plot.top - 8, "垂直速度 (fpm)", { fill: colors.vs, size: width < 420 ? 8.2 : 9.4, anchor: "end", weight: 820 })}
      ${svgText(width / 2, height - 23, "飞行距离 (NM)", { fill: colors.label, size: width < 420 ? 8 : 9.5, weight: 820 })}
      ${svgText(plot.left, height - 6, `平均地速：${Math.round(avgGroundSpeed)} kt`, { fill: colors.label, size: width < 420 ? 7.4 : 8.4, anchor: "start", weight: 780 })}
      ${svgText(width / 2, height - 6, `最大地速：${Math.round(maxGroundSpeed)} kt`, { fill: colors.label, size: width < 420 ? 7.4 : 8.4, weight: 780 })}
      ${svgText(width - plot.right, height - 6, `最大下降率：${Math.round(maxDescentRate)} fpm`, { fill: colors.label, size: width < 420 ? 7.4 : 8.4, anchor: "end", weight: 780 })}
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
    const requiredOffFuel = tripFuel + contFuel + alternateFuel + finalReserveFuel;
    const requiredBlockFuel = requiredOffFuel + taxiFuel;
    const blockFuel = state.calculateFuelKg;
    const offFuel = Math.max(0, blockFuel - taxiFuel);
    const zfw = state.calculateZfwKg;
    const estimatedTow = zfw + offFuel;
    const estimatedLaw = zfw + Math.max(0, offFuel - tripFuel);
    const extraFuel = Math.max(0, blockFuel - requiredBlockFuel);
    const fuelShortfall = Math.max(0, requiredBlockFuel - blockFuel);
    const dest = routeAirportCode("arrival");
    const dep = routeAirportCode("departure");
    const tripTime = profile.totalTimeMinutes;
    const contTime = 15;
    const alternateTime = 17;
    const finalReserveTime = 30;
    const windCode = `${profile.avgWindComponentKt >= 0 ? "P" : "M"}${String(Math.round(Math.abs(profile.avgWindComponentKt))).padStart(3, "0")}`;
    const isaCode = `${profile.avgIsaDeviationC >= 0 ? "P" : "M"}${String(Math.round(Math.abs(profile.avgIsaDeviationC))).padStart(3, "0")}`;
    const line = (label, arpt, fuel, time) => `${label.padEnd(15, " ")}${String(arpt || "").padEnd(7, " ")}${formatBriefWeight(fuel)}  ${formatFuelTime(time)}`;
    const compactWeight = (kg) => {
      const value = displayWeightValue(kg);
      return Number.isFinite(value) ? String(Math.round(value)).padStart(6, " ") : "    --";
    };
    const compactLine = (label, arpt, fuel, time) => (
      `${label.padEnd(11, " ")}${String(arpt || "").padEnd(5, " ")}${compactWeight(fuel)} ${formatFuelTime(time)}`
    );
    const unitLabel = currentWeightUnit().toUpperCase();
    const leftLines = [
      "          PLANNED FUEL",
      "------------------------------",
      "FUEL           ARPT      FUEL  TIME",
      "------------------------------",
      line("TRIP", dest, tripFuel, tripTime),
      line("CONT 15 MIN", "", contFuel, contTime),
      line("ALTN", "ALTN", alternateFuel, alternateTime),
      line("FINRES", "", finalReserveFuel, finalReserveTime),
      "------------------------------",
      line("MINIMUM T/OFF", "", requiredOffFuel, tripTime + contTime + alternateTime + finalReserveTime),
      "------------------------------",
      line("EXTRA", "", extraFuel, 0),
      "------------------------------",
      line("T/OFF FUEL", "", offFuel, tripTime + contTime + alternateTime + finalReserveTime),
      line("TAXI", dep, taxiFuel, 20),
      "------------------------------",
      line("BLOCK FUEL", dep, blockFuel, ""),
      fuelShortfall > 0 ? `FUEL SHORT      ${formatBriefWeight(fuelShortfall)}  ${t("calculate.weightOverLimit")}` : null,
      "PIC EXTRA       .....",
      "TOTAL FUEL      .....",
      "REASON FOR PIC EXTRA ..........",
      "------------------------------",
    ].filter((lineText) => lineText !== null);
    const rightLines = [
      `UNITS      ${unitLabel}`,
      "",
      `MAXIMUM    TOW ${formatBriefWeight(aircraft.mtowKg)}  LAW ${formatBriefWeight(aircraft.mlwKg)}`,
      `           ZFW ${formatBriefWeight(aircraft.zfwKg)}  AVG W/C ${windCode}`,
      `ESTIMATED  TOW ${formatBriefWeight(estimatedTow)}  LAW ${formatBriefWeight(estimatedLaw)}`,
      `           ZFW ${formatBriefWeight(zfw)}  AVG ISA ${isaCode}`,
      "",
      "------------------------------",
      "FMC INFO:",
      `FINRES+ALTN       ${formatBriefWeight(finalReserveFuel + alternateFuel)}`,
      `TRIP+TAXI         ${formatBriefWeight(tripFuel + taxiFuel)}`,
      "",
      `MODEL: ${aircraft.code}`,
      `${formatMach(state.calculateCruiseMach || aircraft.econMach)} / ${formatFlightLevelFromFeet(state.calculateCruiseAltitudeFt)}`,
    ];
    const compactLeftLines = [
      "      PLANNED FUEL",
      "----------------------------",
      "FUEL        ARPT   FUEL TIME",
      "----------------------------",
      compactLine("TRIP", dest, tripFuel, tripTime),
      compactLine("CONT 15", "", contFuel, contTime),
      compactLine("ALTN", "ALTN", alternateFuel, alternateTime),
      compactLine("FINRES", "", finalReserveFuel, finalReserveTime),
      "----------------------------",
      compactLine("MIN T/OFF", "", requiredOffFuel, tripTime + contTime + alternateTime + finalReserveTime),
      "----------------------------",
      compactLine("EXTRA", "", extraFuel, 0),
      "----------------------------",
      compactLine("T/OFF FUEL", "", offFuel, tripTime + contTime + alternateTime + finalReserveTime),
      compactLine("TAXI", dep, taxiFuel, 20),
      "----------------------------",
      compactLine("BLOCK", dep, blockFuel, ""),
      fuelShortfall > 0 ? `SHORT        ${compactWeight(fuelShortfall)} ${t("calculate.weightOverLimit")}` : null,
      "PIC EXTRA    .....",
      "TOTAL FUEL   .....",
      "PIC REASON   ..........",
      "----------------------------",
    ].filter((lineText) => lineText !== null);
    const compactRightLines = [
      `UNITS ${unitLabel}`,
      "",
      `MAX TOW ${compactWeight(aircraft.mtowKg).trim()} LAW ${compactWeight(aircraft.mlwKg).trim()}`,
      `MAX ZFW ${compactWeight(aircraft.zfwKg).trim()} W/C ${windCode}`,
      `EST TOW ${compactWeight(estimatedTow).trim()} LAW ${compactWeight(estimatedLaw).trim()}`,
      `EST ZFW ${compactWeight(zfw).trim()} ISA ${isaCode}`,
      "",
      "--------------------------",
      "FMC INFO:",
      `FINRES+ALTN ${compactWeight(finalReserveFuel + alternateFuel).trim()}`,
      `TRIP+TAXI   ${compactWeight(tripFuel + taxiFuel).trim()}`,
      "",
      `MODEL ${aircraft.code}`,
      `${formatMach(state.calculateCruiseMach || aircraft.econMach)} ${formatFlightLevelFromFeet(state.calculateCruiseAltitudeFt)}`,
    ];
    const briefWidth = elements.calcFuelBrief.getBoundingClientRect?.().width || 0;
    const stackedBrief = briefWidth > 0 && briefWidth < 286;
    const compactBrief = !stackedBrief && briefWidth > 0 && briefWidth < 520;
    let brief = "";
    if (stackedBrief) {
      brief = `${leftLines.join("\n")}\n\n${rightLines.join("\n")}`;
    } else if (compactBrief) {
      const leftColumnWidth = Math.max(28, ...compactLeftLines.map((item) => item.length));
      const briefRows = [];
      const rowCount = Math.max(compactLeftLines.length, compactRightLines.length);
      for (let index = 0; index < rowCount; index += 1) {
        briefRows.push(`${(compactLeftLines[index] || "").padEnd(leftColumnWidth, " ")}  ${compactRightLines[index] || ""}`.trimEnd());
      }
      brief = briefRows.join("\n");
    } else {
      const leftColumnWidth = Math.max(34, ...leftLines.map((item) => item.length));
      const briefRows = [];
      const rowCount = Math.max(leftLines.length, rightLines.length);
      for (let index = 0; index < rowCount; index += 1) {
        briefRows.push(`${(leftLines[index] || "").padEnd(leftColumnWidth, " ")}   ${rightLines[index] || ""}`.trimEnd());
      }
      brief = briefRows.join("\n");
    }
    elements.calcFuelBrief.textContent = brief;
    elements.calcFuelBrief.classList.toggle("is-stacked", stackedBrief);
    elements.calcFuelBrief.classList.toggle("is-compact", compactBrief);
    elements.calcFuelSummary.textContent = t("calculate.fuelSummary", {
      distance: Math.round(profile.totalDistanceNm),
      time: formatReadableDuration(profile.totalTimeMinutes),
      fuel: formatWeight(requiredOffFuel, { compact: true }),
    });
    updateCalculateWeightSummary(profile);
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
      if (state.calculateOnlineWeatherPending && !profile.weatherOnline) {
        elements.calcWeatherReadout.textContent = t("calculate.weatherReadoutPending");
      } else {
        elements.calcWeatherReadout.textContent = t("calculate.weatherReadout", {
          distance: Math.round(target.distanceNm),
          flightLevel: Math.round(target.altitudeFt / 100),
          wind: Math.round(target.windSpeedKt),
          component: formatSignedWindComponent(target.tailwindKt),
          crosswind: Math.round(Math.abs(target.crosswindKt || 0)),
          cloud: Math.round(target.cloud),
          rain: target.rainMmH.toFixed(1),
        });
      }
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

  function updateCalculatePressureSummary(profile) {
    if (!elements.calcWeatherPressure) {
      return;
    }
    if (!profile?.weatherMeta?.points?.length) {
      elements.calcWeatherPressure.textContent = t("calculate.weatherPressureSummary", {
        departure: "--",
        arrival: "--",
      });
      return;
    }
    const points = profile.weatherMeta.points;
    const departureIdent = state.currentRouteAirports?.departure || profile.route.points[0]?.ident || "DEP";
    const arrivalIdent = state.currentRouteAirports?.arrival || profile.route.points.at(-1)?.ident || "ARR";
    const departure = points[0];
    const arrival = points.at(-1);
    elements.calcWeatherPressure.textContent = t("calculate.weatherPressureSummary", {
      departure: `${departureIdent} ${formatPressure(departure?.qnhHpa)}`,
      arrival: `${arrivalIdent} ${formatPressure(arrival?.qnhHpa)}`,
    });
  }

  function renderCalculatePanel() {
    syncCalculateControls();
    const profile = buildCalculateProfile();
    state.calculateProfileData = profile;
    if (!profile) {
      if (elements.calcStatusText) {
        elements.calcStatusText.textContent = t("calculate.statusNoRoute");
      }
      updateCalculatePressureSummary(null);
      renderCalculateWeatherProfile(null);
      renderCalculateSpeedProfile(null);
      renderCalculateFuel(null);
      updateCalculateReadouts(null);
      return;
    }
    if (elements.calcStatusText) {
      const weatherMode = state.calculateOnlineWeatherPending && !profile.weatherOnline
        ? t("calculate.weatherModePending")
        : profile.weatherOnline
        ? t("calculate.weatherModeOnline", {
          time: formatWeatherTime(profile.weatherMeta?.weatherTime),
          updated: profile.weatherMeta?.updatedAt || "--",
        })
        : t("calculate.weatherModeFallback");
      elements.calcStatusText.textContent = t("calculate.statusReady", {
        count: profile.samples.length,
        source: `${CALC_WEATHER_SOURCE_LABELS[state.calculateWeatherSource]} (${CALC_WEATHER_MODEL_LABELS[profile.weatherMeta?.model || CALC_WEATHER_MODELS[state.calculateWeatherSource]] || profile.weatherMeta?.model || CALC_WEATHER_MODELS[state.calculateWeatherSource]})`,
        mode: weatherMode,
      });
    }
    updateCalculatePressureSummary(profile);
    renderCalculateWeatherProfile(profile);
    renderCalculateSpeedProfile(profile);
    renderCalculateFuel(profile);
    const midpointNm = profile.totalDistanceNm * 0.5;
    const cruiseHeadwindSample = profile.samples
      .filter((sample) => sample.phase === "cruise" && Number(sample.tailwindKt) <= -1)
      .sort((left, right) => Math.abs(left.distanceNm - midpointNm) - Math.abs(right.distanceNm - midpointNm))[0];
    updateCalculateReadouts(cruiseHeadwindSample || nearestProfileSample(profile.samples, midpointNm));
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
    if (event.pointerType === "touch") {
      return;
    }
    const profile = state.calculateProfileData;
    const sample = nearestCalculateSampleFromEvent(event, state.calculateWeatherLayout, profile);
    if (!sample) {
      return;
    }
    event.preventDefault();
    updateCalculateReadouts(sample);
    if (commit) {
      const layout = state.calculateWeatherLayout;
      const rect = event.currentTarget.getBoundingClientRect();
      const y = rect.height > 0
        ? ((event.clientY - rect.top) / rect.height) * layout.height
        : layout.plot.top;
      const rawAltitude = 60000 * (1 - ((y - layout.plot.top) / Math.max(1, layout.height - layout.plot.top - layout.plot.bottom)));
      const roundedAltitude = Math.round(clampNumber(rawAltitude, sample.terrainFt + 1200, 60000) / 1000) * 1000;
      state.calculateAltitudeOverrides.set(sample.profileLegKey || `leg:${sample.legIndex}`, roundedAltitude);
      scheduleCalculateRender();
    }
  }

  function resetCalculateProfileAdjustments() {
    state.calculateAltitudeOverrides.clear();
    state.calculateProfileFocusNm = null;
    state.calculateProfileZoom = 1;
    state.calculateProfilePanRatio = 0.5;
    scheduleCalculateRender();
  }

  function registerEvents() {
    syncCalculateControls({ resetMach: true });
    ensureCalculateResizeObserver();
    elements.calcManufacturerSelect?.addEventListener("change", (event) => {
      state.calculateManufacturer = normalizeCalculateManufacturer(event.target.value);
      state.calculateAircraft = normalizeCalculateAircraft("", state.calculateManufacturer);
      state.calculateCruiseMach = null;
      state.calculateZfwKg = null;
      state.calculateFuelKg = null;
      scheduleCalculateRender();
    });
    elements.calcAircraftSelect?.addEventListener("change", (event) => {
      state.calculateAircraft = normalizeCalculateAircraft(event.target.value, state.calculateManufacturer);
      state.calculateCruiseMach = null;
      state.calculateZfwKg = null;
      state.calculateFuelKg = null;
      scheduleCalculateRender();
    });
    elements.calcZfwInput?.addEventListener("input", (event) => {
      const aircraft = selectedCalculateAircraft();
      state.calculateZfwKg = clampNumber(Number(event.target.value), aircraft.oewKg, aircraft.zfwKg);
      state.calculateFuelKg = clampNumber(Number(state.calculateFuelKg), 0, fuelMaxForZfwKg(aircraft, state.calculateZfwKg));
      updateCalculateSliderProgress(event.target);
      scheduleCalculateRender();
    });
    elements.calcFuelInput?.addEventListener("input", (event) => {
      const aircraft = selectedCalculateAircraft();
      state.calculateFuelKg = clampNumber(Number(event.target.value), 0, fuelMaxForZfwKg(aircraft, state.calculateZfwKg));
      updateCalculateSliderProgress(event.target);
      scheduleCalculateRender();
    });
    elements.calcCruiseAltitudeInput?.addEventListener("input", (event) => {
      state.calculateCruiseAltitudeFt = clampNumber(Number(event.target.value), 10000, 60000);
      state.calculateProfileFocusNm = null;
      updateCalculateSliderProgress(event.target);
      scheduleCalculateRender();
    });
    elements.calcCruiseMachInput?.addEventListener("input", (event) => {
      const aircraft = selectedCalculateAircraft();
      state.calculateCruiseMach = clampNumber(Number(event.target.value), 0.5, aircraft.maxMach);
      updateCalculateSliderProgress(event.target);
      scheduleCalculateRender();
    });
    elements.calcDescentRateInput?.addEventListener("input", (event) => {
      state.calculateDescentRateFpm = clampNumber(Number(event.target.value), 0, 4000);
      updateCalculateSliderProgress(event.target);
      scheduleCalculateRender();
    });
    elements.calcProfileZoomInput?.addEventListener("input", (event) => {
      state.calculateProfileZoom = clampNumber(Number(event.target.value), 1, 4);
      if (state.calculateProfileZoom <= 1.01) {
        state.calculateProfilePanRatio = 0.5;
      }
      updateCalculateSliderProgress(event.target);
      scheduleCalculateRender();
    });
    elements.calcProfilePanInput?.addEventListener("input", (event) => {
      state.calculateProfilePanRatio = clampNumber(Number(event.target.value) / 100, 0, 1);
      updateCalculateSliderProgress(event.target);
      scheduleCalculateRender();
    });
    elements.calcResetProfileButton?.addEventListener("click", resetCalculateProfileAdjustments);
    elements.calcWeatherSourceButtons.forEach((button) => {
      button.addEventListener("click", () => {
        const source = button.dataset.calcWeatherSource;
        state.calculateWeatherSource = CALC_WEATHER_SOURCE_KEYS.has(source) ? source : "ecmwf";
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
    elements.calcWeatherProfileSvg?.addEventListener("pointermove", (event) => {
      handleCalculateWeatherPointer(event);
    });
    elements.calcSpeedProfileSvg?.addEventListener("pointermove", (event) => {
      if (event.pointerType === "touch") {
        return;
      }
      const sample = nearestCalculateSampleFromEvent(event, state.calculateSpeedLayout, state.calculateProfileData);
      if (sample) {
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
