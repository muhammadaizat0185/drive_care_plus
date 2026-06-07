import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny notification preference store backing the three toggles in the
/// `NOTIFICATIONS` section of the redesigned settings screen
/// (`maintenance reminders`, `booking confirmations`, `weekly reports`).
///
/// The DriveCare+ codebase did not previously have a dedicated service
/// for these flags, so this class fills that gap with the minimum
/// surface required by Requirement 6.6:
///
///   * In-memory state for the three toggles, defaulting to `true` so a
///     fresh install starts with all notification kinds enabled.
///   * Persistence to `SharedPreferences` under deterministic keys so
///     the choices survive app restarts.
///   * `ChangeNotifier` so the settings screen can `ListenableBuilder`
///     against the singleton and rebuild the toggle row whenever a
///     value flips (mirrors the pattern used by `ProfileService` and
///     `ThemeService`).
///
/// The service is intentionally a singleton (`NotificationPreferences
/// .instance`) because the three flags are global app preferences, not
/// per-screen state. Tests reset the singleton's in-memory values via
/// [reset] and seed the prefs store via
/// `SharedPreferences.setMockInitialValues({...})` before exercising
/// the screen.
///
/// SharedPreferences keys, all `bool`:
///
///   * `notif_maintenance_reminders`
///   * `notif_booking_confirmations`
///   * `notif_weekly_reports`
class NotificationPreferences extends ChangeNotifier {
  /// Process-wide singleton. The settings screen and any future
  /// notification dispatch site read through this instance so the
  /// three flags have one canonical source of truth.
  static final NotificationPreferences instance =
      NotificationPreferences._internal();

  NotificationPreferences._internal();

  // SharedPreferences keys — exported as `static const` so tests and
  // any future migration step can reference them by name without
  // duplicating the literal strings.
  static const String kMaintenanceRemindersKey =
      'notif_maintenance_reminders';
  static const String kBookingConfirmationsKey =
      'notif_booking_confirmations';
  static const String kWeeklyReportsKey = 'notif_weekly_reports';

  bool _maintenanceReminders = true;
  bool _bookingConfirmations = true;
  bool _weeklyReports = true;

  /// Whether the user wants maintenance reminder notifications.
  /// Defaults to `true` on a fresh install.
  bool get maintenanceReminders => _maintenanceReminders;

  /// Whether the user wants booking confirmation notifications.
  /// Defaults to `true` on a fresh install.
  bool get bookingConfirmations => _bookingConfirmations;

  /// Whether the user wants weekly summary report notifications.
  /// Defaults to `true` on a fresh install.
  bool get weeklyReports => _weeklyReports;

  /// Loads the three flags from `SharedPreferences`.
  ///
  /// Missing keys fall back to `true` (the default-on contract). Errors
  /// reading the prefs store degrade gracefully — the in-memory
  /// defaults stay in place and a debug log is emitted, mirroring the
  /// pattern used by `ProfileService.init()` and `ThemeService.init()`.
  ///
  /// Listeners are notified once after the load completes so
  /// `ListenableBuilder`s rebuild with the persisted values on the
  /// next frame.
  Future<void> init() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _maintenanceReminders =
          prefs.getBool(kMaintenanceRemindersKey) ?? true;
      _bookingConfirmations =
          prefs.getBool(kBookingConfirmationsKey) ?? true;
      _weeklyReports = prefs.getBool(kWeeklyReportsKey) ?? true;
    } catch (e) {
      debugPrint('NotificationPreferences.init error: $e');
    }
    notifyListeners();
  }

  /// Sets the maintenance-reminders flag, persisting through
  /// `SharedPreferences`. Listeners are notified before the persist
  /// completes so the UI flips immediately and the toggle round-trip
  /// stays snappy.
  Future<void> setMaintenanceReminders(bool value) async {
    if (_maintenanceReminders == value) return;
    _maintenanceReminders = value;
    notifyListeners();
    await _persistBool(kMaintenanceRemindersKey, value);
  }

  /// Sets the booking-confirmations flag. See
  /// [setMaintenanceReminders].
  Future<void> setBookingConfirmations(bool value) async {
    if (_bookingConfirmations == value) return;
    _bookingConfirmations = value;
    notifyListeners();
    await _persistBool(kBookingConfirmationsKey, value);
  }

  /// Sets the weekly-reports flag. See [setMaintenanceReminders].
  Future<void> setWeeklyReports(bool value) async {
    if (_weeklyReports == value) return;
    _weeklyReports = value;
    notifyListeners();
    await _persistBool(kWeeklyReportsKey, value);
  }

  /// Resets the in-memory state to its default values without touching
  /// the persisted store. Intended for tests that need a clean slate
  /// between iterations of a property sweep.
  @visibleForTesting
  void reset() {
    _maintenanceReminders = true;
    _bookingConfirmations = true;
    _weeklyReports = true;
    notifyListeners();
  }

  Future<void> _persistBool(String key, bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('NotificationPreferences persist error ($key): $e');
    }
  }
}
