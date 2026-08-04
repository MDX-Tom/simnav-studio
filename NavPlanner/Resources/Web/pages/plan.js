export function registerPlanPage(context) {
  const {
    elements,
    buildRoute,
    clearAllMapDrawings,
    resetAndReplan,
    stopActiveRouteOperation,
  } = context;

  elements.planButton?.addEventListener("click", buildRoute);
  elements.recalculateButton?.addEventListener("click", () => buildRoute({ forceAuto: true }));
  elements.planClearTrackButton?.addEventListener("click", clearAllMapDrawings);
  elements.resetAndReplanButton?.addEventListener("click", resetAndReplan);
  elements.stopRequestButton?.addEventListener("click", stopActiveRouteOperation);
}
