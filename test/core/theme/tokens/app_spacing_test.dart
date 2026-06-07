// Validates: Requirements 1.4
//
// Equality assertions for every named spacing token defined in
// `lib/core/theme/tokens/app_spacing.dart`.
//
// The Reference_Source spacing scale is geometric and every screen, card,
// and component reads from this token, so each entry is pinned to its
// canonical logical-pixel value.

import 'package:drive_care_plus/core/theme/tokens/app_spacing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSpacing — geometric scale (Requirement 1.4)', () {
    test('xs == 4.0', () {
      expect(AppSpacing.xs, equals(4.0));
    });

    test('sm == 8.0', () {
      expect(AppSpacing.sm, equals(8.0));
    });

    test('md == 12.0', () {
      expect(AppSpacing.md, equals(12.0));
    });

    test('lg == 16.0', () {
      expect(AppSpacing.lg, equals(16.0));
    });

    test('xl == 24.0', () {
      expect(AppSpacing.xl, equals(24.0));
    });

    test('xxl == 32.0', () {
      expect(AppSpacing.xxl, equals(32.0));
    });

    test('xxxl == 40.0', () {
      expect(AppSpacing.xxxl, equals(40.0));
    });

    test('xxxxl == 48.0', () {
      expect(AppSpacing.xxxxl, equals(48.0));
    });
  });

  group('AppSpacing — scale ordering', () {
    test('values increase monotonically xs < sm < md < lg < xl < xxl < xxxl < '
        'xxxxl', () {
      final List<double> ordered = [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxxxl,
      ];
      for (int i = 1; i < ordered.length; i++) {
        expect(ordered[i] > ordered[i - 1], isTrue,
            reason: 'index $i (${ordered[i]}) must exceed index ${i - 1} '
                '(${ordered[i - 1]})');
      }
    });
  });
}
