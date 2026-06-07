import 'package:flutter/material.dart';

import '../../services/theme_service.dart';

/// Preset color validation guard for theme primary-color changes.
///
/// `ThemeService.setPrimaryColor` accepts any `Color` today. The redesign
/// adds a guard at the public interaction surface (Settings and any other
/// caller that exposes a color choice) so non-preset colors are rejected
/// before they reach `ThemeService` and the active light/dark themes are
/// retained without modification.
///
/// Validates: Requirement 2.7 — non-preset rejection preserves the
/// previously applied Light_Theme and Dark_Theme and surfaces an error to
/// the caller.

/// Error thrown by [setPrimaryColorValidated] when the supplied color is
/// not one of the values in `ThemeService.presets`.
class NonPresetColorError extends ArgumentError {
  NonPresetColorError(Color color)
      : super.value(
          color,
          'color',
          'Color is not a member of ThemeService.presets; '
              'theme primary color was not changed.',
        );
}

/// Returns `true` iff [color] is one of the values in `ThemeService.presets`.
///
/// Equality is by `Color.value` (Flutter's `operator ==` for `Color`).
bool isPresetColor(Color color) {
  for (final preset in ThemeService.presets.values) {
    if (preset == color) return true;
  }
  return false;
}

/// Validates [color] against the preset list and, if valid, forwards to
/// `ThemeService.instance.setPrimaryColor`.
///
/// Throws [NonPresetColorError] without mutating any `ThemeService` state
/// when [color] is not a preset, satisfying Requirement 2.7's contract that
/// non-preset attempts retain the previously applied themes.
Future<void> setPrimaryColorValidated(Color color) async {
  if (!isPresetColor(color)) {
    throw NonPresetColorError(color);
  }
  await ThemeService.instance.setPrimaryColor(color);
}
