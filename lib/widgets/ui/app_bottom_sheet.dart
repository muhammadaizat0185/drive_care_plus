import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Token-driven modal bottom sheet helper for the DriveCare+
/// Component_Library.
///
/// `AppBottomSheet.show<T>(context, builder: ...)` wraps Flutter's
/// `showModalBottomSheet` with the DriveCare+ design tokens applied:
///
///   * Top-rounded corners using `AppRadii.large` so the sheet visually
///     matches `AppCard` and the workshop/vault detail sheets
///     (Requirement 3.9).
///   * Drag handle rendered above the sheet body. The handle is already
///     enabled at the app theme level via
///     `BottomSheetThemeData.showDragHandle = true`; this helper passes
///     `showDragHandle: true` explicitly so the contract holds even if a
///     consumer mounts the sheet against a `Theme` without the DriveCare+
///     bottom-sheet theme.
///   * Card-token surface so the sheet honours light/dark neutrals without
///     hard-coded literals (Requirement 3.11).
///   * `useSafeArea: true` and `isScrollControlled: true` so tall content
///     can opt into a larger fraction of the viewport via
///     [initialHeightFraction] without clipping under system insets.
///
/// ### Animation duration
///
/// Requirement 3.9 specifies an inclusive window of 200–350 milliseconds.
/// Flutter's stock `showModalBottomSheet` enter animation runs at ~250ms,
/// which sits inside that window. Setting an exact 280ms target would
/// require constructing a `TickerProvider`-backed `AnimationController` and
/// passing it through `transitionAnimationController` — at the cost of a
/// stateful wrapper purely to host the vsync. The default duration keeps
/// this helper a one-line static call while remaining spec-compliant. If
/// the duration is ever tightened below 250ms, this helper will need a
/// stateful adapter to provide a custom controller; documenting the
/// trade-off here so the future change is intentional.
///
/// ### Body layout
///
/// The result of [builder] is wrapped in:
///
///   * a `SizedBox` whose `height` equals
///     `MediaQuery.of(sheetContext).size.height * initialHeightFraction`,
///     giving the sheet a deterministic initial height proportional to the
///     viewport;
///   * a `Padding` of `AppSpacing.lg` on all sides so consumers can pass
///     raw layout (e.g. `Column`) without re-deriving the sheet's inset.
///
/// Consumers that need fully resizable sheets (e.g. document vault add
/// flows) can return a `DraggableScrollableSheet` directly from [builder]
/// and ignore the [initialHeightFraction] sizing.
///
/// ### Example
///
/// ```dart
/// final result = await AppBottomSheet.show<bool>(
///   context,
///   initialHeightFraction: 0.4,
///   builder: (context) => Column(
///     mainAxisSize: MainAxisSize.min,
///     children: <Widget>[
///       const Text('Sign out of DriveCare+?'),
///       AppPrimaryButton(
///         label: 'Sign out',
///         onPressed: () => Navigator.of(context).pop(true),
///       ),
///       AppSecondaryButton(
///         label: 'Cancel',
///         onPressed: () => Navigator.of(context).pop(false),
///       ),
///     ],
///   ),
/// );
/// ```
class AppBottomSheet {
  const AppBottomSheet._();

  // Touch_Target_Floor parity for the drag handle's gesture region is
  // delegated to the Flutter framework, which already pads the handle to
  // the standard 48-logical-pixel hit area.

  /// Presents an `AppBottomSheet` and resolves with the value passed to
  /// `Navigator.of(sheetContext).pop(value)` from inside [builder], or
  /// `null` if the sheet is dismissed by drag/scrim tap.
  ///
  /// - [context] must be able to look up the DriveCare+ theme extensions
  ///   (`AppColorsExt`, `AppRadiiExt`, `AppSpacingExt`).
  /// - [builder] receives the sheet's own `BuildContext` and is responsible
  ///   for the visible body. Returning a `Form`, `Column`, or
  ///   `DraggableScrollableSheet` are all valid.
  /// - [initialHeightFraction] selects the sheet's initial height as a
  ///   fraction of the viewport. Asserted to lie in `(0.0, 1.0]`. Default
  ///   `0.5` matches the design contract.
  /// - [isDismissible] mirrors `showModalBottomSheet.isDismissible` and
  ///   simultaneously gates `enableDrag`: when `false`, neither scrim taps
  ///   nor a downward drag can dismiss the sheet, so the consumer is
  ///   responsible for popping it programmatically.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    double initialHeightFraction = 0.5,
    bool isDismissible = true,
  }) {
    assert(
      initialHeightFraction > 0.0 && initialHeightFraction <= 1.0,
      'AppBottomSheet.initialHeightFraction must be in (0.0, 1.0]; '
      'received $initialHeightFraction.',
    );

    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.card,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radii.large),
          topRight: Radius.circular(radii.large),
        ),
      ),
      builder: (BuildContext sheetContext) {
        final double keyboardHeight =
            MediaQuery.of(sheetContext).viewInsets.bottom;
        final double viewportHeight =
            MediaQuery.of(sheetContext).size.height;
        final double targetHeight = viewportHeight * initialHeightFraction;
        final double maxAvailableHeight = viewportHeight - keyboardHeight;
        final double sheetHeight =
            targetHeight > maxAvailableHeight ? maxAvailableHeight : targetHeight;

        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: SizedBox(
            height: sheetHeight,
            child: Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: builder(sheetContext),
            ),
          ),
        );
      },
    );
  }
}
