(() => {
  "use strict";

  const storageKey = "navplannerUIZoomLevel";
  const allowedLevels = new Set([-1, 0, 1, 2]);

  function normalizeLevel(value) {
    const parsed = Number.parseInt(String(value), 10);
    return allowedLevels.has(parsed) ? parsed : 0;
  }

  function factorForLevel(value) {
    return 1 + normalizeLevel(value) * 0.08;
  }

  function deviceBaseScale() {
    const root = document.documentElement;
    if (root.dataset.device !== "pad") {
      return 1;
    }
    if (root.dataset.platform === "ios" && root.dataset.mobileLayout === "true") {
      return 1;
    }
    return root.dataset.platform === "mac" ? 0.9 : 0.8;
  }

  function readSavedLevel() {
    try {
      return normalizeLevel(window.localStorage.getItem(storageKey));
    } catch (_) {
      return 0;
    }
  }

  function writeSavedLevel(level) {
    try {
      window.localStorage.setItem(storageKey, String(level));
    } catch (_) {
      // A restricted WebView may reject localStorage; the current session still updates.
    }
  }

  function apply(value, { persist = true } = {}) {
    const level = normalizeLevel(value);
    const factor = factorForLevel(level);
    const effectiveScale = deviceBaseScale() * factor;
    const inversePercentage = 100 / effectiveScale;
    const root = document.documentElement;
    root.dataset.uiZoomLevel = String(level);
    root.style.setProperty("--ui-zoom-scale", effectiveScale.toFixed(6));
    root.style.setProperty("--ui-viewport-height", `${inversePercentage.toFixed(6)}vh`);
    if (persist) {
      writeSavedLevel(level);
    }
    return Object.freeze({ level, factor, effectiveScale });
  }

  function current() {
    return apply(document.documentElement.dataset.uiZoomLevel, { persist: false });
  }

  window.SimNavUIZoom = Object.freeze({
    version: 1,
    storageKey,
    normalizeLevel,
    factorForLevel,
    apply,
    current,
  });

  apply(readSavedLevel(), { persist: false });
})();
