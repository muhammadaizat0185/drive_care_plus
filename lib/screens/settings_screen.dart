import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/color_utils.dart';
import '../core/theme/preset_validator.dart';
import '../core/theme/tokens/tokens.dart';
import '../core/util/in_flight_gate.dart';
import '../services/notification_preferences.dart';
import '../services/profile_service.dart';
import '../services/theme_service.dart';
import '../widgets/ui/ui.dart';
import 'login_screen.dart';

/// Redesigned Settings screen — section scaffolding (task 8.1) + the
/// `PROFILE` section (task 8.2).
///
/// Renders the eight section blocks required by Requirement 6.1 in this
/// exact order:
///
///   1. PROFILE
///   2. APPEARANCE
///   3. NOTIFICATIONS
///   4. PRIVACY & SECURITY
///   5. DATA & STORAGE
///   6. PREFERENCES
///   7. ABOUT & SUPPORT
///   8. (final) Sign Out button
///
/// Each section consists of an [AppSectionHeader] followed by either the
/// implementation built in the corresponding sub-task or a placeholder
/// [Container] that subsequent tasks will populate:
///
///   - 8.2 fills `PROFILE` with the avatar, display-name, phone, and
///     `Save Profile` controls (this task).
///   - 8.3 wires the unsaved-changes [AppFeedbackBanner].
///   - 8.5 fills `APPEARANCE` with the dark-mode toggle and 4-column
///     gradient swatch grid.
///   - 8.8 fills `NOTIFICATIONS` with the three toggles.
///   - 8.10 fills `PRIVACY & SECURITY`, `DATA & STORAGE`, `PREFERENCES`,
///     and `ABOUT & SUPPORT` with `AppListTile` rows.
///   - 8.11 wires the `Sign Out` button to the [AppBottomSheet]
///     confirmation flow.
///   - 8.12 wires the save-failure [AppFeedbackBanner].
///
/// Service references ([ProfileService], [ThemeService]) are preserved so
/// the populating tasks can pick them up directly.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const String routeName = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Controllers populated from `ProfileService` so the `PROFILE` section's
  // `AppTextField`s bind directly to the persisted profile snapshot. The
  // fields are initialised in [initState] from the current
  // [ProfileService] snapshot and disposed in [dispose].
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  /// Per-screen in-flight guard for the `Save Profile` gesture. Drops
  /// re-entrant taps while a previous [ProfileService.updateProfile]
  /// call is still in flight, so a single user gesture maps to a
  /// single persistence round-trip. The button's `isLoading` slot and
  /// the input fields' `enabled` flag are driven off
  /// [InFlightGate.isRunning] via a [ListenableBuilder] in the
  /// `PROFILE` section, mirroring the pattern used by `Sign In` on
  /// the login screen.
  final InFlightGate _saveGate = InFlightGate();

  /// Inline validation message rendered under the display-name field
  /// when the entered text is empty after trimming. Cleared on the
  /// next save attempt or user keystroke. Validation errors render
  /// via `AppTextField.errorText` per the task spec.
  String? _nameError;

  /// Inline validation message rendered under the phone field when
  /// the entered digits do not satisfy the 7–15 length constraint.
  /// Cleared on the next save attempt or user keystroke.
  String? _phoneError;

  /// Save-failure feedback message rendered as an error
  /// [AppFeedbackBanner] above the section content (task 8.12 —
  /// Requirement 6.10). Set to a non-null string when
  /// [ProfileService.updateProfile] throws; cleared on the next save
  /// attempt so the user gets fresh feedback per try. The user's
  /// edited values are intentionally retained — the controllers are
  /// not touched on failure so the user can correct and retry without
  /// retyping.
  String? _saveError;

  /// Returns `true` when the live controller text differs from the
  /// snapshot persisted by [ProfileService] for either the display
  /// name or phone number.
  ///
  /// Drives the unsaved-changes [AppFeedbackBanner] at the top of the
  /// scroll view (task 8.3 — Requirement 6.3): the banner is rendered
  /// while this getter returns `true` and removed once the controller
  /// text matches the persisted profile (whether by Save Profile
  /// succeeding or the user reverting their edits manually).
  ///
  /// Both branches are checked because either field on its own is
  /// sufficient to constitute an unsaved change. The comparison is a
  /// raw `!=` against the persisted values, exactly as the task spec
  /// dictates — trimming or normalisation here would diverge from
  /// what the save handler actually persists and could cause the
  /// banner to lie about whether the form is dirty.
  bool get _isDirty {
    final ProfileService profile = ProfileService.instance;
    return _nameController.text != profile.displayName ||
        _phoneController.text != profile.phone;
  }

  @override
  void initState() {
    super.initState();
    final ProfileService profile = ProfileService.instance;
    _nameController = TextEditingController(text: profile.displayName);
    _phoneController = TextEditingController(text: profile.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _saveGate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return AppBackground(
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          _nameController,
          _phoneController,
          ProfileService.instance,
          ThemeService.instance,
          NotificationPreferences.instance,
          _saveGate,
        ]),
        builder: (BuildContext context, Widget? _) {
          final AppColorsExt colors = theme.extension<AppColorsExt>()!;
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: <Widget>[
                if (_saveGate.isRunning)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                        ),
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _isDirty ? _onSavePressed : null,
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: _isDirty
                            ? colors.emerald500
                            : colors.foreground.withValues(
                                alpha: colors.surfaceProminent + 0.2,
                              ),
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
              ],
            ),
            body: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.lg,
                vertical: spacing.lg,
              ),
              children: <Widget>[
                // Save-failure banner (task 8.12 — Requirement 6.10).
                if (_saveError != null) ...<Widget>[
                  AppFeedbackBanner(
                    kind: FeedbackKind.error,
                    message: _saveError!,
                    onDismiss: () => setState(() => _saveError = null),
                  ),
                  SizedBox(height: spacing.lg),
                ],

                // Unsaved-changes banner (task 8.3 — Requirement 6.3).
                if (_isDirty) ...<Widget>[
                  const AppFeedbackBanner(
                    kind: FeedbackKind.warning,
                    message: 'You have unsaved changes.',
                  ),
                  SizedBox(height: spacing.lg),
                ],

                // 1. PROFILE — avatar, name, phone, Save Profile (task 8.2).
                const AppSectionHeader(label: 'PROFILE'),
                AppCard(
                  child: _ProfileSection(
                    nameController: _nameController,
                    phoneController: _phoneController,
                    saveGate: _saveGate,
                    nameError: _nameError,
                    phoneError: _phoneError,
                    onNameChanged: _onNameChanged,
                    onPhoneChanged: _onPhoneChanged,
                    onChangeAvatarPressed: _onChangeAvatarPressed,
                  ),
                ),
                SizedBox(height: spacing.xxl),

                // 2. APPEARANCE — dark-mode toggle + swatch grid (task 8.5).
                const AppSectionHeader(label: 'APPEARANCE'),
                const AppCard(
                  child: _AppearanceSection(),
                ),
                SizedBox(height: spacing.xxl),

                // 3. NOTIFICATIONS — three preference toggles (task 8.8).
                const AppSectionHeader(label: 'NOTIFICATIONS'),
                const AppCard(
                  child: _NotificationsSection(),
                ),
                SizedBox(height: spacing.xxl),

                // 4. PRIVACY & SECURITY — list tiles (task 8.10).
                const AppSectionHeader(label: 'PRIVACY & SECURITY'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _PrivacySecuritySection(onAction: _showComingSoon),
                ),
                SizedBox(height: spacing.xxl),

                // 5. DATA & STORAGE — list tiles (task 8.10).
                const AppSectionHeader(label: 'DATA & STORAGE'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _DataStorageSection(onAction: _showComingSoon),
                ),
                SizedBox(height: spacing.xxl),

                // 6. PREFERENCES — list tiles (task 8.10).
                const AppSectionHeader(label: 'PREFERENCES'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _PreferencesSection(onAction: _showComingSoon),
                ),
                SizedBox(height: spacing.xxl),

                // 7. ABOUT & SUPPORT — list tiles (task 8.10).
                const AppSectionHeader(label: 'ABOUT & SUPPORT'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _AboutSupportSection(onAction: _showComingSoon),
                ),
                SizedBox(height: spacing.xxl),

                // 8. Sign Out — full functionality wired in task 8.11.
                AppSecondaryButton(
                  label: 'Sign Out',
                  icon: Icons.logout_rounded,
                  fullWidth: true,
                  onPressed: _onSignOutPressed,
                ),
                SizedBox(height: spacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Clears the display-name validation error as soon as the user
  /// edits the field, so stale errors don't linger after the user
  /// has started addressing them. Re-validation runs on the next
  /// save attempt.
  void _onNameChanged(String _) {
    if (_nameError != null) {
      setState(() => _nameError = null);
    }
  }

  /// Clears the phone validation error as soon as the user edits
  /// the field. See [_onNameChanged].
  void _onPhoneChanged(String _) {
    if (_phoneError != null) {
      setState(() => _phoneError = null);
    }
  }

  /// Handler wired to the camera `AppIconButton` overlaying the
  /// avatar in the `PROFILE` section. Avatar selection is not yet
  /// implemented, so the handler surfaces a placeholder snackbar
  /// per the task spec; the underlying avatar-picker flow lands in
  /// a follow-up.
  void _onChangeAvatarPressed() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Change avatar — coming soon')),
      );
  }

  /// Handler wired to the `Save Profile` [AppGradientButton] in the
  /// `PROFILE` section.
  ///
  /// Validates locally before persisting:
  ///
  ///   * Display name must be 1–50 characters after trimming
  ///     (matches `AppTextField.maxLength: 50` and the
  ///     non-empty contract from Requirement 6.2).
  ///   * Phone must be 7–15 digits. The `digitsOnly` formatter and
  ///     `LengthLimitingTextInputFormatter(15)` enforce the upper
  ///     bound and the input alphabet at the keyboard layer; the
  ///     7-digit lower bound is enforced here.
  ///
  /// Validation errors render via `AppTextField.errorText`. On
  /// validation failure no [ProfileService.updateProfile] call is
  /// issued, mirroring the empty-field gate on the login screen.
  ///
  /// On validation success the call is routed through [_saveGate]
  /// so rapid taps yield exactly one persistence round-trip per
  /// user gesture; the gate's `isRunning` flag drives the button's
  /// `isLoading` visual via a [ListenableBuilder] in
  /// [_ProfileSection]. The save-failure [AppFeedbackBanner] is
  /// wired in task 8.12.
  Future<void> _onSavePressed() async {
    final String name = _nameController.text.trim();
    final String phone = _phoneController.text;

    final String? nameError =
        (name.isEmpty || name.length > 50) ? 'Enter a name (1–50 characters)' : null;
    final String? phoneError =
        (phone.length < 7 || phone.length > 15) ? 'Enter 7–15 digits' : null;

    setState(() {
      _nameError = nameError;
      _phoneError = phoneError;
      // Clear any prior save-failure banner on a fresh attempt so
      // the user sees feedback specific to this try.
      _saveError = null;
    });
    if (nameError != null || phoneError != null) {
      return;
    }

    final ProfileService profile = ProfileService.instance;
    // Wrap the gated call in try/catch so a failure inside
    // [ProfileService.updateProfile] surfaces the error feedback
    // banner (task 8.12 — Requirement 6.10) without dropping the
    // user's edited values. The InFlightGate releases on throw via
    // its `try/finally`, so the button returns to its idle state and
    // the user can retry once they've adjusted their input.
    try {
      await _saveGate.run<void>(() async {
        await profile.updateProfile(
          name: name,
          avatarUrl: profile.photoUrl,
          phoneNo: phone,
          userBio: profile.bio,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = 'Failed to save profile. Please try again.';
      });
    }
  }

  /// Handler shared across the `PRIVACY & SECURITY`, `DATA & STORAGE`,
  /// `PREFERENCES`, and `ABOUT & SUPPORT` rows.
  ///
  /// These sections render representative entries (`Change password`,
  /// `Two-factor auth`, `Clear cache`, ...) whose underlying flows are
  /// outside the scope of the figma-ui-redesign feature. The redesign
  /// task only requires rendering them via [AppListTile] /
  /// [AppSectionHeader] (Requirement 6.1); each tap surfaces a
  /// "coming soon" snackbar with the action's label so the row stays
  /// visibly interactive without diverging from the spec.
  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$label — coming soon')),
      );
  }

  /// Handler wired to the `Sign Out` button at the bottom of the
  /// settings scroll view (task 8.11 — Requirements 6.7 / 6.8 / 6.9).
  ///
  /// Presents an [AppBottomSheet] with `Cancel` and `Sign Out` buttons:
  ///
  ///   * `Cancel` pops the sheet with `false` — no navigation, no
  ///     sign-out. (Requirement 6.8.)
  ///   * `Sign Out` pops the sheet with `true`, then calls
  ///     `FirebaseAuth.instance.signOut()` and navigates to
  ///     `LoginScreen.routeName` via
  ///     `Navigator.pushReplacementNamed` so the auth screen replaces
  ///     the settings screen on the navigation stack. (Requirement
  ///     6.9.)
  ///
  /// `mounted` is checked after the awaited `signOut()` because the
  /// async hop can outlive the screen if the user backgrounds the app.
  /// Errors thrown by `signOut()` (e.g. a network failure) bubble out
  /// of this handler — the existing Firebase error pipeline shows a
  /// snackbar in the parent app shell.
  Future<void> _onSignOutPressed() async {
    final bool? confirmed = await AppBottomSheet.show<bool>(
      context,
      initialHeightFraction: 0.35,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
        final AppTypographyExt typography =
            theme.extension<AppTypographyExt>()!;
        final AppColorsExt colors = theme.extension<AppColorsExt>()!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Sign out of DriveCare+?',
              style: typography.headline.copyWith(color: colors.foreground),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.md),
            Text(
              'You can sign back in any time.',
              style: typography.bodyLarge.copyWith(
                color: colors.foreground.withValues(
                  alpha: colors.surfaceProminent + 0.4,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xl),
            AppGradientButton(
              label: 'Sign Out',
              icon: Icons.logout_rounded,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            SizedBox(height: spacing.md),
            AppSecondaryButton(
              label: 'Cancel',
              fullWidth: true,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      // Cancel branch (Requirement 6.8) — no navigation, no auth
      // mutation. The sheet has already dismissed itself by popping.
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Sign-out failures are rare in practice (the call resolves
      // locally and is non-blocking on the backend) but if one
      // occurs, surface a snackbar and stay on the settings screen
      // so the user can retry. We deliberately don't push the auth
      // screen on failure since the local auth state may still be
      // intact.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Sign out failed. Please try again.')),
        );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }
}

/// `PROFILE` section body (task 8.2 — Requirement 6.2).
///
/// Layout:
///
///   * 96-pixel avatar built from a [CircleAvatar] backed by
///     `NetworkImage(profile.photoUrl)`, with an overlaid camera
///     [AppIconButton] (`semanticsLabel: 'Change avatar'`) anchored
///     to the bottom-right corner inside a [Stack].
///   * Display-name [AppTextField] bound to the parent's
///     `_nameController` (`maxLength: 50`, non-empty validation
///     surfaced through `errorText`).
///   * Phone [AppTextField] bound to the parent's
///     `_phoneController` with `keyboardType: TextInputType.phone`
///     and the `digitsOnly` + `LengthLimitingTextInputFormatter(15)`
///     formatters; the 7-digit lower bound is validated by the
///     parent on save and surfaced through `errorText`.
///   * Full-width `Save Profile` [AppGradientButton]. Tap routes
///     through the parent's [InFlightGate] so rapid taps yield one
///     [ProfileService.updateProfile] round-trip per user gesture;
///     the gate's `isRunning` flag drives the button's `isLoading`
///     visual via a [ListenableBuilder].
///
/// The widget rebuilds itself when [ProfileService] notifies so the
/// avatar's `backgroundImage` reflects external profile updates
/// (e.g. avatar change wired in a follow-up task).
class _ProfileSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final InFlightGate saveGate;
  final String? nameError;
  final String? phoneError;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onChangeAvatarPressed;

  const _ProfileSection({
    required this.nameController,
    required this.phoneController,
    required this.saveGate,
    required this.nameError,
    required this.phoneError,
    required this.onNameChanged,
    required this.onPhoneChanged,
    required this.onChangeAvatarPressed,
  });

  /// Avatar visual diameter (logical pixels). Held here as a local
  /// layout constant because the design uses a single avatar size
  /// for the `PROFILE` section and the value isn't a `Token_Set`
  /// member; spacing/radii/typography come from tokens.
  static const double _avatarDiameter = 96.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return ListenableBuilder(
      listenable: ProfileService.instance,
      builder: (BuildContext context, Widget? _) {
        final ProfileService profile = ProfileService.instance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Avatar + camera overlay. Centered horizontally so the
            // section has a clear focal point above the form fields.
            Center(
              child: SizedBox(
                width: _avatarDiameter,
                height: _avatarDiameter,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    CircleAvatar(
                      radius: _avatarDiameter / 2,
                      backgroundImage: NetworkImage(profile.photoUrl),
                      backgroundColor: colors.muted,
                    ),
                    // Camera overlay anchored to the bottom-right. The
                    // 48x48 hit area enforced inside [AppIconButton]
                    // (`Touch_Target_Floor` from Requirement 13.3)
                    // intentionally overhangs the avatar's circle by
                    // a few pixels so it doesn't clip into the photo.
                    Positioned(
                      right: -spacing.xs,
                      bottom: -spacing.xs,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.background,
                            width: 2.0,
                          ),
                        ),
                        child: AppIconButton(
                          icon: Icons.camera_alt,
                          semanticsLabel: 'Change avatar',
                          onPressed: onChangeAvatarPressed,
                          color: colors.emerald500,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.xl),

            // Display name. `maxLength: 50` is enforced by the
            // `AppTextField` itself (which sets
            // `MaxLengthEnforcement.enforced`); the lower bound (1)
            // is validated by the parent on save.
            ListenableBuilder(
              listenable: saveGate,
              builder: (BuildContext context, Widget? _) {
                return AppTextField(
                  controller: nameController,
                  label: 'Display name',
                  hintText: 'How should we greet you?',
                  prefixIcon: Icons.person_outline,
                  maxLength: 50,
                  errorText: nameError,
                  enabled: !saveGate.isRunning,
                  onChanged: onNameChanged,
                  textCapitalization: TextCapitalization.words,
                );
              },
            ),
            SizedBox(height: spacing.lg),

            // Phone. Keyboard is constrained to digit input and the
            // length is hard-capped at 15 by
            // `LengthLimitingTextInputFormatter`. The 7-digit lower
            // bound is checked by the parent on save and surfaced
            // through `errorText`.
            ListenableBuilder(
              listenable: saveGate,
              builder: (BuildContext context, Widget? _) {
                return AppTextField(
                  controller: phoneController,
                  label: 'Phone number',
                  hintText: '0123456789',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  errorText: phoneError,
                  enabled: !saveGate.isRunning,
                  onChanged: onPhoneChanged,
                );
              },
            ),

          ],
        );
      },
    );
  }
}

/// `NOTIFICATIONS` section body (task 8.8 — Requirement 6.6).
///
/// Renders three labelled rows, one per notification preference, each
/// pairing a token-styled label with an [AppToggleSwitch] bound to the
/// matching field on `NotificationPreferences.instance`:
///
///   * `Maintenance Reminders` — `notif_maintenance_reminders` key.
///   * `Booking Confirmations` — `notif_booking_confirmations` key.
///   * `Weekly Reports`        — `notif_weekly_reports` key.
///
/// Toggling routes through the corresponding `set...` method on the
/// service, which:
///
///   1. flips the in-memory state and notifies listeners (the outer
///      `ListenableBuilder` in `_SettingsScreenState.build` rebuilds
///      this section so the toggle updates on the same frame),
///   2. persists the new value to `SharedPreferences` under the
///      documented key.
///
/// The section is stateless: the toggles read live state from the
/// singleton and the parent's listenable subscription handles
/// rebuilds.
class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    final NotificationPreferences prefs = NotificationPreferences.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _NotificationRow(
          label: 'Maintenance Reminders',
          value: prefs.maintenanceReminders,
          onChanged: prefs.setMaintenanceReminders,
        ),
        _NotificationRow(
          label: 'Booking Confirmations',
          value: prefs.bookingConfirmations,
          onChanged: prefs.setBookingConfirmations,
        ),
        _NotificationRow(
          label: 'Weekly Reports',
          value: prefs.weeklyReports,
          onChanged: prefs.setWeeklyReports,
        ),
      ],
    );
  }
}

/// Single label-plus-toggle row used by [_NotificationsSection].
///
/// Layout mirrors the dark-mode row in [_AppearanceSection]: the label
/// occupies the leading edge via an `Expanded`, the toggle pins to the
/// trailing edge via a fixed-size [AppToggleSwitch]. Vertical gap
/// between rows uses `AppSpacing.md` so the section reads as a clean
/// grouped list without bumping into the next section header.
class _NotificationRow extends StatelessWidget {
  final String label;
  final bool value;
  final Future<void> Function(bool) onChanged;

  const _NotificationRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: typography.bodyLarge.copyWith(color: colors.foreground),
            ),
          ),
          AppToggleSwitch(
            value: value,
            semanticsLabel: label,
            onChanged: (bool v) {
              // Fire-and-forget: the onChanged contract returns void,
              // and the persistence write is non-blocking from the
              // UI's perspective. Errors degrade gracefully via the
              // service's debugPrint pipeline.
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

/// `PRIVACY & SECURITY` section body (task 8.10 — Requirement 6.1).
///
/// Renders representative rows via [AppListTile]:
///
///   * `Change password` — placeholder action surfaced as a snackbar.
///   * `Two-factor auth` — placeholder action surfaced as a snackbar.
///
/// The redesign task only requires that these sections render via the
/// Component_Library tile primitives in the documented order; the
/// underlying flows (password change, 2FA enrolment) are out of scope
/// for the figma-ui-redesign feature and are handled in dedicated
/// product workstreams. The `coming soon` snackbar is the visible
/// signal that the row is interactive without diverging from the
/// spec's "no new features" non-goal.
class _PrivacySecuritySection extends StatelessWidget {
  final void Function(String label) onAction;

  const _PrivacySecuritySection({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final TextStyle titleStyle =
        typography.bodyLarge.copyWith(color: colors.foreground);
    final Color iconColor =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppListTile(
          leading: Icon(Icons.lock_outline, color: iconColor),
          title: Text('Change password', style: titleStyle),
          trailing: Icon(Icons.chevron_right, color: iconColor),
          onTap: () => onAction('Change password'),
        ),
        AppListTile(
          leading: Icon(Icons.shield_outlined, color: iconColor),
          title: Text('Two-factor auth', style: titleStyle),
          trailing: Icon(Icons.chevron_right, color: iconColor),
          onTap: () => onAction('Two-factor auth'),
        ),
      ],
    );
  }
}

/// `DATA & STORAGE` section body (task 8.10 — Requirement 6.1).
///
/// Renders representative rows via [AppListTile] for cache + storage
/// management. See [_PrivacySecuritySection] for the broader rationale
/// behind the placeholder-handler pattern.
class _DataStorageSection extends StatelessWidget {
  final void Function(String label) onAction;

  const _DataStorageSection({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final TextStyle titleStyle =
        typography.bodyLarge.copyWith(color: colors.foreground);
    final Color iconColor =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppListTile(
          leading: Icon(Icons.cleaning_services_outlined, color: iconColor),
          title: Text('Clear cache', style: titleStyle),
          trailing: Icon(Icons.chevron_right, color: iconColor),
          onTap: () => onAction('Clear cache'),
        ),
        AppListTile(
          leading: Icon(Icons.storage_outlined, color: iconColor),
          title: Text('Storage usage', style: titleStyle),
          trailing: Icon(Icons.chevron_right, color: iconColor),
          onTap: () => onAction('Storage usage'),
        ),
      ],
    );
  }
}

/// `PREFERENCES` section body (task 8.10 — Requirement 6.1).
///
/// Renders representative rows via [AppListTile] for locale + region.
/// The current values are hardcoded display strings (`English`,
/// `Malaysia`) since the figma-ui-redesign feature does not introduce
/// new preference flows; the rows preview the eventual UI shape with
/// the visible value rendered via the tile's `subtitle` slot.
class _PreferencesSection extends StatelessWidget {
  final void Function(String label) onAction;

  const _PreferencesSection({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final TextStyle titleStyle =
        typography.bodyLarge.copyWith(color: colors.foreground);
    final TextStyle subtitleStyle = typography.body.copyWith(
      color: colors.foreground.withValues(
        alpha: colors.surfaceProminent + 0.4,
      ),
    );
    final Color iconColor =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppListTile(
          leading: Icon(Icons.language, color: iconColor),
          title: Text('Language', style: titleStyle),
          subtitle: Text('English', style: subtitleStyle),
          trailing: Icon(Icons.chevron_right, color: iconColor),
          onTap: () => onAction('Language'),
        ),
        AppListTile(
          leading: Icon(Icons.public, color: iconColor),
          title: Text('Region', style: titleStyle),
          subtitle: Text('Malaysia', style: subtitleStyle),
          trailing: Icon(Icons.chevron_right, color: iconColor),
          onTap: () => onAction('Region'),
        ),
      ],
    );
  }
}

/// `ABOUT & SUPPORT` section body (task 8.10 — Requirement 6.1).
///
/// Renders the app version (read from the `pubspec.yaml`-aligned
/// `1.0.0+1` literal — the pubspec parsing is out of scope here, and
/// the design only needs the value visible) plus a help/feedback
/// entry that surfaces a placeholder snackbar.
class _AboutSupportSection extends StatelessWidget {
  /// App version pinned to the value declared in `pubspec.yaml`. The
  /// figma-ui-redesign tasks document permits a hardcoded fallback
  /// when reading from `PackageInfo` would require a new dependency;
  /// the constant is held here so a future migration to
  /// `package_info_plus` only touches this single line.
  static const String _appVersion = '1.0.0+1';

  final void Function(String label) onAction;

  const _AboutSupportSection({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final TextStyle titleStyle =
        typography.bodyLarge.copyWith(color: colors.foreground);
    final TextStyle subtitleStyle = typography.body.copyWith(
      color: colors.foreground.withValues(
        alpha: colors.surfaceProminent + 0.4,
      ),
    );
    final Color iconColor =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppListTile(
          leading: Icon(Icons.info_outline, color: iconColor),
          title: Text('App version', style: titleStyle),
          subtitle: Text(_appVersion, style: subtitleStyle),
        ),
        AppListTile(
          leading: Icon(Icons.help_outline, color: iconColor),
          title: Text('Help & Feedback', style: titleStyle),
          trailing: Icon(Icons.chevron_right, color: iconColor),
          onTap: () => onAction('Help & Feedback'),
        ),
      ],
    );
  }
}

/// `APPEARANCE` section body (tasks 8.5 + 8.6 — Requirements 6.4 / 6.5).
///
/// Renders, top-to-bottom:
///
///   * A `Dark mode` row pairing a token-styled label with an
///     [AppToggleSwitch] whose `value` mirrors
///     `ThemeService.themeMode == ThemeMode.dark`. Toggling routes
///     through `ThemeService.setThemeMode(...)` (light ↔ dark), which
///     persists the new mode through SharedPreferences and re-renders
///     `MaterialApp` with the matching `ThemeData` on the next frame
///     (Requirements 2.3 / 2.4 wired by the existing service).
///   * A 4-column `GridView` of circular gradient swatches built from
///     `ThemeService.presets.values.toList()`. Each swatch is a
///     tappable `LinearGradient`-filled circle whose four-stop palette
///     is derived from the preset color via `derivePalette(...)` so
///     every swatch previews the same gradient brand treatment that
///     the rest of the app applies once the preset is picked.
///   * The currently selected swatch — where the swatch color equals
///     `ThemeService.instance.primaryColor` — overlays a centred
///     [Icons.check] glyph so exactly one swatch carries the checkmark
///     at all times (Requirement 6.5).
///
/// Tap behaviour routes through [setPrimaryColorValidated] (the
/// preset-validating wrapper added in task 2.6) so non-presets are
/// rejected before they reach `ThemeService` and the active themes are
/// retained without modification (Requirement 2.7). The swatch grid
/// only ever feeds preset values into the validator, but a defensive
/// `try/catch` surfaces the [NonPresetColorError] message via a
/// snackbar — this branch is exercised by the safety contract, not
/// the happy path.
///
/// The widget is stateless: re-renders on `ThemeService` notifications
/// are driven by the outer `ListenableBuilder` in
/// `_SettingsScreenState.build`, which already merges `ThemeService`
/// into its listenable set (so flipping the dark-mode toggle and
/// picking a swatch both refresh this subtree on the next frame).
///
/// Every visual constant — spacing between rows, swatch grid spacing,
/// row gap — flows from the design-token extensions on
/// `Theme.of(context)`; no hex colors, spacing, or radii literals from
/// the Token_Sets are inlined (Requirement 3.11). The checkmark glyph
/// reads its color from `Colors.white` because it sits on top of a
/// dark-end gradient stop and needs to read against any preset hue;
/// `Colors.white` is the contrast-safe stable choice across the seven
/// preset gradients regardless of the active light/dark theme mode.
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  /// Diameter of each swatch circle in logical pixels. The cell width
  /// is determined by the surrounding `GridView`'s `crossAxisCount: 4`
  /// constraint; this constant only sizes the inner circle so the
  /// checkmark glyph centres consistently regardless of the available
  /// cell width.
  static const double _swatchDiameter = 56.0;

  /// Visual size of the checkmark glyph rendered on the selected
  /// swatch. Held local because the glyph size is a component-local
  /// detail, not a Token_Set member.
  static const double _checkGlyphSize = 28.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final ThemeService themeService = ThemeService.instance;
    final bool isDark = themeService.themeMode == ThemeMode.dark;
    final Color selected = themeService.primaryColor;

    // Snapshot the preset colors as a stable list. `ThemeService.presets`
    // is a compile-time `static const Map<String, Color>` so the order
    // is deterministic and matches the design's swatch sequence.
    final List<Color> presetColors =
        ThemeService.presets.values.toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Dark-mode row: label + toggle, separated by an `Expanded` so
        // the toggle pins to the trailing edge regardless of label
        // width.
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Dark mode',
                style: typography.bodyLarge.copyWith(
                  color: colors.foreground,
                ),
              ),
            ),
            AppToggleSwitch(
              value: isDark,
              semanticsLabel: 'Dark mode',
              onChanged: (bool v) {
                themeService.setThemeMode(
                  v ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        Text(
          'Choose your accent color',
          style: typography.body.copyWith(
            color: colors.foreground.withValues(
              alpha: colors.surfaceProminent + 0.4,
            ),
          ),
        ),
        SizedBox(height: spacing.lg),

        // 4-column gradient swatch grid. `shrinkWrap` + the inner
        // `NeverScrollableScrollPhysics` let the grid sit inside the
        // outer `ListView` without taking over the scroll gesture.
        // `childAspectRatio: 1` keeps every cell a square so the
        // circular swatch fits regardless of available width.
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: spacing.md,
          crossAxisSpacing: spacing.md,
          childAspectRatio: 1.0,
          children: <Widget>[
            for (final Color preset in presetColors)
              _SwatchTile(
                color: preset,
                selected: preset == selected,
                diameter: _swatchDiameter,
                checkGlyphSize: _checkGlyphSize,
                onTap: () => _onSwatchTap(context, preset),
              ),
          ],
        ),
      ],
    );
  }

  /// Routes a swatch tap through [setPrimaryColorValidated] so the
  /// preset-only contract from Requirement 2.7 is honoured at the
  /// public interaction surface.
  ///
  /// The grid only feeds `ThemeService.presets.values` into the
  /// validator, so the [NonPresetColorError] branch should never
  /// trigger in practice. The defensive `try/catch` is here so that
  /// any future regression — e.g. a swatch built from a non-preset
  /// color — surfaces visibly via a snackbar instead of failing
  /// silently or throwing into the framework's error reporter.
  Future<void> _onSwatchTap(BuildContext context, Color color) async {
    try {
      await setPrimaryColorValidated(color);
    } on NonPresetColorError catch (e) {
      // Guard: the swatch grid only emits preset colors, so this
      // branch is the safety net the task spec calls out.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Single circular gradient swatch used by [_AppearanceSection].
///
/// Renders a circle filled with a `LinearGradient` derived from
/// [color] via `derivePalette(...)` so the preview matches the gradient
/// stops the rest of the app will use once the preset is picked.
/// When [selected] is `true`, a centred `Icons.check` glyph is
/// overlaid in `Colors.white` so the active preset is unambiguous at
/// a glance.
///
/// Tap routes through the parent's [onTap] handler, which itself
/// routes through [setPrimaryColorValidated]. The widget enforces a
/// `48 x 48` logical-pixel hit area via [GestureDetector]'s
/// `behavior: HitTestBehavior.opaque` plus a `SizedBox` floor on the
/// outer cell so the swatch satisfies the `Touch_Target_Floor` from
/// Requirement 13.3 even though its visual diameter is 56 logical
/// pixels.
class _SwatchTile extends StatelessWidget {
  final Color color;
  final bool selected;
  final double diameter;
  final double checkGlyphSize;
  final VoidCallback onTap;

  const _SwatchTile({
    required this.color,
    required this.selected,
    required this.diameter,
    required this.checkGlyphSize,
    required this.onTap,
  });

  // `Touch_Target_Floor` from Requirements 3.10 / 13.3. Held local
  // because it's an accessibility floor, not a layout token.
  static const double _minHitArea = 48.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;

    // Derive a coherent four-stop gradient palette from the seed so
    // the swatch previews the same brand-gradient treatment used by
    // `AppPrimaryButton` and friends once the preset is applied.
    final ({
      Color emerald500,
      Color emerald600,
      Color teal400,
      Color teal500,
    }) palette = derivePalette(color);

    final Widget circle = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? colors.foreground
              : colors.foreground.withValues(alpha: 0.15),
          width: selected ? 2.0 : 1.0,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.emerald500,
            palette.emerald600,
            palette.teal500,
            palette.teal400,
          ],
        ),
      ),
      child: selected
          ? Icon(
              Icons.check,
              size: checkGlyphSize,
              color: Colors.white,
              semanticLabel: 'Selected',
            )
          : null,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: SizedBox(
          width: _minHitArea > diameter ? _minHitArea : diameter,
          height: _minHitArea > diameter ? _minHitArea : diameter,
          child: Center(child: circle),
        ),
      ),
    );
  }
}
