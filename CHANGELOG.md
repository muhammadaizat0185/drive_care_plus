# Changelog - DriveCare+ Enhancements & Fixes

All notable changes made to the DriveCare+ codebase during this development cycle are documented below.

---

## [1.3.0] - 2026-06-09

### Added
*   **Cloud Firestore Synchronization on Login**:
    *   Implemented `syncFromFirestore` in `VehicleInsights` to restore vehicles, bookings, and vault documents from Cloud Firestore on login.
    *   Linked restoration into the user initialization flow inside `AuthCleanupService.initializeUserData`.
*   **Fresh Start State for Authenticated Users**:
    *   Configured `VehicleInsights` default values to be empty on initialization.
    *   Modified seeding logic for default vehicle (`Perodua Axia`) and initial vault documents to only seed for unauthenticated (guest) users, ensuring a clean state for newly logged-in accounts.
*   **Refuel Log Deduplication**:
    *   Filtered the local optimistic `_entries` list in `RefuelLogScreen` to prevent double-rendering when entries are synced to/from Firestore.
*   **Robust Unit Testing**:
    *   Added comprehensive mock test suite in `test/services/vehicle_insights_test.dart` using `MockPlatformInterfaceMixin` and global reusable platform delegates to verify guest/auth seeding, Firestore sync, and CRUD operations.
*   **Vehicle Empty State UI**:
    *   Implemented interactive placeholder state inside the Cockpit's `VehicleHealthGauge` when no vehicles are registered, prompting them to add a vehicle and providing a link to navigate to the garage page.
    *   Implemented full empty state inside `VehicleScreen` to hide odometer tracking, diagnostic profile gauges, specifications, and checklist cards when no vehicles exist. It displays a "Your Garage is Empty" card with a button to launch the vehicle registration flow.
    *   Wrote a new widget test suite `test/screens/vehicle_screen_empty_state_test.dart` to verify empty state display and navigation hooks.
*   **Back Button Redirection & Double-Press Exit Interception**:
    *   Wrapped `HomeScreen` in a root `PopScope` to redirect back gestures from non-zero tabs (Shops, My Car, Refuel, Wallet) back to Cockpit (index 0).
    *   Implemented a double-press back gesture requirement within a 2-second window on the Cockpit page to exit the application cleanly via `SystemNavigator.pop()`.
    *   Wrote a dedicated widget test suite `test/screens/home_screen_back_button_test.dart` asserting correct redirection, snackbar display, and exit logic under varying timings.

---

## [1.2.0] - 2026-06-09

### Added
*   **Android Biometric Login**:
    *   Added support for local biometric credentials registration and hardware verification via `local_auth` and `flutter_secure_storage`.
    *   Declared `USE_BIOMETRIC` permission in `AndroidManifest.xml` and migrated `MainActivity.kt` to `FlutterFragmentActivity`.
    *   Added secure biometric toggle with password re-authentication inside the Settings screen.
    *   Integrated biometric sign-in button on the Login screen supporting background Firebase email/password authentication.
*   **Two-Factor Authentication (TOTP 2FA)**:
    *   Implemented base32 key generation and Google Authenticator-compatible QR codes via `otp` and `qr_flutter`.
    *   Created step-by-step 2FA setup flow inside Settings screen saving configuration to Cloud Firestore.
    *   Integrated session gating via a 6-digit `TOTPVerificationScreen` post-login with automatic Firebase sign-out if cancelled or bypassed.

### Changed
*   **Settings Swatch Preview & Notifications**:
    *   Upgraded settings notification toggles to fire descriptive snackbars.
    *   Allowed non-pro users to tap locked color swatches for custom theme previews (reverts on page exit if not upgraded).

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
