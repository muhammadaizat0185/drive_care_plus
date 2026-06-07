/// Pure helper for normalizing a raw `double?` percentage value into a safe
/// integer in the inclusive range `[0, 100]`, suitable for rendering in
/// `AppHealthGauge` and the four-tile health metrics grid.
///
/// Behaviour:
///
/// * If [value] is `null`            → returns `null` (caller renders a
///                                      `--%` placeholder).
/// * If [value] is not finite        → returns `null` (NaN, +infinity, and
///                                      -infinity are treated as missing
///                                      data; caller renders `--%`).
/// * Otherwise                        → returns
///                                      `value.clamp(0.0, 100.0).round()`,
///                                      guaranteed to be an `int` in the
///                                      inclusive range `[0, 100]`.
///
/// Pure: no IO, no side effects, deterministic for any input.
///
/// See: figma-ui-redesign Requirements 4.3, 8.2.
int? clampPercentage(double? value) {
  if (value == null) {
    return null;
  }
  if (!value.isFinite) {
    return null;
  }
  return value.clamp(0.0, 100.0).round();
}
