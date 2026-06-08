# Changelog - DriveCare+ Enhancements & Fixes

All notable changes made to the DriveCare+ codebase during this development cycle are documented below.

---

## [1.1.0] - 2026-06-08

### Added
*   **Zoned Booking Notifications**:
    *   Configured the `timezone` database with fallbacks (Malaysian Standard Time GMT+8 & UTC) in `NotificationService.init()`.
    *   Implemented zoned scheduling to issue local alerts **30 minutes before** a scheduled workshop appointment and at the **exact booking start time**.
    *   Integrated dynamic notifications lifecycle support: rescheduled appointments reschedule the reminders, while cancellations cancel them.
*   **Android App branding**:
    *   Configured `flutter_launcher_icons` and successfully built new high-resolution launcher mipmap icons generated from `assets/images/logo/app_logo.png`.

### Changed
*   **Android Launcher Label**:
    *   Modified `android:label` in `AndroidManifest.xml` from `drive_care_plus` to `DriveCare+`.
*   **Dashboard Navigation Direct Routing**:
    *   Refactored the dashboard's `UpcomingAppointmentCard` tap handler so it deep-links directly to the "My Bookings" tab instead of launching the "Find Workshop" search viewport.
    *   Converted `BookingScreen` to a `StatefulWidget` that tracks tabs reactively via `activeTabNotifier`.

### Fixed
*   **Dashboard SVG Rendering**:
    *   Fixed the dashboard's `VehicleHealthGauge` asset rendering code so that it respects the user's active custom car type and hex color from `VehicleInsights`.
*   **Dashboard Profile Avatar File Path**:
    *   Fixed path resolving for custom uploaded avatar image files inside `GreetingHeader` so that they render correctly in the cockpit view (resolving a sync mismatch with the settings screen avatar).
