import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import 'types.dart';

/// Floating bottom navigation pill for the DriveCare+ Component_Library.
///
/// Renders a translucent floating pill that floats above the screen content
/// with a `BackdropFilter` blur of sigma `12` on both axes (within the
/// 10–20 inclusive window required by Requirement 3.8). The pill hosts
/// 3–5 navigation items inclusive — the constructor asserts this so any
/// out-of-range list fails fast at debug time rather than rendering an
/// undersized or overcrowded nav.
///
/// Each item occupies an equal share of the pill's content width via
/// `Expanded(flex: 1)` so adding or removing items rebalances the row
/// without per-item width math (Requirement 3.8). The active item — the
/// entry whose index equals [currentIndex] — is filled with the brand
/// gradient (`AppColors.emerald500 → AppColors.teal400`) and renders its
/// icon and label in white. Inactive items are rendered on a transparent
/// background with the muted-foreground treatment (the foreground token
/// softened via the `surfaceProminent` overlay so they recede from the
/// active entry while remaining legible).
///
/// Every item is wrapped in a [GestureDetector] sized to at least
/// 48x48 logical pixels, matching the `Touch_Target_Floor` from
/// Requirements 3.10 / 13.3 even when the visual content is smaller.
/// Tapping an item invokes [onTap] with the item's index; the widget
/// itself is stateless and the consumer is responsible for rebuilding
/// with an updated [currentIndex].
///
/// Visual constants — corner radius, padding, gradient stops, surface
/// opacity, typography, motion — flow from the design-token extensions on
/// `Theme.of(context)`; no hex colors, spacing, radii, typography, or
/// duration literals from the Token_Sets are inlined (Requirement 3.11).
///
/// Example:
/// ```dart
/// AppFloatingBottomNav(
///   items: const <NavItem>[
///     NavItem(icon: Icons.dashboard,    label: 'Cockpit'),
///     NavItem(icon: Icons.store,        label: 'Shops'),
///     NavItem(icon: Icons.directions_car, label: 'My Car'),
///     NavItem(icon: Icons.local_gas_station, label: 'Refuel'),
///     NavItem(icon: Icons.account_balance_wallet, label: 'Wallet'),
///   ],
///   currentIndex: 0,
///   onTap: (i) => setState(() => _activeTab = i),
/// );
/// ```
class AppFloatingBottomNav extends StatelessWidget {
  /// Navigation entries rendered left-to-right inside the pill.
  ///
  /// Asserted to contain between 3 and 5 entries inclusive (Requirement 3.8).
  final List<NavItem> items;

  /// Index of the currently active item. Asserted to be a valid index into
  /// [items].
  final int currentIndex;

  /// Tap callback invoked with the index of the tapped item. Re-tapping
  /// the active item also fires; consumers may filter for `i != currentIndex`
  /// if they want a single-shot navigation contract.
  final ValueChanged<int> onTap;

  const AppFloatingBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  })  : assert(
          items.length >= 3 && items.length <= 5,
          'AppFloatingBottomNav supports 3 to 5 items inclusive '
          '(Requirement 3.8); received items list out of range.',
        ),
        assert(
          currentIndex >= 0 && currentIndex < items.length,
          'AppFloatingBottomNav.currentIndex must be a valid index into items.',
        );

  // Backdrop blur sigma — the canonical mid-point of the 10–20 inclusive
  // window required by Requirement 3.8. Held as a private constant rather
  // than a token because there is no blur-sigma token in the Token_Sets
  // and Requirement 3.11's literal-free rule covers token-equivalent
  // values only.
  static const double _backdropSigma = 12.0;

  // `Touch_Target_Floor` from Requirements 3.10 / 13.3.
  static const double _minHitArea = 48.0;

  // 1-logical-pixel border width matches the convention shared with
  // `AppCard` and `AppFeedbackBanner`. There is no border-width token in
  // the Token_Sets, so encoding it as a private constant here does not
  // violate Requirement 3.11.
  static const double _borderWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppShadowsExt shadows = theme.extension<AppShadowsExt>()!;

    final BorderRadius pillRadius = BorderRadius.circular(radii.xLarge);

    // Translucent pill surface: the card color softened via the
    // `surfaceMedium` overlay (0.12 alpha) so the backdrop blur reads
    // through. Border is the standard token border at full saturation
    // for a crisp surface edge.
    final Color pillSurface =
        colors.card.withValues(alpha: colors.surfaceMedium);

    return ClipRRect(
      borderRadius: pillRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: _backdropSigma,
          sigmaY: _backdropSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: pillSurface,
            borderRadius: pillRadius,
            border: Border.all(color: colors.border, width: _borderWidth),
            boxShadow: shadows.medium,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    flex: 1,
                    child: _NavItemButton(
                      item: items[i],
                      active: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal button rendering a single [NavItem] inside an
/// [AppFloatingBottomNav].
///
/// When [active] is `true`, the button is filled with the brand gradient
/// (`emerald500 → teal400`) and renders its icon and label in white. When
/// `false`, the button is transparent with a muted-foreground icon and
/// label, matching the inactive treatment described in Requirement 3.8.
///
/// The gesture region is sized to at least 48x48 logical pixels via a
/// [ConstrainedBox] floor so every item meets the `Touch_Target_Floor`
/// from Requirements 3.10 / 13.3 regardless of pill width.
class _NavItemButton extends StatelessWidget {
  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavItemButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final BorderRadius itemRadius = BorderRadius.circular(radii.large);

    // Active state: brand gradient pill, white foreground.
    // Inactive state: transparent, muted foreground (foreground softened
    // via `surfaceProminent` to match the muted-foreground language used
    // by `AppSectionHeader` and the disabled-button treatment).
    final Decoration itemDecoration = active
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[colors.emerald500, colors.teal400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: itemRadius,
          )
        : BoxDecoration(
            color: Colors.transparent,
            borderRadius: itemRadius,
          );

    final Color foreground = active
        ? Colors.white
        : colors.foreground.withValues(alpha: colors.surfaceProminent);

    final TextStyle labelStyle =
        typography.label.copyWith(color: foreground);

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppFloatingBottomNav._minHitArea,
            minWidth: AppFloatingBottomNav._minHitArea,
          ),
          child: Container(
            decoration: itemDecoration,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.sm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  item.icon,
                  color: foreground,
                  size: typography.title.fontSize,
                ),
                SizedBox(height: spacing.xs),
                Text(
                  item.label,
                  style: labelStyle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
