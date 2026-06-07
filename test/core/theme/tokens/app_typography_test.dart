// Validates: Requirements 1.6, 13.1, 13.2
//
// Equality assertions for every named typography token defined in
// `lib/core/theme/tokens/app_typography.dart`.
//
// Each `TextStyle` is asserted to have the exact `fontSize` and
// `fontWeight` mandated by the Reference_Source type ramp:
//
//   display       → 32 / w900
//   headlineLarge → 24 / w900
//   headline      → 20 / w800
//   title         → 16 / w700
//   bodyLarge     → 14 / w400
//   body          → 12 / w400  (Accessibility_Floor — Requirement 13.1)
//   label         → 10 / w700  (Accessibility_Floor — Requirement 13.2)

import 'package:drive_care_plus/core/theme/tokens/app_typography.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTypography — type ramp (Requirement 1.6)', () {
    test('display has fontSize=32, fontWeight=w900', () {
      expect(AppTypography.display.fontSize, equals(32));
      expect(AppTypography.display.fontWeight, equals(FontWeight.w900));
    });

    test('headlineLarge has fontSize=24, fontWeight=w900', () {
      expect(AppTypography.headlineLarge.fontSize, equals(24));
      expect(AppTypography.headlineLarge.fontWeight, equals(FontWeight.w900));
    });

    test('headline has fontSize=20, fontWeight=w800', () {
      expect(AppTypography.headline.fontSize, equals(20));
      expect(AppTypography.headline.fontWeight, equals(FontWeight.w800));
    });

    test('title has fontSize=16, fontWeight=w700', () {
      expect(AppTypography.title.fontSize, equals(16));
      expect(AppTypography.title.fontWeight, equals(FontWeight.w700));
    });

    test('bodyLarge has fontSize=14, fontWeight=w400', () {
      expect(AppTypography.bodyLarge.fontSize, equals(14));
      expect(AppTypography.bodyLarge.fontWeight, equals(FontWeight.w400));
    });
  });

  group('AppTypography — accessibility floors '
      '(Requirements 13.1, 13.2)', () {
    test('body has fontSize=12 (body Accessibility_Floor) and fontWeight=w400',
        () {
      expect(AppTypography.body.fontSize, equals(12),
          reason: 'Requirement 13.1 mandates 12 logical pixels for body text');
      expect(AppTypography.body.fontWeight, equals(FontWeight.w400));
    });

    test('label has fontSize=10 (label Accessibility_Floor) and '
        'fontWeight=w700', () {
      expect(AppTypography.label.fontSize, equals(10),
          reason: 'Requirement 13.2 mandates 10 logical pixels for label text');
      expect(AppTypography.label.fontWeight, equals(FontWeight.w700));
    });
  });

  group('AppTypography — type ramp ordering', () {
    test('fontSize decreases monotonically '
        'display > headlineLarge > headline > title > bodyLarge > body > label',
        () {
      final List<double> sizes = [
        AppTypography.display.fontSize!,
        AppTypography.headlineLarge.fontSize!,
        AppTypography.headline.fontSize!,
        AppTypography.title.fontSize!,
        AppTypography.bodyLarge.fontSize!,
        AppTypography.body.fontSize!,
        AppTypography.label.fontSize!,
      ];
      for (int i = 1; i < sizes.length; i++) {
        expect(sizes[i] < sizes[i - 1], isTrue,
            reason: 'size at index $i (${sizes[i]}) must be less than '
                'index ${i - 1} (${sizes[i - 1]})');
      }
    });
  });
}
