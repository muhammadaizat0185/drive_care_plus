// Validates: Requirements 1.2, 1.3, 2.1, 2.2
//
// Equality assertions for every named color token defined in
// `lib/core/theme/tokens/app_colors.dart`. The redesigned screens, theme
// builder, and Component_Library all read these literals as the single
// source of truth, so each entry is asserted against an exact ARGB literal
// and against its surface-opacity numeric value where applicable.
//
// The dark-mode neutrals are pre-computed from the Reference_Source OKLCH
// values (`oklch(0.145 0 0)`, `oklch(0.985 0 0)`, `oklch(0.269 0 0)`) and
// frozen as `Color(0xFFRRGGBB)` literals; the assertions below pin those
// frozen values byte-for-byte (Requirement 2.2 — within ±1 per channel).

import 'package:drive_care_plus/core/theme/tokens/app_colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors — brand gradient palette (Requirement 1.2)', () {
    test('emerald500 == #10B981', () {
      expect(AppColors.emerald500, equals(const Color(0xFF10B981)));
    });

    test('emerald600 == #059669', () {
      expect(AppColors.emerald600, equals(const Color(0xFF059669)));
    });

    test('teal400 == #2DD4BF', () {
      expect(AppColors.teal400, equals(const Color(0xFF2DD4BF)));
    });

    test('teal500 == #14B8A6', () {
      expect(AppColors.teal500, equals(const Color(0xFF14B8A6)));
    });
  });

  group('AppColors — semantic palette (Requirement 1.2)', () {
    test('success == #10B981', () {
      expect(AppColors.success, equals(const Color(0xFF10B981)));
    });

    test('warning == #F59E0B', () {
      expect(AppColors.warning, equals(const Color(0xFFF59E0B)));
    });

    test('error == #EF4444', () {
      expect(AppColors.error, equals(const Color(0xFFEF4444)));
    });

    test('info == #3B82F6', () {
      expect(AppColors.info, equals(const Color(0xFF3B82F6)));
    });
  });

  group('AppColors — Light_Theme neutrals (Requirement 2.1)', () {
    test('lightBackground == #FFFFFF', () {
      expect(AppColors.lightBackground, equals(const Color(0xFFFFFFFF)));
    });

    test('lightForeground == #111827', () {
      expect(AppColors.lightForeground, equals(const Color(0xFF111827)));
    });

    test('lightCard == #FFFFFF', () {
      expect(AppColors.lightCard, equals(const Color(0xFFFFFFFF)));
    });

    test('lightMuted == #ECECF0', () {
      expect(AppColors.lightMuted, equals(const Color(0xFFECECF0)));
    });

    test('lightBorder == rgba(0, 0, 0, 0.1) → 0x1A000000', () {
      expect(AppColors.lightBorder, equals(const Color(0x1A000000)));
    });
  });

  group('AppColors — Dark_Theme neutrals (Requirement 2.2)', () {
    test('darkBackground == #1A1A1A (oklch(0.145 0 0))', () {
      expect(AppColors.darkBackground, equals(const Color(0xFF1A1A1A)));
    });

    test('darkForeground == #FAFAFA (oklch(0.985 0 0))', () {
      expect(AppColors.darkForeground, equals(const Color(0xFFFAFAFA)));
    });

    test('darkCard == #1A1A1A (oklch(0.145 0 0))', () {
      expect(AppColors.darkCard, equals(const Color(0xFF1A1A1A)));
    });

    test('darkPopover == #1A1A1A (oklch(0.145 0 0))', () {
      expect(AppColors.darkPopover, equals(const Color(0xFF1A1A1A)));
    });

    test('darkBorder == #373737 (oklch(0.269 0 0))', () {
      expect(AppColors.darkBorder, equals(const Color(0xFF373737)));
    });
  });

  group('AppColors — surface overlay opacities (Requirement 1.3)', () {
    test('surfaceSubtle == 0.05', () {
      expect(AppColors.surfaceSubtle, equals(0.05));
    });

    test('surfaceMedium == 0.12', () {
      expect(AppColors.surfaceMedium, equals(0.12));
    });

    test('surfaceProminent == 0.20', () {
      expect(AppColors.surfaceProminent, equals(0.20));
    });

    test('every surface opacity lies in [0.0, 1.0]', () {
      expect(AppColors.surfaceSubtle, inInclusiveRange(0.0, 1.0));
      expect(AppColors.surfaceMedium, inInclusiveRange(0.0, 1.0));
      expect(AppColors.surfaceProminent, inInclusiveRange(0.0, 1.0));
    });
  });
}
