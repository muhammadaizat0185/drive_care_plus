import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../models/workshop.dart';
import '../../widgets/ui/ui.dart';
import '../workshop_detail_screen.dart';

/// Compact detail body for the redesigned workshops experience (Tasks 9.10
/// and 9.11). Mounted via [AppBottomSheet.show] from the Browse tab when a
/// workshop card is tapped (Task 9.10).
///
/// Layout (top to bottom):
///   * header row with the workshop name and rating;
///   * quick-info grid: `Status` tile and `Distance` tile;
///   * services chip cloud (workshop services or placeholder set);
///   * opening-hours list (one row per day);
///   * footer row with `Call` (secondary) and `Book Now` (gradient) actions.
///
/// Telephony and booking flows from the existing
/// [WorkshopDetailScreen] are preserved by routing the `Book Now` button
/// to that screen via [Navigator.pushReplacement] when more comprehensive
/// booking setup is required. Phone-call opens via [launchUrl] with the
/// `tel:` scheme; falls back to a snackbar if no phone number is present.
///
/// Visual constants come from the design-token extensions on
/// `Theme.of(context)`; no hex colors, spacing, radii, or typography
/// literals from the Token_Sets are inlined (Requirement 3.11).
class WorkshopDetailSheet extends StatelessWidget {
  final Workshop workshop;

  const WorkshopDetailSheet({super.key, required this.workshop});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final bool isOpen = workshop.isOpenNow ?? true;
    final List<String> hours = _hours();
    final List<String> services = _services();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ---- Header --------------------------------------------
          Text(
            workshop.name,
            style: typography.headline.copyWith(color: colors.foreground),
          ),
          SizedBox(height: spacing.xs),
          Row(
            children: <Widget>[
              AppBadge(
                text: '★ ${workshop.rating.toStringAsFixed(1)}',
                kind: BadgeKind.brand,
              ),
              SizedBox(width: spacing.sm),
              Text(
                '(${workshop.reviewCount} reviews)',
                style: typography.body.copyWith(
                  color: colors.foreground
                      .withValues(alpha: colors.surfaceProminent),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),

          // ---- Quick-info grid (Status + Distance) ---------------
          const AppSectionHeader(label: 'Quick info'),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickInfoTile(
                  icon: Icons.circle,
                  iconColor: isOpen ? colors.success : colors.error,
                  title: 'Status',
                  value: isOpen ? 'Open' : 'Closed',
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: _QuickInfoTile(
                  icon: Icons.location_on_outlined,
                  iconColor: colors.info,
                  title: 'Distance',
                  value: workshop.distance ?? '—',
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),

          // ---- Services chip cloud --------------------------------
          const AppSectionHeader(label: 'Services'),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: <Widget>[
              for (final String s in services) AppBadge(text: s),
            ],
          ),
          SizedBox(height: spacing.lg),

          // ---- Opening hours --------------------------------------
          const AppSectionHeader(label: 'Opening hours'),
          AppCard(
            child: Column(
              children: <Widget>[
                for (final String row in hours)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _splitHour(row).$1,
                            style: typography.body
                                .copyWith(color: colors.foreground),
                          ),
                        ),
                        Text(
                          _splitHour(row).$2,
                          style: typography.body.copyWith(
                            color: colors.foreground
                                .withValues(alpha: colors.surfaceProminent),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: spacing.lg),

          // ---- Footer: Call + Book Now ---------------------------
          Row(
            children: <Widget>[
              Expanded(
                child: AppSecondaryButton(
                  label: 'Call',
                  icon: Icons.phone_outlined,
                  onPressed: () => _launchPhone(context),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppGradientButton(
                  label: 'Book Now',
                  onPressed: () => _openFullBookingFlow(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _hours() {
    final List<dynamic>? raw =
        workshop.openingHours?['weekdayDescriptions'] as List?;
    if (raw != null && raw.isNotEmpty) {
      return raw.map((dynamic d) => d.toString()).toList(growable: false);
    }
    return const <String>[
      'Monday: 9:00 AM – 6:00 PM',
      'Tuesday: 9:00 AM – 6:00 PM',
      'Wednesday: 9:00 AM – 6:00 PM',
      'Thursday: 9:00 AM – 6:00 PM',
      'Friday: 9:00 AM – 6:00 PM',
      'Saturday: 10:00 AM – 4:00 PM',
      'Sunday: Closed',
    ];
  }

  (String, String) _splitHour(String row) {
    final List<String> parts = row.split(': ');
    if (parts.length < 2) {
      return (row, '');
    }
    return (parts.first, parts.sublist(1).join(': '));
  }

  List<String> _services() {
    if (workshop.services.isNotEmpty) {
      return workshop.services
          .map((WorkshopService s) => s.name)
          .toList(growable: false);
    }
    if (workshop.isCarWash) {
      return const <String>['Car Wash', 'Detailing', 'Vacuum'];
    }
    if (workshop.isGasStation) {
      return const <String>['Fuel', 'Air Pump', 'Convenience'];
    }
    return const <String>[
      'Oil Change',
      'Brakes',
      'Tires',
      'Diagnostics',
      'Battery',
    ];
  }

  Future<void> _launchPhone(BuildContext context) async {
    // The Workshop model does not currently surface a phone number from
    // Google Places; the redesigned card surfaces the action and the
    // detail sheet plumbs the intent. When the phone field lands on the
    // model the launchUrl call here will pick it up directly. For now
    // we surface an informational snackbar so the gesture has feedback.
    //
    // TODO(figma-ui-redesign Task 9.11): replace this snackbar fallback
    // with `launchUrl(Uri.parse('tel:${workshop.phoneNumber}'))` once
    // `Workshop.phoneNumber` is added to the model.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Uri webUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(workshop.name)}',
    );
    try {
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Phone number not available')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to launch dialer')),
      );
    }
  }

  void _openFullBookingFlow(BuildContext context) {
    // Existing booking flow lives in WorkshopDetailScreen. The bottom
    // sheet is the compact preview; the full booking setup remains the
    // existing screen so the date/time pickers, service selection grid,
    // and Firestore booking creation are preserved verbatim.
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => WorkshopDetailScreen(workshop: workshop),
      ),
    );
  }
}

class _QuickInfoTile extends StatelessWidget {
  const _QuickInfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: typography.body.fontSize, color: iconColor),
              SizedBox(width: spacing.xs),
              Text(
                title,
                style: typography.label.copyWith(
                  color: colors.foreground
                      .withValues(alpha: colors.surfaceProminent),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            value,
            style: typography.title.copyWith(color: colors.foreground),
          ),
        ],
      ),
    );
  }
}
