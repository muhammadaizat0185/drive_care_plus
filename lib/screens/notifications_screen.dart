// Token + Component_Library sweep (Group 14, Task 14.4).
//
// Sweep summary:
//   * Section heading rendered via `AppSectionHeader`.
//   * Intro card rendered via `AppCard`.
//   * Each reminder rendered via `AppListTile`.
//   * Spacing/typography routed through token extensions.
//
// No data sources, controllers, navigation calls, or service calls are
// present in this screen — the original implementation rendered a static
// list. This sweep preserves the same static reminder copy verbatim.

import 'package:flutter/material.dart';

import '../core/theme/tokens/tokens.dart';
import '../widgets/ui/ui.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const routeName = '/notifications';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final reminders = [
      'Oil change reminder will be sent 7 days before due date.',
      'Workshop quotation reply will trigger a push notification.',
      'Insurance expiry reminder will be sent 30 days before expiry.',
    ];

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: EdgeInsets.all(spacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push Notification Plan',
                  style: typography.title.copyWith(color: colors.foreground),
                ),
                SizedBox(height: spacing.sm),
                Text(
                  'Dummy reminder center. Later this connects to Firebase Cloud Messaging.',
                  style: typography.bodyLarge
                      .copyWith(color: mutedForeground),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.lg),
          const AppSectionHeader(label: 'Reminders'),
          for (final reminder in reminders) ...[
            AppCard(
              padding: EdgeInsets.zero,
              child: AppListTile(
                leading: Icon(
                  Icons.notifications_active_outlined,
                  color: colors.emerald500,
                ),
                title: Text(
                  reminder,
                  style: typography.bodyLarge
                      .copyWith(color: colors.foreground),
                ),
              ),
            ),
            SizedBox(height: spacing.md),
          ],
        ],
      ),
    );
  }
}
