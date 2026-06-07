// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;

// =============================================================================
// Authoritative design token colors from AppColors
// =============================================================================
const int emerald500 = 0xFF10B981;
const int emerald600 = 0xFF059669;
const int teal400 = 0xFF2DD4BF;
const int teal500 = 0xFF14B8A6;
const int success = 0xFF10B981;
const int warning = 0xFFF59E0B;
const int error = 0xFFEF4444;
const int info = 0xFF3B82F6;
const int lightBackground = 0xFFFFFFFF;
const int lightForeground = 0xFF111827;
const int lightCard = 0xFFFFFFFF;
const int lightMuted = 0xFFECECF0;
const int darkBackground = 0xFF1A1A1A;
const int darkForeground = 0xFFFAFAFA;
const int darkCard = 0xFF1A1A1A;
const int darkPopover = 0xFF1A1A1A;

// =============================================================================
// WCAG 2.1 Relative Luminance and Contrast Formula
// =============================================================================
double _channelToLinear(double c) {
  if (c <= 0.03928) {
    return c / 12.92;
  }
  return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(int argb) {
  final double r = ((argb >> 16) & 0xFF) / 255.0;
  final double g = ((argb >> 8) & 0xFF) / 255.0;
  final double b = (argb & 0xFF) / 255.0;

  final double rLin = _channelToLinear(r);
  final double gLin = _channelToLinear(g);
  final double bLin = _channelToLinear(b);

  return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin;
}

double contrastRatio(int fg, int bg) {
  final double lFg = relativeLuminance(fg);
  final double lBg = relativeLuminance(bg);
  final double lighter = lFg > lBg ? lFg : lBg;
  final double darker = lFg > lBg ? lBg : lFg;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  print('======================================================================');
  print('DriveCare+ Contrast Ratio Lint Auditor (Pure Dart CLI)');
  print('======================================================================\n');

  final List<TokenPair> passingPairs = [
    TokenPair(
      name: 'lightForeground on lightBackground',
      fg: lightForeground,
      bg: lightBackground,
      threshold: 4.5,
    ),
    TokenPair(
      name: 'lightForeground on lightCard',
      fg: lightForeground,
      bg: lightCard,
      threshold: 4.5,
    ),
    TokenPair(
      name: 'lightForeground on lightMuted',
      fg: lightForeground,
      bg: lightMuted,
      threshold: 4.5,
    ),
    TokenPair(
      name: 'white on error',
      fg: 0xFFFFFFFF,
      bg: error,
      threshold: 3.0,
    ),
    TokenPair(
      name: 'white on info',
      fg: 0xFFFFFFFF,
      bg: info,
      threshold: 3.0,
    ),
    TokenPair(
      name: 'darkForeground on darkBackground',
      fg: darkForeground,
      bg: darkBackground,
      threshold: 4.5,
    ),
    TokenPair(
      name: 'darkForeground on darkCard',
      fg: darkForeground,
      bg: darkCard,
      threshold: 4.5,
    ),
    TokenPair(
      name: 'darkForeground on darkPopover',
      fg: darkForeground,
      bg: darkPopover,
      threshold: 4.5,
    ),
    TokenPair(
      name: 'white on error (dark)',
      fg: 0xFFFFFFFF,
      bg: error,
      threshold: 3.0,
    ),
    TokenPair(
      name: 'white on info (dark)',
      fg: 0xFFFFFFFF,
      bg: info,
      threshold: 3.0,
    ),
    TokenPair(
      name: 'emerald500 on darkCard',
      fg: emerald500,
      bg: darkCard,
      threshold: 3.0,
    ),
    TokenPair(
      name: 'error on darkBackground',
      fg: error,
      bg: darkBackground,
      threshold: 4.5,
    ),
  ];

  final List<DocumentedExceptionPair> allowedExceptions = [
    DocumentedExceptionPair(
      name: 'white on emerald500 (#10B981) — light/dark',
      fg: 0xFFFFFFFF,
      bg: emerald500,
      currentRatio: 2.53,
    ),
    DocumentedExceptionPair(
      name: 'white on teal400 (#2DD4BF) — light/dark',
      fg: 0xFFFFFFFF,
      bg: teal400,
      currentRatio: 1.86,
    ),
    DocumentedExceptionPair(
      name: 'white on warning (#F59E0B) — light/dark',
      fg: 0xFFFFFFFF,
      bg: warning,
      currentRatio: 2.14,
    ),
    DocumentedExceptionPair(
      name: 'emerald500 on lightCard — light',
      fg: emerald500,
      bg: lightCard,
      currentRatio: 2.53,
    ),
    DocumentedExceptionPair(
      name: 'error on lightBackground — light',
      fg: error,
      bg: lightBackground,
      currentRatio: 3.76,
    ),
  ];

  bool hasErrors = false;

  print('Checking passing pairings against WCAG thresholds:');
  for (final pair in passingPairs) {
    final double ratio = contrastRatio(pair.fg, pair.bg);
    if (ratio >= pair.threshold) {
      print('  [PASS] ${pair.name}: ${ratio.toStringAsFixed(2)}:1 (threshold >= ${pair.threshold})');
    } else {
      print('  [FAIL] ${pair.name}: ${ratio.toStringAsFixed(2)}:1 below threshold of ${pair.threshold}!');
      hasErrors = true;
    }
  }

  print('\nVerifying allowed design exceptions remain within tolerance:');
  for (final exc in allowedExceptions) {
    final double ratio = contrastRatio(exc.fg, exc.bg);
    final double lowerBound = exc.currentRatio - 0.05;
    if (ratio >= lowerBound) {
      print('  [PASS] ${exc.name}: ${ratio.toStringAsFixed(2)}:1 within acceptable range (pinned ~${exc.currentRatio})');
    } else {
      print('  [FAIL] ${exc.name}: ${ratio.toStringAsFixed(2)}:1 has regressed below acceptable pinned floor of ${lowerBound.toStringAsFixed(2)}!');
      hasErrors = true;
    }
  }

  print('\n----------------------------------------------------------------------');
  if (hasErrors) {
    print('Audit Result: FAIL. Unauthorized contrast violations detected.');
    exit(1);
  } else {
    print('Audit Result: SUCCESS. All token pairing ratios conform.');
    exit(0);
  }
}

class TokenPair {
  final String name;
  final int fg;
  final int bg;
  final double threshold;

  const TokenPair({
    required this.name,
    required this.fg,
    required this.bg,
    required this.threshold,
  });
}

class DocumentedExceptionPair {
  final String name;
  final int fg;
  final int bg;
  final double currentRatio;

  const DocumentedExceptionPair({
    required this.name,
    required this.fg,
    required this.bg,
    required this.currentRatio,
  });
}
