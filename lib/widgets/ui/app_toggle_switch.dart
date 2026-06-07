import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '_focus_indicator.dart';

/// Token-driven toggle switch for the DriveCare+ Component_Library.
///
/// Renders a `50 x 30` logical-pixel rounded track with a circular thumb
/// that animates between the left and right edges when [value] flips.
/// While [value] is `true` the track is filled with the brand gradient
/// (`AppColors.emerald500 → AppColors.teal400`); while `false` the
/// track is filled with the muted border token so the off-state is
/// visually neutral.
///
/// The widget guarantees a `48 x 48` logical-pixel gesture region per the
/// `Touch_Target_Floor` from Requirement 3.10 / 13.3, even though the
/// visual track is smaller. When [onChanged] is `null` the switch is
/// disabled: gestures are detached and the track adopts the muted
/// surface treatment (Requirement 3.12).
///
/// Every visual constant — gradient stops, track radius, motion duration,
/// muted color — comes from the design-token extensions on
/// `Theme.of(context)`; no hex color, spacing, radius, typography, or
/// duration literals from the Token_Sets are inlined (Requirement 3.11).
///
/// The thumb transition uses `AppMotion.fast` (150 ms) which is the
/// dedicated short-duration token in the motion scale.
///
/// `semanticsLabel` is forwarded onto a `Semantics(toggled:, label:)`
/// node so assistive technology can announce the switch by name and
/// state (Requirement 13.8).
class AppToggleSwitch extends StatelessWidget {
  /// Current on/off state of the switch.
  final bool value;

  /// Called with the proposed new value when the user taps the switch.
  /// `null` → disabled state per Requirement 3.12.
  final ValueChanged<bool>? onChanged;

  /// Optional accessibility label used for the wrapping `Semantics`
  /// node. When `null`, an empty label is emitted.
  final String? semanticsLabel;

  const AppToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
  });

  // `Touch_Target_Floor` from Requirement 3.10 / 13.3. Held as a local
  // constant because it's an accessibility floor, not a layout token.
  static const double _minHitArea = 48.0;

  // Visual track dimensions for the switch. These are component-local
  // sizing constants (not part of the spacing token scale) and live
  // here so the contract is explicit at the call site.
  static const double _trackWidth = 50.0;
  static const double _trackHeight = 30.0;
  static const double _thumbDiameter = 24.0;
  static const double _thumbInset = 3.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppMotionExt motion = theme.extension<AppMotionExt>()!;

    final bool disabled = onChanged == null;

    final BorderRadius trackRadius =
        BorderRadius.circular(_trackHeight / 2);

    // Active vs inactive vs disabled track treatment.
    //   - active   → brand gradient
    //   - inactive → muted border surface
    //   - disabled → muted surface (Requirement 3.12)
    final Decoration trackDecoration;
    if (disabled) {
      trackDecoration = BoxDecoration(
        color: colors.muted,
        borderRadius: trackRadius,
      );
    } else if (value) {
      trackDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[colors.emerald500, colors.teal400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: trackRadius,
      );
    } else {
      trackDecoration = BoxDecoration(
        color: colors.border,
        borderRadius: trackRadius,
      );
    }

    final Widget track = AnimatedContainer(
      width: _trackWidth,
      height: _trackHeight,
      duration: motion.fast,
      curve: motion.standard,
      decoration: trackDecoration,
      padding: const EdgeInsets.all(_thumbInset),
      child: AnimatedAlign(
        duration: motion.fast,
        curve: motion.standard,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: _thumbDiameter,
          height: _thumbDiameter,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    final Widget hitArea = SizedBox(
      width: _minHitArea,
      height: _minHitArea,
      child: Center(child: track),
    );

    final Widget interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => onChanged!(!value),
      child: hitArea,
    );

    return Semantics(
      toggled: value,
      enabled: !disabled,
      label: semanticsLabel ?? '',
      child: AppFocusIndicator(
        enabled: !disabled,
        borderRadius: trackRadius,
        child: interactive,
      ),
    );
  }
}
