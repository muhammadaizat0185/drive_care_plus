import 'package:flutter/material.dart';

/// Internal hit-target floor wrapper used across the DriveCare+
/// Component_Library.
///
/// Pads the gesture region of [child] to at least `48 x 48` logical pixels
/// — the `Touch_Target_Floor` from Requirements 3.10 and 13.3 of the
/// figma-ui-redesign spec — even when the visual content is smaller. The
/// child is centered within the floored region, so callers can pair small
/// glyphs (e.g. a 24-logical-pixel icon) with a tappable area large enough
/// to satisfy the accessibility contract without re-deriving the floor at
/// each call site.
///
/// This widget is library-private (leading underscore in the filename)
/// and is **not** exported from `ui.dart`. Component_Library widgets pull
/// it in directly via a relative import.
///
/// ### Usage
///
/// Most existing Component_Library widgets (`AppPrimaryButton`,
/// `AppIconButton`, `AppToggleSwitch`, `AppCategoryChip`,
/// `AppFloatingBottomNav`, `AppCard.onTap`, `AppListTile.onTap`, ...)
/// already enforce the floor inline via `BoxConstraints(minHeight: 48)` or
/// `SizedBox(width: 48, height: 48)`. This wrapper exists so any future
/// interactive widget can opt in with a single line:
///
/// ```dart
/// return HitTargetFloor(
///   child: GestureDetector(
///     onTap: onTap,
///     child: visualContent, // may be smaller than 48 x 48
///   ),
/// );
/// ```
///
/// The wrapper does not attach gestures or semantics of its own — it
/// only enforces the spatial floor. Consumers remain responsible for
/// `GestureDetector`, `Semantics`, and any disabled-state handling.
class HitTargetFloor extends StatelessWidget {
  /// Visible content. Will be centered inside the `48 x 48` (or larger)
  /// floored region so a smaller visual still occupies a touch-friendly
  /// hit area.
  final Widget child;

  /// `Touch_Target_Floor` from Requirements 3.10 / 13.3 in logical pixels.
  /// Held as a public constant so widget tests can reference the same
  /// floor the runtime enforces, keeping the contract symmetric.
  static const double minSize = 48.0;

  const HitTargetFloor({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: child,
      ),
    );
  }
}
