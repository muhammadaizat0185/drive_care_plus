import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../widgets/ui/ui.dart';

class BookingHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final void Function(Map<String, dynamic> booking)? onTap;
  final void Function(String bookingId)? onConfirmFinished;
  final void Function(String bookingId)? onConfirmCancelled;
  final void Function(Map<String, dynamic> booking)? onReschedule;

  const BookingHistoryTab({
    super.key,
    required this.bookings,
    this.onTap,
    this.onConfirmFinished,
    this.onConfirmCancelled,
    this.onReschedule,
  });

  @visibleForTesting
  static const Key populatedKey = ValueKey<String>('booking_history_populated');

  @visibleForTesting
  static const Key emptyKey = ValueKey<String>('booking_history_empty');

  bool _isPastBooking(Map<String, dynamic> booking) {
    final dateStr = booking['date']?.toString() ?? '';
    if (dateStr.isEmpty) return false;
    final parsedDate = DateTime.tryParse(dateStr);
    if (parsedDate == null) return false;

    final today = DateTime.now();
    final bookingDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    return bookingDate.isBefore(todayDate);
  }

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return AppEmptyState(
        key: emptyKey,
        icon: Icons.history_outlined,
        title: 'No past bookings',
        message: 'Your completed or cancelled bookings will appear here.',
      );
    }

    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return ListView.separated(
      key: populatedKey,
      padding: EdgeInsets.all(spacing.lg),
      itemCount: bookings.length,
      separatorBuilder: (BuildContext _, int _) => SizedBox(height: spacing.md),
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> booking = bookings[index];
        final String id = booking['id']?.toString() ?? '';
        final String status = booking['status']?.toString() ?? 'Pending';
        final bool isPast = _isPastBooking(booking);
        final bool isPendingOrConfirmed = status.toLowerCase() == 'pending' || status.toLowerCase() == 'confirmed';
        final bool isPendingConfirmation = isPast && isPendingOrConfirmed;

        return _HistoryBookingCard(
          booking: booking,
          isPendingConfirmation: isPendingConfirmation,
          onTap: onTap == null ? null : () => onTap!(booking),
          onConfirmFinished: onConfirmFinished == null || id.isEmpty
              ? null
              : () => onConfirmFinished!(id),
          onConfirmCancelled: onConfirmCancelled == null || id.isEmpty
              ? null
              : () => onConfirmCancelled!(id),
          onReschedule: onReschedule == null
              ? null
              : () => onReschedule!(booking),
        );
      },
    );
  }
}

class _HistoryBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isPendingConfirmation;
  final VoidCallback? onTap;
  final VoidCallback? onConfirmFinished;
  final VoidCallback? onConfirmCancelled;
  final VoidCallback? onReschedule;

  const _HistoryBookingCard({
    required this.booking,
    required this.isPendingConfirmation,
    required this.onTap,
    required this.onConfirmFinished,
    required this.onConfirmCancelled,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final String workshopName = (booking['workshopName'] ?? 'Workshop').toString();
    final String serviceName = (booking['serviceName'] ?? 'Service').toString();
    final String dateString = (booking['date'] ?? '').toString();
    final String timeString = (booking['time'] ?? '').toString();
    final String status = (booking['status'] ?? 'Pending').toString();

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
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
                  text: isPendingConfirmation ? 'Pending Confirmation' : status,
                  kind: isPendingConfirmation
                      ? BadgeKind.warning
                      : (status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'finished'
                          ? BadgeKind.success
                          : (status.toLowerCase() == 'cancelled' ? BadgeKind.error : BadgeKind.info)),
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
                  color: colors.foreground.withValues(alpha: colors.surfaceProminent),
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
                  color: colors.foreground.withValues(alpha: colors.surfaceProminent),
                ),
                SizedBox(width: spacing.xs),
                Text(
                  timeString,
                  style: typography.body.copyWith(color: colors.foreground),
                ),
              ],
            ),
            if (isPendingConfirmation) ...[
              SizedBox(height: spacing.md),
              Container(
                padding: EdgeInsets.all(spacing.sm),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radii.medium),
                  border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Was this appointment completed, cancelled, or do you need to reschedule?',
                      style: typography.label.copyWith(color: colors.foreground),
                    ),
                    SizedBox(height: spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppSecondaryButton(
                            label: 'Cancelled',
                            onPressed: onConfirmCancelled,
                          ),
                        ),
                        SizedBox(width: spacing.xs),
                        Expanded(
                          child: AppSecondaryButton(
                            label: 'Reschedule',
                            onPressed: onReschedule,
                          ),
                        ),
                        SizedBox(width: spacing.xs),
                        Expanded(
                          child: AppGradientButton(
                            label: 'Finished',
                            onPressed: onConfirmFinished,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
