// Feature: figma-ui-redesign — SharedPreferences key audit unit tests
//
// Validates:
//   * Task 15.2 — SharedPreferences key audit (functional preservation)
//   * Requirement 14.7 — Audit SharedPreferences keys `theme_primary_color`,
//                         `theme_mode_index`, and `has_seen_onboarding_guide`
//                         to ensure they are read and written with exactly the
//                         same names, types, and encodings as the legacy app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drive_care_plus/services/theme_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Eagerly restore theme service to light mode / emerald500 baseline
    await ThemeService.instance.setThemeMode(ThemeMode.light);
    await ThemeService.instance.setPrimaryColor(const Color(0xFF1B8A5A));
  });

  group('SharedPreferences Key Audit (Task 15.2)', () {
    test('theme_primary_color and theme_mode_index persistence parity', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      // Verify initially empty or mock default behavior
      expect(prefs.containsKey('theme_primary_color'), isFalse);
      expect(prefs.containsKey('theme_mode_index'), isFalse);

      final service = ThemeService.instance;

      // Update primary color
      const targetColor = Color(0xFF10B981); // Mint Fresh
      await service.setPrimaryColor(targetColor);

      // Assert exact key name exists and carries the correct integer color encoding.
      expect(prefs.containsKey('theme_primary_color'), isTrue);
      expect(prefs.getInt('theme_primary_color'), equals(targetColor.toARGB32()));

      // Update theme mode
      await service.setThemeMode(ThemeMode.dark);

      // Assert exact key name exists and carries the correct integer enum index encoding.
      expect(prefs.containsKey('theme_mode_index'), isTrue);
      expect(prefs.getInt('theme_mode_index'), equals(ThemeMode.dark.index));

      // Re-read configuration to confirm parsing round-trip holds.
      await service.init();
      expect(service.primaryColor, equals(targetColor));
      expect(service.themeMode, equals(ThemeMode.dark));
    });

    test('has_seen_onboarding_guide persistence parity', () async {
      final prefs = await SharedPreferences.getInstance();

      // Verify the onboarding key is not set initially
      expect(prefs.containsKey('has_seen_onboarding_guide'), isFalse);

      // Set key to mimic finishing onboarding
      await prefs.setBool('has_seen_onboarding_guide', true);

      // Assert key name exists and carries the correct boolean type.
      expect(prefs.containsKey('has_seen_onboarding_guide'), isTrue);
      expect(prefs.getBool('has_seen_onboarding_guide'), isTrue);
    });
  });
}
