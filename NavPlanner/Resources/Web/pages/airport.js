export function registerAirportPage(context) {
  const {
    elements,
    map,
    airportSlots,
    airportForSlot,
    setActiveAirportSlot,
  } = context;

  function focusAirportSlot(slot) {
    const airport = airportForSlot(slot);
    if (!airport) {
      return;
    }
    map.flyTo(
      [airport.airport_ref_latitude, airport.airport_ref_longitude],
      9,
      { duration: 0.7 },
    );
  }

  elements.focusDepartureButton?.addEventListener("click", () => focusAirportSlot("departure"));
  elements.focusArrivalButton?.addEventListener("click", () => focusAirportSlot("arrival"));
  elements.focusManualButton?.addEventListener("click", () => focusAirportSlot("manual"));

  airportSlots.forEach((slot) => {
    elements[`${slot}AirportTab`]?.addEventListener("click", () => setActiveAirportSlot(slot));
  });
}
