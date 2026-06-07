// Validates: Requirements 1.5
//
// Equality assertions for every named corner-radius token defined in
// `lib/core/theme/tokens/app_radii.dart`.

import 'package:drive_care_plus/core/theme/tokens/app_radii.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRadii — corner-radius scale (Requirement 1.5)', () {
    test('small == 12.0', () {
      expect(AppRadii.small, equals(12.0));
    });

    test('medium == 16.0', () {
      expect(AppRadii.medium, equals(16.0));
    });

    test('large == 24.0', () {
      expect(AppRadii.large, equals(24.0));
    });

    test('xLarge == 32.0', () {
      expect(AppRadii.xLarge, equals(32.0));
    });

    test('values increase monotonically small < medium < large < xLarge', () {
      expect(AppRadii.small < AppRadii.medium, isTrue);
      expect(AppRadii.medium < AppRadii.large, isTrue);
      expect(AppRadii.large < AppRadii.xLarge, isTrue);
    });
  });
}
