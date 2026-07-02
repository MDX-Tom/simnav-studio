export function registerSettingsPage(context) {
  const {
    elements,
    t,
    requestDatabaseSelection,
    refreshDatabaseList,
    restoreBundledDatabase,
    handleDatabaseListAction,
    openOfflineMapManagerFromSettings,
    refreshOfflineMapStatus,
    refreshMapCacheStatus,
    clearMapCache,
    resetAllSettingsAndCaches,
    applyThemeMode,
    applyLanguageMode,
    applyWeightUnit,
    applyAppIconChoice,
    applyMapSourceChoice,
    applyOnlineMapProvider,
    applyMapTileZoomOffset,
    setStatus,
    setErrorStatus,
  } = context;

  elements.selectDatabaseButton?.addEventListener("click", requestDatabaseSelection);
  elements.refreshDatabaseListButton?.addEventListener("click", () => {
    refreshDatabaseList({ announce: true }).catch(setErrorStatus);
  });
  elements.restoreBundledDatabaseButton?.addEventListener("click", () => {
    restoreBundledDatabase().catch(setErrorStatus);
  });
  elements.databaseSearchInput?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      refreshDatabaseList({ announce: true }).catch(setErrorStatus);
    }
  });
  elements.databaseList?.addEventListener("click", handleDatabaseListAction);
  elements.manageOfflineMapsButton?.addEventListener("click", () => openOfflineMapManagerFromSettings("manage"));
  elements.refreshOfflineMapsButton?.addEventListener("click", () => {
    refreshOfflineMapStatus()
      .then(() => setStatus(t("offline.statusRefreshed")))
      .catch(setErrorStatus);
  });
  elements.refreshMapCacheButton?.addEventListener("click", () => {
    refreshMapCacheStatus({ announce: true }).catch(setErrorStatus);
  });
  elements.clearMapCacheButton?.addEventListener("click", () => {
    clearMapCache().catch(setErrorStatus);
  });
  elements.resetAllSettingsButton?.addEventListener("click", () => {
    resetAllSettingsAndCaches().catch(setErrorStatus);
  });
  elements.themeChoiceButtons.forEach((button) => {
    button.addEventListener("click", () => applyThemeMode(button.dataset.themeChoice));
  });
  elements.languageChoiceButtons.forEach((button) => {
    button.addEventListener("click", () => applyLanguageMode(button.dataset.languageChoice));
  });
  elements.weightUnitButtons.forEach((button) => {
    button.addEventListener("click", () => applyWeightUnit(button.dataset.weightUnitChoice));
  });
  elements.appIconChoiceButtons.forEach((button) => {
    button.addEventListener("click", () => applyAppIconChoice(button.dataset.appIconChoice));
  });
  elements.mapSourceChoiceButtons.forEach((button) => {
    button.addEventListener("click", () => applyMapSourceChoice(button.dataset.mapSourceChoice));
  });
  elements.onlineMapProviderButtons.forEach((button) => {
    button.addEventListener("click", () => applyOnlineMapProvider(button.dataset.onlineMapProvider));
  });
  elements.mapTileZoomOffsetInput?.addEventListener("input", () => {
    applyMapTileZoomOffset(elements.mapTileZoomOffsetInput.value, { announce: false });
  });
  elements.mapTileZoomOffsetInput?.addEventListener("change", () => {
    applyMapTileZoomOffset(elements.mapTileZoomOffsetInput.value, { announce: true });
  });
}
