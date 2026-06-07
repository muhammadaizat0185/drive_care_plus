// Booking screen extracted helpers (Group 14, Task 14.1).
//
// Hosts the workshop card and bookings tab list rendering used by the
// redesigned `BookingScreen`. Keeping these here keeps the screen file
// under the ~600-line ceiling stipulated by the Group 14 sweep playbook.
//
// Service preservation:
//   * `Workshop` data shape is unchanged.
//   * `WorkshopDetailScreen(workshop: workshop)` navigation is unchanged.
//   * `Geolocator.distanceBetween` and `url_launcher` calls are unchanged.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../models/workshop.dart';
import '../../widgets/ui/ui.dart';
import '../workshop_detail_screen.dart';

/// Workshop card rendered in the redesigned booking flow's
/// "Find Workshops" tab.
class BookingWorkshopCard extends StatelessWidget {
  final Workshop workshop;

  const BookingWorkshopCard({super.key, required this.workshop});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final String statusLabel = workshop.isOpenNow == true
        ? 'Open Now'
        : (workshop.isOpenNow == false ? 'Closed' : 'Status: N/A');
    final Color statusColor =
        workshop.isOpenNow == true ? colors.success : colors.error;

    String typeLabel = 'Automotive';
    if (workshop.types.contains('car_repair')) {
      typeLabel = 'Workshop';
    } else if (workshop.types.contains('gas_station')) {
      typeLabel = 'Fuel & Services';
    } else if (workshop.types.contains('car_wash')) {
      typeLabel = 'Car Wash';
    }

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing.sm,
                            vertical: spacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.emerald500.withValues(
                              alpha: colors.surfaceMedium,
                            ),
                            borderRadius:
                                BorderRadius.circular(radii.small),
                          ),
                          child: Text(
                            'POPULAR',
                            style: typography.label
                                .copyWith(color: colors.emerald500),
                          ),
                        ),
                        SizedBox(width: spacing.sm),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing.sm,
                            vertical: spacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.muted,
                            borderRadius:
                                BorderRadius.circular(radii.small),
                          ),
                          child: Text(
                            typeLabel.toUpperCase(),
                            style: typography.label
                                .copyWith(color: mutedForeground),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      workshop.name,
                      style: typography.title
                          .copyWith(color: colors.foreground),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.sm,
                  vertical: spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: colors.surfaceMedium),
                  borderRadius: BorderRadius.circular(radii.small),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: colors.warning,
                      size: typography.body.fontSize,
                    ),
                    SizedBox(width: spacing.xs),
                    Text(
                      workshop.rating.toStringAsFixed(1),
                      style: typography.label.copyWith(color: colors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: typography.body.fontSize,
                color: mutedForeground,
              ),
              SizedBox(width: spacing.xs),
              Text(
                workshop.distance ?? 'Nearby',
                style: typography.body.copyWith(color: mutedForeground),
              ),
              SizedBox(width: spacing.md),
              Icon(
                Icons.comment_outlined,
                size: typography.body.fontSize,
                color: mutedForeground,
              ),
              SizedBox(width: spacing.xs),
              Text(
                '${workshop.reviewCount} Reviews',
                style: typography.body.copyWith(color: mutedForeground),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          RichText(
            text: TextSpan(
              style:
                  typography.body.copyWith(color: colors.foreground),
              children: [
                TextSpan(
                  text: 'Status: ',
                  style: typography.body.copyWith(color: mutedForeground),
                ),
                TextSpan(
                  text: statusLabel,
                  style: typography.body.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.lg),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Navigate',
                  icon: Icons.directions,
                  fullWidth: true,
                  onPressed: _launchNavigation,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                // Primary CTA: gradient button (Requirement 12.4).
                child: AppGradientButton(
                  label:
                      workshop.isGasStation ? 'View Details' : 'Book Now',
                  onPressed: () => _openDetails(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkshopDetailScreen(workshop: workshop),
      ),
    );
  }

  Future<void> _launchNavigation() async {
    if (workshop.location == null) return;

    final lat = workshop.location!.latitude;
    final lng = workshop.location!.longitude;
    final url = Uri.parse('google.navigation:q=$lat,$lng');
    final webUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}

/// Confirmed-booking card rendered in the "My Bookings" tab.
class BookingConfirmedCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingConfirmedCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final price = booking['servicePrice'] as double? ?? 0.0;
    final status = booking['status'] as String? ?? 'Confirmed';

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking['workshopName'] ?? 'Workshop',
                  style: typography.title.copyWith(color: colors.foreground),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.md,
                  vertical: spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.emerald500
                      .withValues(alpha: colors.surfaceMedium),
                  borderRadius: BorderRadius.circular(radii.small),
                  border: Border.all(color: colors.emerald500),
                ),
                child: Text(
                  status,
                  style: typography.label
                      .copyWith(color: colors.emerald500),
                ),
              ),
            ],
          ),
          Divider(
            height: spacing.xl,
            color: colors.border,
          ),
          Row(
            children: [
              Icon(
                Icons.build_circle_outlined,
                size: typography.title.fontSize,
                color: mutedForeground,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  booking['serviceName'] ?? 'Service',
                  style: typography.bodyLarge
                      .copyWith(color: colors.foreground),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: typography.title.fontSize,
                color: mutedForeground,
              ),
              SizedBox(width: spacing.sm),
              Text(
                '${booking['date']} at ${booking['time']}',
                style:
                    typography.bodyLarge.copyWith(color: colors.foreground),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: typography.title.fontSize,
                color: mutedForeground,
              ),
              SizedBox(width: spacing.sm),
              Text(
                'Estimated: RM ${price.toStringAsFixed(2)}',
                style:
                    typography.bodyLarge.copyWith(color: colors.emerald500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
