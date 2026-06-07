import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../widgets/ui/ui.dart';

/// My Bookings tab body for the redesigned `workshop_map_screen` (Task 9.13).
///
/// Renders one of two mutually-exclusive states based on [bookings]:
///
/// * non-empty → an [AppCard] per booking with `Reschedule` + `Cancel`
///   action buttons that delegate to [onReschedule] and [onCancel].
/// * empty → an [AppEmptyState] with a `Browse Workshops` CTA that
///   delegates to [onBrowse].
///
/// The `populated` and `empty` branches are wired to share a single
/// [Center] container so Property 15 (mutual exclusion) sees exactly one
/// of `[populated, empty]` rendered for any input list, including the
/// empty list (Task 9.14).
///
/// All visual constants come from the design-token extensions on
/// `Theme.of(context)`; no hex colors, spacing, radii, or typography
/// literals from the Token_Sets are inlined (Requirement 3.11).
class MyBookingsTab extends StatelessWidget {
  /// List of bookings to render, each as a `Map<String, dynamic>` matching
  /// the shape stored in `bookings/{id}` by `WorkshopFirebaseService`. The
  /// minimum keys consumed by this widget are `workshopName`,
  /// `serviceName`, `date`, `time`, and `status`.
  final List<Map<String, dynamic>> bookings;

  /// Reschedule handler. Receives the booking id (from the `id` key in the
  /// booking map). When `null`, the Reschedule button still renders but is
  /// disabled.
  final void Function(String bookingId)? onReschedule;

  /// Cancel handler. Receives the booking id. When `null`, the Cancel
  /// button still renders but is disabled.
  final void Function(String bookingId)? onCancel;

  /// Browse Workshops CTA tap handler used by the empty state. When
  /// `null`, the CTA still renders but is disabled.
  final VoidCallback? onBrowse;

  const MyBookingsTab({
    super.key,
    required this.bookings,
    this.onReschedule,
    this.onCancel,
    this.onBrowse,
  });

  /// `ValueKey` attached to the populated branch's outer scroll view. The
  /// Property 15 PBT in `test/screens/workshop_my_bookings_pbt_test.dart`
  /// uses this key to assert "exactly one of populated/empty" across any
  /// generated booking list.
  @visibleForTesting
  static const Key populatedKey = ValueKey<String>('my_bookings_populated');

  /// `ValueKey` attached to the empty branch's [AppEmptyState]. Paired
  /// with [populatedKey] for the Property 15 mutual-exclusion assertion.
  @visibleForTesting
  static const Key emptyKey = ValueKey<String>('my_bookings_empty');

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return AppEmptyState(
        key: emptyKey,
        icon: Icons.event_available_outlined,
        title: 'No bookings yet',
        message: 'Book a workshop visit to see it here.',
        action: AppGradientButton(
          label: 'Browse Workshops',
          onPressed: onBrowse,
          icon: Icons.search,
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return ListView.separated(
      key: populatedKey,
      padding: EdgeInsets.all(spacing.lg),
      itemCount: bookings.length,
      separatorBuilder: (BuildContext _, int _) =>
          SizedBox(height: spacing.md),
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> booking = bookings[index];
        final String id = booking['id']?.toString() ?? '';
        return _BookingCard(
          booking: booking,
          onReschedule: onReschedule == null || id.isEmpty
              ? null
              : () => onReschedule!(id),
          onCancel: onCancel == null || id.isEmpty
              ? null
              : () => onCancel!(id),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onReschedule,
    required this.onCancel,
  });

  final Map<String, dynamic> booking;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final String workshopName =
        (booking['workshopName'] ?? 'Workshop').toString();
    final String serviceName =
        (booking['serviceName'] ?? 'Service').toString();
    final String dateString = (booking['date'] ?? '').toString();
    final String timeString = (booking['time'] ?? '').toString();
    final String status = (booking['status'] ?? 'Pending').toString();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  workshopName,
                  style: typography.title.copyWith(color: colors.foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppBadge(
                text: status,
                kind: status.toLowerCase() == 'confirmed'
                    ? BadgeKind.success
                    : BadgeKind.info,
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            serviceName,
            style: typography.body.copyWith(color: colors.foreground),
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: <Widget>[
              Icon(
                Icons.calendar_today_outlined,
                size: typography.body.fontSize,
                color: colors.foreground
                    .withValues(alpha: colors.surfaceProminent),
              ),
              SizedBox(width: spacing.xs),
              Text(
                _formatDate(dateString),
                style: typography.body.copyWith(color: colors.foreground),
              ),
              SizedBox(width: spacing.lg),
              Icon(
                Icons.access_time,
                size: typography.body.fontSize,
                color: colors.foreground
                    .withValues(alpha: colors.surfaceProminent),
              ),
              SizedBox(width: spacing.xs),
              Text(
                timeString,
                style: typography.body.copyWith(color: colors.foreground),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AppSecondaryButton(
                  label: 'Reschedule',
                  onPressed: onReschedule,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppSecondaryButton(
                  label: 'Cancel',
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final DateTime? parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      return iso.isEmpty ? '—' : iso;
    }
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }
}
