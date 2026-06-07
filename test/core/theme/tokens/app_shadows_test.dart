// Validates: Requirements 1.7, 1.8
//
// Equality assertions for every named shadow token defined in
// `lib/core/theme/tokens/app_shadows.dart`. The Reference_Source values are:
//
//   small  → rgba(0, 0, 0, 0.05) blur=2  offset=(0, 1)
//   medium → rgba(0, 0, 0, 0.10) blur=6  offset=(0, 4)
//   large  → rgba(0, 0, 0, 0.10) blur=15 offset=(0, 10)
//   xLarge → rgba(0, 0, 0, 0.15) blur=25 offset=(0, 20)
//
// The light-mode opacity bytes are pinned via the ARGB literals:
//   0x0D ≈ 13/255 ≈ 0.05
//   0x1A ≈ 26/255 ≈ 0.10
//   0x26 ≈ 38/255 ≈ 0.15
//
// `darkOpacityMultiplier` is asserted to equal the documented `2.5` factor
// applied at theme-build time via `color_utils.scaleShadowOpacity`
// (Requirement 1.8).

import 'package:drive_care_plus/core/theme/tokens/app_shadows.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppShadows — light-mode shadow scale (Requirement 1.7)', () {
    test('small is a single BoxShadow: 0x0D000000, blur=2, offset=(0, 1)', () {
      expect(AppShadows.small, hasLength(1));
      final BoxShadow s = AppShadows.small.single;
      expect(s.color, equals(const Color(0x0D000000)));
      expect(s.blurRadius, equals(2.0));
      expect(s.offset, equals(const Offset(0, 1)));
      expect(s.spreadRadius, equals(0.0));
      expect(s.blurStyle, equals(BlurStyle.normal));
    });

    test('medium is a single BoxShadow: 0x1A000000, blur=6, offset=(0, 4)',
        () {
      expect(AppShadows.medium, hasLength(1));
      final BoxShadow s = AppShadows.medium.single;
      expect(s.color, equals(const Color(0x1A000000)));
      expect(s.blurRadius, equals(6.0));
      expect(s.offset, equals(const Offset(0, 4)));
      expect(s.spreadRadius, equals(0.0));
      expect(s.blurStyle, equals(BlurStyle.normal));
    });

    test('large is a single BoxShadow: 0x1A000000, blur=15, offset=(0, 10)',
        () {
      expect(AppShadows.large, hasLength(1));
      final BoxShadow s = AppShadows.large.single;
      expect(s.color, equals(const Color(0x1A000000)));
      expect(s.blurRadius, equals(15.0));
      expect(s.offset, equals(const Offset(0, 10)));
      expect(s.spreadRadius, equals(0.0));
      expect(s.blurStyle, equals(BlurStyle.normal));
    });

    test('xLarge is a single BoxShadow: 0x26000000, blur=25, offset=(0, 20)',
        () {
      expect(AppShadows.xLarge, hasLength(1));
      final BoxShadow s = AppShadows.xLarge.single;
      expect(s.color, equals(const Color(0x26000000)));
      expect(s.blurRadius, equals(25.0));
      expect(s.offset, equals(const Offset(0, 20)));
      expect(s.spreadRadius, equals(0.0));
      expect(s.blurStyle, equals(BlurStyle.normal));
    });

    test('opacity bytes encode the expected fractional values', () {
      // 0x0D / 0xFF ≈ 0.05098…
      expect(AppShadows.small.single.color.a, closeTo(0.05, 0.005));
      // 0x1A / 0xFF ≈ 0.10196…
      expect(AppShadows.medium.single.color.a, closeTo(0.10, 0.005));
      expect(AppShadows.large.single.color.a, closeTo(0.10, 0.005));
      // 0x26 / 0xFF ≈ 0.14902…
      expect(AppShadows.xLarge.single.color.a, closeTo(0.15, 0.005));
    });
  });

  group('AppShadows — dark-mode multiplier (Requirement 1.8)', () {
    test('darkOpacityMultiplier == 2.5', () {
      expect(AppShadows.darkOpacityMultiplier, equals(2.5));
    });
  });
}
