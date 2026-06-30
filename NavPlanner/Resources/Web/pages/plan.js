export function registerPlanPage(context) {
  const {
    elements,
    buildRoute,
    clearAllMapDrawings,
    stopActiveRouteOperation,
  } = context;

  elements.planButton?.addEventListener("click", buildRoute);
  elements.recalculateButton?.addEventListener("click", () => buildRoute({ forceAuto: true }));
  elements.planClearTrackButton?.addEventListener("click", clearAllMapDrawings);
  elements.stopRequestButton?.addEventListener("click", stopActiveRouteOperation);
}
