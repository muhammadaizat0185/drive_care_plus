/// Pure refuel-math helper used by the refuel-log screen and any other
/// surface that needs to display fuel efficiency derived from a refuel entry.
///
/// Computes fuel efficiency in kilometers-per-liter from a [distanceKm]
/// (kilometers travelled since the previous fill-up) and [liters] (volume of
/// fuel added at this fill-up):
///
/// * If `liters <= 0`            → returns `0.0` (guard against division by
///                                  zero or by a negative volume, which has
///                                  no physical meaning for a refuel entry).
/// * Otherwise                    → returns `distanceKm / liters`.
///
/// The function does not validate [distanceKm]; a negative or zero distance
/// is propagated through the division so callers can decide how to render
/// the result. NaN/infinity inputs are likewise propagated by Dart's IEEE-754
/// double arithmetic.
///
/// Pure: no IO, no side effects, deterministic for any `(distanceKm, liters)`
/// pair.
///
/// See: figma-ui-redesign Requirement 9.7.
double kmPerLiter(double distanceKm, double liters) {
  if (liters <= 0) {
    return 0.0;
  }
  return distanceKm / liters;
}
