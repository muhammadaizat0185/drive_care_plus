/// Shared model types used across the DriveCare+ Component_Library
/// (`lib/widgets/ui/`).
///
/// These types are the typed surface that component widgets accept as
/// inputs (instead of stringly-typed values) so that screens compose
/// against compile-time-checked enums and value classes.
///
/// Component-specific token mappings (e.g. `FeedbackKind` → semantic
/// color from `AppColors`) live inside the consuming widgets, not here.
///
/// Domain enums that are tied to a single screen flow (workshop
/// categories, fuel types, document categories) live with the screen
/// or service that owns them and are introduced in their respective
/// implementation tasks rather than here.
///
/// See: figma-ui-redesign Requirement 3.1.
library;

import 'package:flutter/widgets.dart';

/// Semantic kind of an `AppFeedbackBanner`.
///
/// Each value maps to a corresponding semantic color in the design
/// tokens (`success`, `error`, `warning`, `info`) and drives the
/// banner's background, border, and icon treatment.
///
/// See: figma-ui-redesign Requirement 3.7.
enum FeedbackKind { success, error, warning, info }

/// Visual kind of an `AppBadge`.
///
/// `neutral` uses the muted surface; `success`/`warning`/`error`/`info`
/// map to the matching semantic tokens; `brand` uses the gradient
/// brand fill.
enum BadgeKind { neutral, success, warning, error, info, brand }

/// A single entry in the `AppFloatingBottomNav` items list.
///
/// `icon` is rendered inside the pill; `label` is shown beneath the
/// icon when the item is active. Two `NavItem`s are equal iff their
/// `icon` and `label` match, which makes nav-item lists comparable
/// in tests without identity tracking.
///
/// See: figma-ui-redesign Requirement 3.8.
@immutable
class NavItem {
  final IconData icon;
  final String label;

  const NavItem({required this.icon, required this.label});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavItem && other.icon == icon && other.label == label;
  }

  @override
  int get hashCode => Object.hash(icon, label);
}
