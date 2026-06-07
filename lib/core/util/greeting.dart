/// Pure greeting helper used by the cockpit/home screen header.
///
/// Returns a greeting string of the form `"<prefix>, <namePart>"` where:
///
/// * The `prefix` is determined by [hour24]:
///   * `6 <= hour24 <= 11`  → `"Good morning"`
///   * `12 <= hour24 <= 17` → `"Good afternoon"`
///   * else (`hour24 >= 18` OR `hour24 <= 5`) → `"Good evening"`
///
/// * The `namePart` is determined by [firstName]:
///   * If [firstName] is `null`, empty, or whitespace-only → `"there"`
///   * Otherwise → `firstName.trim()`
///
/// The function does not validate the [hour24] range; the third branch is a
/// catch-all so every integer maps to a valid greeting prefix.
///
/// Pure: no IO, no side effects, no allocations beyond the returned string.
///
/// See: figma-ui-redesign Requirements 4.1, 4.2.
String getGreeting(int hour24, String? firstName) {
  final String prefix;
  if (hour24 >= 6 && hour24 <= 11) {
    prefix = 'Good morning';
  } else if (hour24 >= 12 && hour24 <= 17) {
    prefix = 'Good afternoon';
  } else {
    prefix = 'Good evening';
  }

  final String namePart;
  if (firstName == null || firstName.trim().isEmpty) {
    namePart = 'there';
  } else {
    namePart = firstName.trim();
  }

  return '$prefix, $namePart';
}
