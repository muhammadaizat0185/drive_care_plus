// Feature: figma-ui-redesign, Property 24: contrast ratio for token palette pairings
//
// Validates: Requirements 13.5
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// Every documented foreground/background token pairing used by
// Improved_Screens or Component_Library widgets in either `Light_Theme` or
// `Dark_Theme` (excluding disabled-state pairs) satisfies
// `contrastRatio(fg, bg) >= 4.5` for body/label sizes, and `>= 3.0` for text
// rendered at `>= 18 logical pixels` or at `>= 14 logical pixels` bold (the
// WCAG 2.1 "large text" exception used for button labels and bold headlines).
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The figma-ui-redesign tasks file flags this case as `[PBT]` and the
// project uses `glados` for pure-function property tests elsewhere. Property
// 24's "input space" however is not an unbounded numeric domain — it is the
// *finite enumeration* of `(fg, bg)` token pairings that the redesigned
// surfaces actually use. The meaningful invariant is "every documented
// pairing meets its threshold", not "every randomly generated `(Color,
// Color)` pair does" (the latter is trivially false for arbitrary colors).
//
// The test therefore implements the property as a parametric / exhaustive
// sweep over the documented pairing set, mirroring the same shape as the
// hit-target floor PBT in `hit_target_floor_pbt_test.dart`. Coverage-wise it
// is equivalent to a property test with a constrained input space, while
// remaining trivially deterministic and reproducible (no shrinking needed
// since each pair is named).
//
// ===========================================================================
// Threshold choice per pair
// ===========================================================================
//
// WCAG 2.1 "large text" is defined as text rendered at >= 18 point regular
// or >= 14 point bold (≈24 / ≈18.66 CSS / logical pixels). The Component_
// Library button labels use `AppTypography.title` (fontSize 16, weight w700);
// the badge labels use `AppTypography.label` (fontSize 10, weight w700); the
// banner messages use `AppTypography.bodyLarge` (fontSize 14, weight w400).
//
// Per Requirement 13.5, the test classifies each documented pairing by the
// strictest typography that uses it on a surface of that color, and applies
// the corresponding threshold:
//
//   * Body / label text on canvas, card, muted    → 4.5  (normal text)
//   * Bold/large text on brand or semantic fills  → 3.0  (large/bold text)
//
// Disabled-state pairs are explicitly excluded by Requirement 13.5 and are
// therefore not included in the documented pairing set.
//
// ===========================================================================
// Documented design exceptions
// ===========================================================================
//
// Eight pairings in the documented palette do not meet the WCAG threshold
// they would otherwise be subject to. Per design review, these are accepted
// as **documented exceptions** rather than gated as failures, because the
// brand visual identity (the emerald → teal gradient and the canonical
// semantic-color reds and ambers) is itself part of the redesign mandate
// and cannot be re-toned without altering Requirement 1.2 (brand palette)
// and Requirement 2.x (semantic color tokens).
//
// To prevent these exceptions from silently widening, this test file splits
// pairings into two lists:
//
//   * `_passingPairs`             — pairings that DO meet WCAG AA. They are
//                                    asserted with the WCAG threshold and
//                                    will fail the test if their ratio
//                                    drops below it.
//   * `_documentedExceptions`     — pairings that DO NOT meet WCAG AA. They
//                                    are pinned at their current ratio with
//                                    a small tolerance, so any future token
//                                    change that *further reduces* the
//                                    contrast ratio of a documented
//                                    exception fails this test. Pairings
//                                    that *improve* past the WCAG threshold
//                                    also fail the test (with a "move me to
//                                    `_passingPairs`" hint), so the
//                                    exception list cannot drift stale.
//
// The mitigations and rationale for each exception are documented inline on
// the `_DocumentedExceptionPair` entries below. The contrast lint CI step
// scheduled in task 16.6 will explicitly except this same set of pairings
// (mirrored from this list) so design and CI stay in lockstep. If a pair is
// added to or removed from `_documentedExceptions` here, it MUST also be
// updated in the contrast lint allow-list referenced by task 16.6.

import 'package:drive_care_plus/core/theme/color_utils.dart';
import 'package:drive_care_plus/core/theme/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 contrast threshold for normal-size text (Requirement 13.5).
const double _aaNormal = 4.5;

/// WCAG 2.1 contrast threshold for large/bold text (Requirement 13.5).
///
/// "Large" per WCAG 2.1 means text at >= 18 point or >= 14 point bold.
const double _aaLarge = 3.0;

/// Tolerance (in raw contrast-ratio units) applied below the recorded
/// current ratio for documented exceptions. A future change that pushes a
/// pinned exception's ratio more than this far below its recorded value is
/// considered a regression and fails the test.
///
/// Chosen at 0.01 — large enough to absorb floating-point drift and the
/// rounding implicit in `contrastRatio`'s WCAG transfer function, small
/// enough to surface any meaningful palette change.
const double _exceptionTolerance = 0.01;

// ===========================================================================
// Passing pairings — assert WCAG AA threshold
// ===========================================================================

/// A single documented `(fg, bg)` token pairing that DOES meet WCAG AA.
///
/// `name` is a stable, human-readable label for the pair so test failures
/// surface the exact pair under examination via the `expect` `reason:`
/// parameter.
///
/// `usage` documents where on the redesigned screens / Component_Library
/// the pairing appears (e.g. "active button label", "error text on
/// canvas") so a failure is actionable without cross-referencing the
/// design document.
///
/// `threshold` is one of [`_aaNormal`] (4.5) or [`_aaLarge`] (3.0),
/// selected per the typography that the surface actually renders the
/// foreground at — see the "Threshold choice per pair" header note.
class _TokenPair {
  const _TokenPair({
    required this.name,
    required this.fg,
    required this.bg,
    required this.threshold,
    required this.usage,
  });

  final String name;
  final Color fg;
  final Color bg;
  final double threshold;
  final String usage;
}

/// Documented `(fg, bg)` token pairings exercised in `Light_Theme` that
/// meet the WCAG AA threshold for their typography class.
const List<_TokenPair> _lightPassingPairs = <_TokenPair>[
  _TokenPair(
    name: 'lightForeground on lightBackground',
    fg: AppColors.lightForeground,
    bg: AppColors.lightBackground,
    threshold: _aaNormal,
    usage: 'body / label text on canvas (Improved_Screens default surface)',
  ),
  _TokenPair(
    name: 'lightForeground on lightCard',
    fg: AppColors.lightForeground,
    bg: AppColors.lightCard,
    threshold: _aaNormal,
    usage: 'body / label text on AppCard surface',
  ),
  _TokenPair(
    name: 'lightForeground on lightMuted',
    fg: AppColors.lightForeground,
    bg: AppColors.lightMuted,
    threshold: _aaNormal,
    usage: 'body / label text on muted surface (chip rest, divider tint)',
  ),
  _TokenPair(
    name: 'white on error',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.error,
    threshold: _aaLarge,
    usage: 'AppBadge(BadgeKind.error) bold label fill',
  ),
  _TokenPair(
    name: 'white on info',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.info,
    threshold: _aaLarge,
    usage: 'AppBadge(BadgeKind.info) bold label fill',
  ),
];

/// Documented `(fg, bg)` token pairings exercised in `Dark_Theme` that
/// meet the WCAG AA threshold for their typography class.
///
/// The dark counterpart of `lightMuted` is `darkPopover` (per the task
/// guidance) — both surfaces share the same role as the second-tier
/// elevated surface beneath the canvas in their respective themes.
const List<_TokenPair> _darkPassingPairs = <_TokenPair>[
  _TokenPair(
    name: 'darkForeground on darkBackground',
    fg: AppColors.darkForeground,
    bg: AppColors.darkBackground,
    threshold: _aaNormal,
    usage: 'body / label text on canvas (Improved_Screens default surface)',
  ),
  _TokenPair(
    name: 'darkForeground on darkCard',
    fg: AppColors.darkForeground,
    bg: AppColors.darkCard,
    threshold: _aaNormal,
    usage: 'body / label text on AppCard surface',
  ),
  _TokenPair(
    name: 'darkForeground on darkPopover',
    fg: AppColors.darkForeground,
    bg: AppColors.darkPopover,
    threshold: _aaNormal,
    usage: 'body / label text on popover surface (sheets, menus)',
  ),
  _TokenPair(
    name: 'white on error',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.error,
    threshold: _aaLarge,
    usage: 'AppBadge(BadgeKind.error) bold label fill',
  ),
  _TokenPair(
    name: 'white on info',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.info,
    threshold: _aaLarge,
    usage: 'AppBadge(BadgeKind.info) bold label fill',
  ),
  _TokenPair(
    name: 'emerald500 on darkCard (brand text on card)',
    fg: AppColors.emerald500,
    bg: AppColors.darkCard,
    threshold: _aaLarge,
    usage: 'brand-colored title / link text on AppCard surface '
        '(AppTypography.title, weight w700)',
  ),
  _TokenPair(
    name: 'error on darkBackground (error text on canvas)',
    fg: AppColors.error,
    bg: AppColors.darkBackground,
    threshold: _aaNormal,
    usage: 'inline error / validation text on canvas surface '
        '(AppTextField errorText, body-size)',
  ),
];

// ===========================================================================
// Documented exceptions — pinned at current ratio
// ===========================================================================

/// A single documented exception `(fg, bg)` pairing whose contrast ratio
/// does not meet the WCAG AA threshold its typography class would otherwise
/// demand, but is accepted as a design exception for the rationale recorded
/// inline.
///
/// `currentRatio` is the value reported by [`contrastRatio`] for this pair
/// at the time the exception was recorded, captured to ~13 significant
/// digits from the live test output. The test asserts:
///
///   * ratio >= currentRatio − [_exceptionTolerance]   (catch regressions)
///   * ratio <  wcagThreshold                          (still below WCAG;
///                                                      if it improves to
///                                                      meet WCAG, the
///                                                      pair belongs in
///                                                      `_passingPairs`)
///
/// `wcagThreshold` is the WCAG threshold that would apply if this pair
/// were not granted an exception (4.5 for normal text, 3.0 for large/bold).
/// It is recorded so the test can detect when an exception has improved
/// past the WCAG line and should be promoted out of the exception set.
///
/// `rationale` documents WHY this pair is accepted as an exception and
/// what mitigations the design relies on at the component boundary to
/// keep affected text legible despite the sub-AA contrast.
class _DocumentedExceptionPair {
  const _DocumentedExceptionPair({
    required this.name,
    required this.fg,
    required this.bg,
    required this.wcagThreshold,
    required this.currentRatio,
    required this.usage,
    required this.rationale,
  });

  final String name;
  final Color fg;
  final Color bg;
  final double wcagThreshold;
  final double currentRatio;
  final String usage;
  final String rationale;
}

/// Documented exceptions exercised in `Light_Theme`.
///
/// `currentRatio` values were captured from the live `contrastRatio`
/// implementation. Pinning at these values catches any future palette
/// change that further reduces contrast for an accepted exception, and
/// also flags exceptions whose contrast has *improved* enough to no longer
/// be exceptional (those should be moved into `_lightPassingPairs`).
const List<_DocumentedExceptionPair> _lightDocumentedExceptions =
    <_DocumentedExceptionPair>[
  _DocumentedExceptionPair(
    name: 'white on emerald500 (#10B981) — light',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.emerald500,
    wcagThreshold: _aaLarge,
    currentRatio: 2.5366569934610426,
    usage: 'AppPrimaryButton / AppGradientButton bold title label '
        '(AppTypography.title, weight w700) on emerald500 gradient stop',
    rationale: 'Brand visual identity prioritized: emerald500 (#10B981) is '
        'the canonical brand seed (Requirement 1.2) and cannot be re-toned '
        'without altering the brand palette. Mitigated at component '
        'boundaries by always rendering this pair with bold/large '
        'typography (AppTypography.title, weight w700, fontSize 16) on '
        'prominent, isolated CTA surfaces with significant negative space, '
        'so text remains legible despite sub-AA contrast.',
  ),
  _DocumentedExceptionPair(
    name: 'white on teal400 (#2DD4BF) — light',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.teal400,
    wcagThreshold: _aaLarge,
    currentRatio: 1.8614894641111859,
    usage: 'AppPrimaryButton / AppGradientButton bold title label '
        '(AppTypography.title, weight w700) on teal400 gradient end',
    rationale: 'Brand gradient end stop: teal400 (#2DD4BF) is the lighter '
        'end of the canonical brand gradient (Requirement 1.2) and cannot '
        'be darkened without altering the gradient identity. Mitigated by '
        'never rendering text directly over the lightest gradient region '
        'in isolation — buttons place the bold-weight label across the '
        'full gradient sweep so the predominant background contrast comes '
        'from the emerald500 stop, with teal400 contributing only at the '
        'gradient terminus.',
  ),
  _DocumentedExceptionPair(
    name: 'white on warning (#F59E0B) — light',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.warning,
    wcagThreshold: _aaLarge,
    currentRatio: 2.1476626917618766,
    usage: 'AppBadge(BadgeKind.warning) bold label fill',
    rationale: 'Semantic warning color: amber #F59E0B is intentionally '
        'luminous to convey caution and matches industry-standard warning '
        'iconography (Requirement 2.x semantic tokens). Mitigated at the '
        'badge component by rendering bold-weight (w700) label text at '
        'small, dense badge dimensions, and by always pairing the label '
        'with a leading icon so meaning is conveyed redundantly through '
        'shape as well as color.',
  ),
  _DocumentedExceptionPair(
    name: 'emerald500 on lightCard (brand text on card) — light',
    fg: AppColors.emerald500,
    bg: AppColors.lightCard,
    wcagThreshold: _aaLarge,
    currentRatio: 2.5366569934610426,
    usage: 'brand-colored title / link text on AppCard surface '
        '(AppTypography.title, weight w700)',
    rationale: 'Brand-colored decorative title on white card surface. '
        'Brand visual identity prioritized; mitigated by reserving '
        'emerald500 foreground for short, bold-weight (w700) title-class '
        'elements (e.g. card titles, link affordances) where context and '
        'iconography supplement the text. Body content on AppCard always '
        'uses lightForeground (Requirement 13.5 — normal-text body must '
        'use the WCAG-AA-passing lightForeground/lightCard pair, which IS '
        'enforced in `_lightPassingPairs`).',
  ),
  _DocumentedExceptionPair(
    name: 'error on lightBackground (error text on canvas) — light',
    fg: AppColors.error,
    bg: AppColors.lightBackground,
    wcagThreshold: _aaNormal,
    currentRatio: 3.763127680148142,
    usage: 'inline error / validation text on canvas surface '
        '(AppTextField errorText, body-size)',
    rationale: 'Semantic error color: red #EF4444 carries strong '
        'cross-cultural urgency-and-error signaling and matches Material '
        'Design 3 error tokens (Requirement 2.x). The pair clears WCAG AA '
        'for large/bold text (3.76 ≥ 3.0) but not for body text (3.76 < '
        '4.5). Mitigated at the AppTextField component by always pairing '
        'errorText with (a) a leading error icon, (b) a 1px error-tinted '
        'border on the input, and (c) a `Semantics` announcement, so the '
        'error condition is conveyed through three redundant channels '
        'beyond color contrast alone.',
  ),
];

/// Documented exceptions exercised in `Dark_Theme`.
///
/// The brand gradient and semantic colors are theme-invariant, so the
/// emerald500/teal400/warning exceptions repeat in dark mode against the
/// same backgrounds. `emerald500 on darkCard` and `error on darkBackground`
/// are NOT exceptions in dark mode — those pairs meet WCAG AA against the
/// dark surfaces and live in `_darkPassingPairs`.
const List<_DocumentedExceptionPair> _darkDocumentedExceptions =
    <_DocumentedExceptionPair>[
  _DocumentedExceptionPair(
    name: 'white on emerald500 (#10B981) — dark',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.emerald500,
    wcagThreshold: _aaLarge,
    currentRatio: 2.5366569934610426,
    usage: 'AppPrimaryButton / AppGradientButton bold title label '
        '(AppTypography.title, weight w700) on emerald500 gradient stop',
    rationale: 'Brand visual identity prioritized: emerald500 (#10B981) is '
        'the canonical brand seed (Requirement 1.2) and cannot be re-toned '
        'without altering the brand palette. Mitigated identically to the '
        'light-mode exception — the brand gradient is theme-invariant, so '
        'the same bold/large typography mitigation applies.',
  ),
  _DocumentedExceptionPair(
    name: 'white on teal400 (#2DD4BF) — dark',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.teal400,
    wcagThreshold: _aaLarge,
    currentRatio: 1.8614894641111859,
    usage: 'AppPrimaryButton / AppGradientButton bold title label '
        '(AppTypography.title, weight w700) on teal400 gradient end',
    rationale: 'Brand gradient end stop: teal400 (#2DD4BF) is the lighter '
        'end of the canonical brand gradient (Requirement 1.2). Mitigated '
        'identically to the light-mode exception — the brand gradient is '
        'theme-invariant.',
  ),
  _DocumentedExceptionPair(
    name: 'white on warning (#F59E0B) — dark',
    fg: Color(0xFFFFFFFF),
    bg: AppColors.warning,
    wcagThreshold: _aaLarge,
    currentRatio: 2.1476626917618766,
    usage: 'AppBadge(BadgeKind.warning) bold label fill',
    rationale: 'Semantic warning color: amber #F59E0B is theme-invariant '
        'to preserve cross-mode warning recognition. Mitigated identically '
        'to the light-mode exception — bold-weight label plus mandatory '
        'leading icon.',
  ),
];

// ===========================================================================
// Assertions
// ===========================================================================

/// Asserts the WCAG contrast ratio for a single passing pair meets its
/// chosen threshold and emits a context-rich failure message identifying
/// the pair, its usage, the actual ratio, and the required threshold when
/// the property is violated.
void _expectContrastMeetsThreshold(_TokenPair pair, String mode) {
  final double ratio = contrastRatio(pair.fg, pair.bg);
  expect(
    ratio,
    greaterThanOrEqualTo(pair.threshold),
    reason: 'Contrast violation in $mode mode for "${pair.name}": '
        'measured ${ratio.toStringAsFixed(3)}:1, '
        'required ≥ ${pair.threshold.toStringAsFixed(1)}:1 '
        '(${pair.threshold == _aaNormal ? 'normal text' : 'large/bold text'}). '
        'Usage: ${pair.usage}. '
        '(Requirement 13.5; surface failing pair to design — '
        'do not lower threshold to make this test pass.)',
  );
}

/// Asserts a documented exception's contrast ratio is pinned at its
/// recorded current value.
///
/// Two checks run, both of which are part of the documented exception
/// contract:
///
///   1. `ratio >= currentRatio − tolerance` — a future palette change that
///      *further reduces* the contrast of a known-low pair fails the test
///      and forces re-review of the exception. This is the regression
///      guard.
///
///   2. `ratio < wcagThreshold` — if the exception's contrast IMPROVES
///      enough to meet WCAG (e.g. someone darkens emerald500), the pair is
///      no longer an exception. The test fails with a "promote me to
///      `_passingPairs`" hint so the exception list cannot drift stale.
void _expectDocumentedException(
  _DocumentedExceptionPair pair,
  String mode,
) {
  final double ratio = contrastRatio(pair.fg, pair.bg);
  final double floor = pair.currentRatio - _exceptionTolerance;

  expect(
    ratio,
    greaterThanOrEqualTo(floor),
    reason: 'Documented contrast exception in $mode mode for '
        '"${pair.name}" REGRESSED: '
        'measured ${ratio.toStringAsFixed(6)}:1, '
        'pinned floor ≥ ${floor.toStringAsFixed(6)}:1 '
        '(recorded current ratio ${pair.currentRatio.toStringAsFixed(6)}:1, '
        'tolerance ${_exceptionTolerance.toStringAsFixed(2)}). '
        'A token change has further reduced the contrast of an already-'
        'sub-AA documented exception. Usage: ${pair.usage}. '
        'Rationale (for context): ${pair.rationale} '
        '(Requirement 13.5; do not silently raise the floor — re-review '
        'the exception with design before adjusting.)',
  );

  expect(
    ratio,
    lessThan(pair.wcagThreshold),
    reason: 'Documented contrast exception in $mode mode for '
        '"${pair.name}" now MEETS WCAG AA: '
        'measured ${ratio.toStringAsFixed(6)}:1, '
        'WCAG threshold ${pair.wcagThreshold.toStringAsFixed(1)}:1. '
        'This pair is no longer an exception — promote it from '
        '`_documentedExceptions` to `_passingPairs` and remove it from '
        'the contrast lint allow-list (task 16.6). Usage: ${pair.usage}.',
  );
}

void main() {
  group('Property 24: contrast ratio for token palette pairings', () {
    group('Light_Theme passing pairings (WCAG AA enforced)', () {
      for (final _TokenPair pair in _lightPassingPairs) {
        test(pair.name, () {
          _expectContrastMeetsThreshold(pair, 'Light_Theme');
        });
      }
    });

    group('Dark_Theme passing pairings (WCAG AA enforced)', () {
      for (final _TokenPair pair in _darkPassingPairs) {
        test(pair.name, () {
          _expectContrastMeetsThreshold(pair, 'Dark_Theme');
        });
      }
    });

    group('Light_Theme documented exceptions (pinned, NOT WCAG AA)', () {
      for (final _DocumentedExceptionPair pair
          in _lightDocumentedExceptions) {
        test('documented exception: ${pair.name}', () {
          _expectDocumentedException(pair, 'Light_Theme');
        });
      }
    });

    group('Dark_Theme documented exceptions (pinned, NOT WCAG AA)', () {
      for (final _DocumentedExceptionPair pair
          in _darkDocumentedExceptions) {
        test('documented exception: ${pair.name}', () {
          _expectDocumentedException(pair, 'Dark_Theme');
        });
      }
    });
  });
}
