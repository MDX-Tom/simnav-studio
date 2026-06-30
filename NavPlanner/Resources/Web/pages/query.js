export function registerQueryPage(context) {
  const {
    elements,
    state,
    t,
    formatBytes,
    formatCount,
    searchFR24Flights,
    importFR24GPX,
    searchFR24ManualHistory,
    handleFR24FlightAction,
    searchFR24Cache,
    clearFR24TrackDrawing,
    restoreFR24MatchedRoute,
    clearFR24Cache,
    refreshFR24CacheStatus,
    setFR24QueryStatus,
    openFR24CacheDirectory,
    openFR24VerificationBrowser,
    syncFR24BrowserSession,
    saveFR24Access,
    clearFR24Access,
    refreshFR24AccessStatus,
    updateFR24ProfileCursor,
    handleFR24ProfilePointer,
    ensureFR24ProfileResizeObserver,
    setErrorStatus,
  } = context;

  elements.fr24SearchButton?.addEventListener("click", () => {
    searchFR24Flights().catch(setErrorStatus);
  });
  elements.fr24ImportGPXButton?.addEventListener("click", importFR24GPX);
  elements.fr24ManualHistoryButton?.addEventListener("click", () => {
    searchFR24ManualHistory().catch(setErrorStatus);
  });
  elements.fr24ManualHistoryInput?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      searchFR24ManualHistory().catch(setErrorStatus);
    }
  });
  elements.fr24FlightList?.addEventListener("click", handleFR24FlightAction);
  elements.fr24CacheSearchButton?.addEventListener("click", () => {
    searchFR24Cache().catch(setErrorStatus);
  });
  elements.fr24CacheSearchInput?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      searchFR24Cache().catch(setErrorStatus);
    }
  });
  elements.fr24CacheList?.addEventListener("click", handleFR24FlightAction);
  elements.fr24ClearTrackButton?.addEventListener("click", clearFR24TrackDrawing);
  elements.fr24RestoreMatchButton?.addEventListener("click", () => {
    restoreFR24MatchedRoute().catch(setErrorStatus);
  });
  elements.fr24ClearCacheButton?.addEventListener("click", () => {
    clearFR24Cache().catch(setErrorStatus);
  });
  elements.fr24RefreshCacheButton?.addEventListener("click", () => {
    refreshFR24CacheStatus()
      .then(() => setFR24QueryStatus(t("query.cacheSummary", {
        size: formatBytes(state.fr24CacheStatus?.size_bytes || 0),
        count: formatCount(state.fr24CacheStatus?.file_count || 0),
      })))
      .catch(setErrorStatus);
  });
  elements.fr24OpenCacheDirectoryButton?.addEventListener("click", openFR24CacheDirectory);
  elements.fr24OpenBrowserButton?.addEventListener("click", openFR24VerificationBrowser);
  elements.fr24SyncBrowserButton?.addEventListener("click", syncFR24BrowserSession);
  elements.fr24SaveAccessButton?.addEventListener("click", () => {
    saveFR24Access().catch(setErrorStatus);
  });
  elements.fr24ClearAccessButton?.addEventListener("click", () => {
    clearFR24Access().catch(setErrorStatus);
  });
  elements.fr24RefreshAccessButton?.addEventListener("click", () => {
    refreshFR24AccessStatus()
      .then(() => setFR24QueryStatus(elements.fr24AccessSummary?.textContent || t("query.accessInitial")))
      .catch(setErrorStatus);
  });
  elements.fr24ProfileSlider?.addEventListener("input", (event) => {
    updateFR24ProfileCursor(Number(event.target.value));
  });
  elements.fr24ProfileSvg?.addEventListener("pointerdown", (event) => {
    state.fr24ProfileDragging = true;
    elements.fr24ProfileSvg.setPointerCapture?.(event.pointerId);
    handleFR24ProfilePointer(event);
  });
  elements.fr24ProfileSvg?.addEventListener("pointermove", (event) => {
    if (state.fr24ProfileDragging) {
      handleFR24ProfilePointer(event);
    }
  });
  elements.fr24ProfileSvg?.addEventListener("pointerup", (event) => {
    state.fr24ProfileDragging = false;
    elements.fr24ProfileSvg.releasePointerCapture?.(event.pointerId);
  });
  elements.fr24ProfileSvg?.addEventListener("pointercancel", () => {
    state.fr24ProfileDragging = false;
  });
  ensureFR24ProfileResizeObserver();
}
