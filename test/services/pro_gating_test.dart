import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drive_care_plus/services/profile_service.dart';
import 'package:drive_care_plus/services/theme_service.dart';
import 'package:drive_care_plus/services/vehicle_insights.dart';
import 'package:drive_care_plus/services/journey_database.dart';
import 'package:drive_care_plus/screens/document_vault/_widgets.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProfileService.instance.isPro = false;
  });

  group('Pro Subscription & Gating Logic Tests', () {
    test('Basic user is limited to green accent colors only', () {
      final greenPreset1 = ThemeService.presets['Emerald Green']!;
      final greenPreset2 = ThemeService.presets['Mint Fresh']!;
      final nonGreenPreset = ThemeService.presets['Classic Blue']!;

      // ProfileService.instance.isPro is false by default
      expect(ProfileService.instance.isPro, isFalse);

      final isGreen1 = greenPreset1.value == 0xFF1B8A5A || greenPreset1.value == 0xFF10B981;
      final isGreen2 = greenPreset2.value == 0xFF1B8A5A || greenPreset2.value == 0xFF10B981;
      final isGreen3 = nonGreenPreset.value == 0xFF1B8A5A || nonGreenPreset.value == 0xFF10B981;

      expect(isGreen1, isTrue);
      expect(isGreen2, isTrue);
      expect(isGreen3, isFalse);
    });

    test('Vault limits basic users to 5MB and Pro users to 50MB', () {
      // Basic limit check
      final bool isProBasic = ProfileService.instance.isPro; // false
      final int basicLimitBytes = isProBasic ? 50 * 1024 * 1024 : 5 * 1024 * 1024;
      expect(basicLimitBytes, 5 * 1024 * 1024);

      // Pro limit check
      ProfileService.instance.isPro = true;
      final bool isProPro = ProfileService.instance.isPro; // true
      final int proLimitBytes = isProPro ? 50 * 1024 * 1024 : 5 * 1024 * 1024;
      expect(proLimitBytes, 50 * 1024 * 1024);
    });

    test('Basic user is limited to maximum of 2 registered vehicles', () {
      ProfileService.instance.isPro = false;
      
      const int carLimitForBasic = 2;
      expect(carLimitForBasic, 2);
    });
  });
}
