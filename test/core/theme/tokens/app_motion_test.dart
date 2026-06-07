// Validates: Requirements 1.11
//
// Equality assertions for every named motion token defined in
// `lib/core/theme/tokens/app_motion.dart`.

import 'package:drive_care_plus/core/theme/tokens/app_motion.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppMotion — durations (Requirement 1.11)', () {
    test('fast == 150 ms', () {
      expect(AppMotion.fast, equals(const Duration(milliseconds: 150)));
    });

    test('normal == 300 ms', () {
      expect(AppMotion.normal, equals(const Duration(milliseconds: 300)));
    });

    test('slow == 500 ms', () {
      expect(AppMotion.slow, equals(const Duration(milliseconds: 500)));
    });

    test('durations increase monotonically fast < normal < slow', () {
      expect(AppMotion.fast < AppMotion.normal, isTrue);
      expect(AppMotion.normal < AppMotion.slow, isTrue);
    });
  });

  group('AppMotion — curves (Requirement 1.11)', () {
    test('standard == Curves.easeInOut', () {
      expect(AppMotion.standard, same(Curves.easeInOut));
    });

    test('emphasized == Curves.easeOutCubic', () {
      expect(AppMotion.emphasized, same(Curves.easeOutCubic));
    });
  });
}
