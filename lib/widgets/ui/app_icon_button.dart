import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '_focus_indicator.dart';
import '_press_scale.dart';

/// Icon-only interactive control for the DriveCare+ Component_Library.
///
/// Renders [icon] at [size] and guarantees a tappable hit area of at least
/// 48x48 logical pixels regardless of the rendered icon's visual size, in
/// line with the `Touch_Target_Floor` from Requirements 3.10 and 13.3.
///
/// [semanticsLabel] is required and is exposed as a `Semantics.label` so
/// assistive technology can announce the control by name (Requirement 13.8).
///
/// Shares the press-scale animation contract with `AppPrimaryButton` (0.98x
/// ↔ 1.0x in 100 ms, within the 80–200 ms inclusive window from Requirement
/// 3.2) and the same disabled rules from Requirement 3.12: when
/// `onPressed == null`, the icon is rendered with the muted disabled
/// treatment and gestures are detached entirely.
///
/// Visual constants are read from the design-token extensions on
/// `Theme.of(context)`; no hex colors or token-equivalent literals are
/// inlined (Requirement 3.11).
class AppIconButton extends StatelessWidget {
  /// Icon to render at the centre of the hit area.
  final IconData icon;

  /// Tap callback. `null` → disabled state per Requirement 3.12.
  final VoidCallback? onPressed;

  /// Visual size of the icon glyph in logical pixels. The hit area is
  /// always ≥ 48x48 logical pixels regardless of this value.
  final double size;

  /// Required semantics label describing the control's action so assistive
  /// technology can announce it by name (Requirement 13.8). Must be
  /// non-empty.
  final String semanticsLabel;

  /// Optional explicit foreground color override. When `null`, the active
  /// state uses `AppColors.foreground` and the disabled state uses the
  /// muted-foreground treatment.
  final Color? color;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticsLabel,
    this.size = 24,
    this.color,
  }) : assert(
          semanticsLabel != '',
          'AppIconButton.semanticsLabel must be non-empty (Requirement 13.8).',
        );

  // `Touch_Target_Floor` from Requirement 3.10 / 13.3. Held as a local
  // constant because it's an accessibility floor, not a layout token.
  static const double _minHitArea = 48.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;

    final bool disabled = onPressed == null;

    final Color resolvedColor = disabled
        ? colors.foreground.withValues(alpha: colors.surfaceProminent)
        : (color ?? colors.foreground);

    final Widget visual = Container(
      width: _minHitArea,
      height: _minHitArea,
      alignment: Alignment.center,
      // The hit area is square at the floor regardless of icon size; the
      // icon itself stays at [size] visually.
      child: Icon(icon, size: size, color: resolvedColor),
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: semanticsLabel,
      child: AppFocusIndicator(
        enabled: !disabled,
        borderRadius: BorderRadius.circular(8.0),
        child: PressScale(
          enabled: !disabled,
          onTap: onPressed,
          child: visual,
        ),
      ),
    );
  }
}
