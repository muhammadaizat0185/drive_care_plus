# Requirements Document

## Introduction

The DriveCare+ Flutter application is undergoing a comprehensive UI redesign based on a Figma exploration delivered as React/TypeScript components in the `UI Improvement Suggestion/` folder. This feature ports those mockups into idiomatic Flutter, introducing a centralized design token system (colors, typography, spacing, border radii, shadows, motion) that supports light and dark modes, a library of reusable widgets that mirror the shadcn/ui patterns used in the source, and a per-screen redesign of every existing screen in `lib/screens/`. The redesign must preserve all current functionality, state management, and data integrations (Firebase Auth, Firestore, ToyyibPay, Google Maps, SharedPreferences, journey/fuel/marketplace databases). The TypeScript source is gitignored and serves as a visual reference only — it must never be imported, built, or shipped with the Flutter application.

## Glossary

- **Flutter_App**: The DriveCare+ Flutter application contained in the `lib/` directory.
- **Reference_Source**: The contents of the `UI Improvement Suggestion/` folder (React/TypeScript Figma exports). The folder is gitignored and is treated as read-only reference material.
- **Design_Tokens_Module**: A Dart module under `lib/core/theme/` exposing color, typography, spacing, radius, shadow, and motion tokens as compile-time constants and `ThemeData` extensions.
- **Token_Set**: A specific value collection under the Design_Tokens_Module (for example `AppColors`, `AppTypography`, `AppSpacing`, `AppRadii`, `AppShadows`, `AppMotion`).
- **Component_Library**: A set of reusable Flutter widgets under `lib/widgets/ui/` that implement the redesigned visual primitives (buttons, cards, inputs, badges, feedback banners, bottom navigation, modal sheets, etc.).
- **Improved_Screen**: A redesigned Flutter screen in `lib/screens/` whose visual structure mirrors the corresponding `*Improved.tsx` mockup in the Reference_Source.
- **Mocked_Screen**: A screen in the Reference_Source that has a dedicated `*Improved.tsx` file (Home, Login, Settings, Workshops, Vehicle, Refuel, Vault, Wallet).
- **Unmocked_Screen**: A screen in `lib/screens/` that has no dedicated mockup (booking_screen, journey_log_screen, maintenance_screen, notifications_screen, splash_screen, toyyibpay_webview_screen, trip_planner_screen, trip_tracking_screen, register_screen, vehicle_customizer_screen, workshop_detail_screen).
- **Theme_Service**: The existing `ThemeService` in `lib/services/theme_service.dart` that persists primary color and `ThemeMode` selections via `SharedPreferences`.
- **Light_Theme** / **Dark_Theme**: The two `ThemeData` outputs produced by the redesigned `AppTheme.buildTheme(...)`, corresponding to `Brightness.light` and `Brightness.dark`.
- **Accessibility_Floor**: The minimum readable text sizes mandated by the design system — 12 logical pixels for body text and 10 logical pixels for labels and badges.
- **Touch_Target_Floor**: The minimum interactive surface size — 48 logical pixels by 48 logical pixels.

## Requirements

### Requirement 1: Design Token Module

**User Story:** As a Flutter developer, I want a centralized design token module that mirrors the values defined in the Reference_Source, so that every screen and widget reads visual constants from a single source of truth.

#### Acceptance Criteria

1. THE Flutter_App SHALL define a Design_Tokens_Module under `lib/core/theme/` that exposes color, typography, spacing, radius, shadow, and motion Token_Sets, where each Token_Set is a Dart class whose members are Dart compile-time constants.
2. THE Design_Tokens_Module SHALL expose a color Token_Set containing the primary brand palette `Emerald 500 = #10B981`, `Emerald 600 = #059669`, `Teal 400 = #2DD4BF`, `Teal 500 = #14B8A6`, plus semantic colors `Success = #10B981`, `Warning = #F59E0B`, `Error = #EF4444`, `Info = #3B82F6`.
3. THE Design_Tokens_Module SHALL expose surface opacity tokens `surfaceSubtle = 0.05`, `surfaceMedium = 0.12`, and `surfaceProminent = 0.20` as `double` values within the inclusive range `[0.0, 1.0]` for translucent overlays.
4. THE Design_Tokens_Module SHALL expose a spacing Token_Set with the values `xs = 4.0`, `sm = 8.0`, `md = 12.0`, `lg = 16.0`, `xl = 24.0`, `xxl = 32.0`, `xxxl = 40.0`, `xxxxl = 48.0`, all in logical pixels.
5. THE Design_Tokens_Module SHALL expose a border radius Token_Set with the values `small = 12.0`, `medium = 16.0`, `large = 24.0`, `xLarge = 32.0`, all in logical pixels.
6. THE Design_Tokens_Module SHALL expose a typography Token_Set with named `TextStyle` entries `display` (32sp / weight 900), `headlineLarge` (24sp / weight 900), `headline` (20sp / weight 800), `title` (16sp / weight 700), `bodyLarge` (14sp / weight 400), `body` (12sp / weight 400), and `label` (10sp / weight 700).
7. THE Design_Tokens_Module SHALL expose a shadow Token_Set with the values `small`, `medium`, `large`, and `xLarge` whose blur, offset, and opacity match the Reference_Source values `0 1px 2px rgba(0,0,0,0.05)`, `0 4px 6px rgba(0,0,0,0.1)`, `0 10px 15px rgba(0,0,0,0.1)`, and `0 20px 25px rgba(0,0,0,0.15)` respectively.
8. WHEN the active theme brightness is `Brightness.dark`, THE Design_Tokens_Module SHALL return shadow opacities computed by multiplying the light-mode shadow opacities by `2.5` and clamping the result to the inclusive range `[0.0, 1.0]`.
9. THE Design_Tokens_Module SHALL expose every Token_Set member as a `static const` Dart value so that every token is a compile-time constant and no token allocation occurs at runtime.
10. THE Design_Tokens_Module SHALL be defined in Flutter files under `lib/core/theme/` and SHALL NOT contain any Dart `import`, `export`, or `part` directive, nor any asset path, that resolves into `UI Improvement Suggestion/`.
11. THE Design_Tokens_Module SHALL expose a motion Token_Set with the named `Duration` values `fast = 150ms`, `normal = 300ms`, `slow = 500ms`, and the named `Curve` values `standard = Curves.easeInOut` and `emphasized = Curves.easeOutCubic`.
12. THE Design_Tokens_Module SHALL declare every Token_Set class field as `static const` with no public setter or mutator, so that any attempted reassignment fails at compile time.

### Requirement 2: Light and Dark Theme Generation

**User Story:** As a user, I want the app to render correctly in both light and dark modes using the new design tokens, so that the UI feels consistent and readable in any lighting condition.

#### Acceptance Criteria

1. THE Flutter_App SHALL produce a `Light_Theme` `ThemeData` whose background is exactly `#FFFFFF`, foreground is exactly `#111827`, card surface is exactly `#FFFFFF`, muted surface is exactly `#ECECF0`, and border is exactly `rgba(0,0,0,0.1)`, matching the `:root` block in `UI Improvement Suggestion/src/styles/theme.css` with no tolerance.
2. THE Flutter_App SHALL produce a `Dark_Theme` `ThemeData` whose background, card, and popover surfaces use the sRGB conversions of `oklch(0.145 0 0)`, foreground uses the sRGB conversion of `oklch(0.985 0 0)`, and borders use the sRGB conversion of `oklch(0.269 0 0)`, each within ±1 per 8-bit channel of the standard OKLCH-to-sRGB reference conversion.
3. WHEN `Theme_Service.themeMode` equals `ThemeMode.light`, THE Flutter_App SHALL apply the Light_Theme to the `MaterialApp` on the next frame after the value change.
4. WHEN `Theme_Service.themeMode` equals `ThemeMode.dark`, THE Flutter_App SHALL apply the Dark_Theme to the `MaterialApp` on the next frame after the value change.
5. WHEN `Theme_Service.themeMode` equals `ThemeMode.system`, THE Flutter_App SHALL select Light_Theme or Dark_Theme based on the current value of `MediaQuery.platformBrightnessOf(context)` and SHALL re-evaluate that selection on every framework-reported platform brightness change.
6. WHEN `Theme_Service.setPrimaryColor(color)` is called with one of the colors in `ThemeService.presets`, THE Flutter_App SHALL rebuild both Light_Theme and Dark_Theme as a single state update using that color as the seed for the gradient brand palette while keeping all other tokens unchanged, so that no observer ever sees only one of the two themes updated.
7. IF `Theme_Service.setPrimaryColor(color)` is called with a color that is not in `ThemeService.presets`, THEN THE Flutter_App SHALL reject the call, retain the previously applied Light_Theme and Dark_Theme without modification, and surface an error indication to the caller.
8. IF the atomic theme rebuild from acceptance criterion 6 fails for any reason, THEN THE Flutter_App SHALL retain the previously applied Light_Theme and Dark_Theme without partial updates.
9. THE Flutter_App SHALL complete the theme rebuild defined in acceptance criterion 6 within 200 milliseconds on the target device, measured from the call returning to the next applied frame.
10. THE Light_Theme and Dark_Theme SHALL register every typography Token_Set entry from Requirement 1 onto `ThemeData.textTheme` such that for each named entry the registered `TextStyle` has the same `fontSize` and `fontWeight` as the Token_Set definition.
11. THE Light_Theme and Dark_Theme SHALL register a `ThemeExtension` containing non-null instances of `AppColors`, `AppSpacing`, `AppRadii`, `AppShadows`, and `AppMotion`, each exposing every token defined in Requirement 1, accessible via `Theme.of(context).extension<...>()`.

### Requirement 3: Reusable Component Library

**User Story:** As a Flutter developer, I want a reusable component library that mirrors the visual primitives in the Reference_Source, so that screens compose redesigned UI without duplicating styling logic.

#### Acceptance Criteria

1. THE Flutter_App SHALL define the Component_Library under `lib/widgets/ui/` with at minimum the following widgets: `AppPrimaryButton`, `AppSecondaryButton`, `AppIconButton`, `AppGradientButton`, `AppTextField`, `AppBadge`, `AppFeedbackBanner`, `AppCard`, `AppListTile`, `AppSectionHeader`, `AppFloatingBottomNav`, `AppBottomSheet`, `AppEmptyState`, `AppSkeletonLoader`, `AppSpinner`, `AppToggleSwitch`, `AppCategoryChip`, `AppHealthGauge`, `AppPhoneStatusBar`.
2. THE `AppPrimaryButton` widget SHALL render a gradient background from `AppColors.emerald500` to `AppColors.teal400` that is visible while the button is in the enabled state, and SHALL animate to a 0.98x scale only while the button is in the pressed state and return to 1.0x scale on release, with each scale transition completing in between 80 and 200 milliseconds inclusive.
3. THE `AppTextField` widget SHALL render a 2-logical-pixel border using `AppColors.border` in the resting state.
4. WHEN the `AppTextField` widget is focused, THE widget SHALL render its 2-logical-pixel border using `AppColors.emerald500`.
5. WHEN the `AppTextField` widget is supplied with a non-empty error string, THE widget SHALL render its 2-logical-pixel border using `AppColors.error` and display the error string below the field.
6. WHILE the `AppTextField` widget's `enabled` property is false, THE widget SHALL reject all pointer and keyboard input.
7. THE `AppFeedbackBanner` widget SHALL accept a `kind` enum value of `success`, `error`, `warning`, or `info` and SHALL apply the corresponding semantic background, border, and icon colors from the color Token_Set.
8. THE `AppFloatingBottomNav` widget SHALL render a translucent floating pill with a backdrop blur sigma between 10 and 20 logical pixels inclusive, SHALL support 3 to 5 items inclusive where each item occupies an equal share of the pill's content width, and SHALL highlight the active item with the gradient brand fill.
9. THE `AppBottomSheet` widget SHALL render a top drag handle, rounded top corners with `AppRadii.large`, and SHALL animate in from the bottom with a duration between 200 and 350 milliseconds inclusive.
10. WHEN any Component_Library widget is rendered with a touch-interactive surface, THE widget SHALL guarantee a minimum tappable area of `Touch_Target_Floor` (48 by 48 logical pixels).
11. THE Component_Library widgets SHALL read every visual constant (color, spacing, border radius, typography size, elevation, and animation duration) from the Design_Tokens_Module and SHALL NOT contain hard-coded hex color, spacing, radius, typography, or duration literals for tokens that exist in the Token_Sets.
12. WHILE any of `AppPrimaryButton`, `AppSecondaryButton`, `AppIconButton`, or `AppGradientButton` is in the disabled state, THE widget SHALL render with the disabled visual treatment defined in the Token_Set and SHALL NOT respond to tap, press, or long-press gestures.

### Requirement 4: Home Screen Redesign

**User Story:** As a user, I want the home cockpit screen to match the improved Figma mockup, so that I see a clearer greeting, vehicle health visualization, wallet/vault row, upcoming appointment card, and quick actions.

#### Acceptance Criteria

1. THE `home_screen.dart` Improved_Screen SHALL render a time-based greeting using a `getGreeting()` function that, given the device local hour `h` in the range `0..23`, returns `Good morning` for `6 <= h <= 11`, `Good afternoon` for `12 <= h <= 17`, and `Good evening` for `h >= 18 OR h <= 5`, concatenated with a single space and the current user's first name as `"<greeting>, <firstName>"`.
2. IF `ProfileService` returns a null or empty first name, THEN THE `home_screen.dart` Improved_Screen SHALL render the greeting concatenated with the literal `"there"`.
3. THE `home_screen.dart` Improved_Screen SHALL render a circular vehicle health gauge using `AppHealthGauge` whose displayed percentage equals the value produced by `VehicleInsights`, clamped to the inclusive range `[0, 100]`.
4. IF `VehicleInsights` returns no value or surfaces an error, THEN THE `home_screen.dart` Improved_Screen SHALL render the `AppHealthGauge` in a placeholder state showing `--%` instead of a numeric value.
5. THE `home_screen.dart` Improved_Screen SHALL render the wallet card and vault card in a single horizontal row composed of three equal-width columns, with the wallet card spanning columns 1-2 and the vault card occupying column 3.
6. THE `home_screen.dart` Improved_Screen SHALL render the bottom navigation as an `AppFloatingBottomNav` containing five entries in this exact order: `Cockpit`, `Shops`, `My Car`, `Refuel`, `Wallet`, with `Cockpit` selected by default, and SHALL update `HomeScreen.activeTabNotifier` with the matching index value when an entry is tapped.
7. WHEN the user taps the wallet `Top Up` action, THE `home_screen.dart` Improved_Screen SHALL invoke the existing `WalletTopUpSheet` flow without modification to its underlying ToyyibPay payload.
8. WHILE a `WalletTopUpSheet` invocation triggered from acceptance criterion 7 is in flight, THE `home_screen.dart` Improved_Screen SHALL ignore additional taps on the wallet `Top Up` action so that exactly one sheet is presented per user-initiated tap.
9. WHEN the `home_screen.dart` Improved_Screen first mounts after a fresh install, IF the `has_seen_onboarding_guide` SharedPreferences key is unset or false, THEN THE `home_screen.dart` Improved_Screen SHALL present the existing onboarding guide once and SHALL set the `has_seen_onboarding_guide` SharedPreferences key to true.
10. WHEN the `home_screen.dart` Improved_Screen mounts and the `has_seen_onboarding_guide` SharedPreferences key is true, THE `home_screen.dart` Improved_Screen SHALL NOT present the onboarding guide.
11. THE `home_screen.dart` Improved_Screen SHALL render an upcoming-appointment card showing the next confirmed booking title, date, and time when at least one upcoming booking exists, and SHALL render an empty-appointment placeholder otherwise.
12. THE `home_screen.dart` Improved_Screen SHALL render a quick-actions row containing entries that link to the `Refuel`, `Workshops`, `Vault`, and `Wallet` flows using the same navigation handlers already wired in the existing `home_screen.dart`.

### Requirement 5: Login and Register Screen Redesign

**User Story:** As a user signing in or registering, I want the redesigned login and register screens, so that I see a hero illustration, modern input fields, password visibility toggle, social login affordances, and a clear sign-up call to action.

#### Acceptance Criteria

1. THE `login_screen.dart` Improved_Screen SHALL render a hero block positioned above the form, containing a 128x128 logical-pixel square with a 24-logical-pixel corner radius, filled with the brand gradient defined in the `Improved` mockup of `LoginComparison.tsx`, and displaying a centered car emoji.
2. THE `login_screen.dart` Improved_Screen SHALL render an `EMAIL ADDRESS` `AppTextField` with a leading email icon and a 2-logical-pixel border, and a `PASSWORD` `AppTextField` with a leading lock icon and a 2-logical-pixel border, matching the `Improved` mockup in `LoginComparison.tsx`.
3. WHEN the `login_screen.dart` Improved_Screen is first displayed, THE `login_screen.dart` Improved_Screen SHALL render the `PASSWORD` `AppTextField` in obscured state with the visibility toggle icon set to the show-password indicator.
4. WHEN the user taps the password visibility toggle on the `login_screen.dart` Improved_Screen, THE `login_screen.dart` Improved_Screen SHALL toggle the `PASSWORD` `AppTextField` between obscured and revealed states, SHALL update the visibility toggle icon to reflect the new state, and SHALL preserve the entered password value across the toggle.
5. WHEN the user taps the `Sign In` `AppGradientButton` on the `login_screen.dart` Improved_Screen, THE `login_screen.dart` Improved_Screen SHALL invoke the existing Firebase `signInWithEmailAndPassword` call using the values entered in the `EMAIL ADDRESS` and `PASSWORD` fields, and SHALL preserve the existing success-navigation and error-handling behavior.
6. IF the user taps the `Sign In` `AppGradientButton` while the `EMAIL ADDRESS` or `PASSWORD` field is empty, THEN THE `login_screen.dart` Improved_Screen SHALL suppress the Firebase `signInWithEmailAndPassword` call, SHALL display an inline validation message identifying which required field is missing, and SHALL preserve any already-entered values.
7. WHILE a `signInWithEmailAndPassword` call initiated from acceptance criterion 5 is in flight, THE `login_screen.dart` Improved_Screen SHALL render the `Sign In` `AppGradientButton` in a loading state and SHALL ignore additional taps on that button.
8. WHEN the user taps the `Forgot password?` link on the `login_screen.dart` Improved_Screen, THE `login_screen.dart` Improved_Screen SHALL trigger the existing password reset flow without modifying the values entered in the `EMAIL ADDRESS` or `PASSWORD` fields.
9. WHEN the user taps the `Sign up free` link on the `login_screen.dart` Improved_Screen, THE `login_screen.dart` Improved_Screen SHALL navigate to `register_screen.dart`.
10. THE `register_screen.dart` Improved_Screen SHALL adopt the same hero block, typography scale, `AppTextField` styling, and `AppGradientButton` components as the `login_screen.dart` Improved_Screen, while preserving the existing registration form fields and the existing Firebase create-user behavior.
11. WHERE the device exposes biometric authentication and a biometric session token is already stored, THE `login_screen.dart` Improved_Screen SHALL render a `Biometric` social-style button.
12. WHEN the user taps the `Biometric` button rendered by acceptance criterion 11, THE `login_screen.dart` Improved_Screen SHALL trigger the existing biometric login flow.
13. WHERE the device does not expose biometric authentication or no biometric session token is stored, THE `login_screen.dart` Improved_Screen SHALL NOT render the `Biometric` button.

### Requirement 6: Settings Screen Redesign

**User Story:** As a user, I want the redesigned settings screen, so that I can manage profile, appearance, notifications, privacy, data, preferences, about, and logout in clearly grouped sections.

#### Acceptance Criteria

1. THE `settings_screen.dart` Improved_Screen SHALL render the following grouped sections in this exact order: `PROFILE`, `APPEARANCE`, `NOTIFICATIONS`, `PRIVACY & SECURITY`, `DATA & STORAGE`, `PREFERENCES`, `ABOUT & SUPPORT`, and a final `Sign Out` button, mirroring the section structure of `SettingsImproved.tsx`.
2. THE `PROFILE` section SHALL render an avatar with an overlay camera button, an inline display-name `AppTextField` accepting 1 to 50 characters inclusive, an inline phone `AppTextField` accepting 7 to 15 digits inclusive, and a `Save Profile` `AppGradientButton`, all bound to the existing `ProfileService` data.
3. WHILE any field in the `PROFILE` section differs from the value persisted by `ProfileService`, THE `settings_screen.dart` Improved_Screen SHALL render an unsaved-changes `AppFeedbackBanner` of kind `warning` at the top of the scroll view; once the persisted value matches the field values (whether by save or revert), THE banner SHALL be removed.
4. THE `APPEARANCE` section SHALL render an `AppToggleSwitch` for dark mode and a 4-column color picker grid containing the eight colors from `ThemeService.presets` rendered as gradient swatches matching the `colors` array in `SettingsImproved.tsx`.
5. WHEN the user selects a swatch, THE `settings_screen.dart` Improved_Screen SHALL invoke `ThemeService.setPrimaryColor(...)` and SHALL render a checkmark on exactly the currently selected swatch, removing any checkmark from previously selected swatches.
6. THE `NOTIFICATIONS` section SHALL render `AppToggleSwitch` controls for Maintenance Reminders, Booking Confirmations, and Weekly Reports, and WHEN the user toggles any of them, THE `settings_screen.dart` Improved_Screen SHALL persist the new state through the existing notification preference store.
7. WHEN the user taps the `Sign Out` button, THE `settings_screen.dart` Improved_Screen SHALL present an `AppBottomSheet` confirmation modal with `Cancel` and `Sign Out` buttons.
8. WHEN the user taps `Cancel` in the sign-out `AppBottomSheet`, THE `settings_screen.dart` Improved_Screen SHALL dismiss the sheet without changing the authentication state or navigation stack.
9. WHEN the user taps `Sign Out` in the sign-out `AppBottomSheet`, THE `settings_screen.dart` Improved_Screen SHALL trigger the existing Firebase sign-out flow and, on success, navigate to the existing authentication entry screen.
10. IF the `Save Profile` `AppGradientButton` action fails to persist through `ProfileService`, THEN THE `settings_screen.dart` Improved_Screen SHALL render an `AppFeedbackBanner` of kind `error` and SHALL retain the user's edited field values for retry.

### Requirement 7: Workshops Screens Redesign

**User Story:** As a user looking for a workshop, I want the redesigned workshops list, map, and detail screens, so that I can browse, search, filter, favorite, and book with the improved visuals.

#### Acceptance Criteria

1. THE `workshop_map_screen.dart` Improved_Screen SHALL render a top tab switcher with `Browse` and `My Bookings` tabs styled per the section structure of `WorkshopImproved.tsx`, with `Browse` selected by default.
2. THE `Browse` tab SHALL render a search `AppTextField` with a leading magnifier icon and a trailing filter `AppIconButton`, plus a horizontally scrolling row of `AppCategoryChip` entries for `All`, `Repair`, `Car Wash`, and `Parts`, with `All` selected by default and exactly one chip selected at any time.
3. THE `Browse` tab SHALL display the rendered list of workshops filtered to those whose name contains the search text as a case-insensitive substring AND whose category equals the selected chip's value (or all categories when `All` is selected).
4. THE `Browse` tab SHALL render a list/map `viewMode` toggle with `list` selected by default, and SHALL display either the existing list of `Workshop` cards or the existing `GoogleMap` view based on the toggle state.
5. THE `Workshop` card SHALL render the workshop image, name, rating badge, review count, open/closed status, distance, price range, up to two specialty chips with a `+N more` overflow indicator (where `N` equals the number of additional specialties), and dual `Navigate` and `Book Now` action buttons.
6. WHEN the user taps the heart icon on a `Workshop` card, THE `workshop_map_screen.dart` Improved_Screen SHALL toggle the workshop's favorite state in persistent storage and SHALL update the icon fill within 100 milliseconds.
7. IF the favorite-state persistence in acceptance criterion 6 fails, THEN THE `workshop_map_screen.dart` Improved_Screen SHALL revert the icon fill to its previous state and surface an error indication.
8. WHEN the user taps a `Workshop` card body, THE Flutter_App SHALL present `workshop_detail_screen.dart` as an `AppBottomSheet` covering at least 80 percent of the viewport height.
9. THE `workshop_detail_screen.dart` Improved_Screen SHALL render a quick-info grid containing `Status` and `Distance` tiles, a services-offered chip cloud, an opening-hours list, and a footer with `Call` and `Book Now` action buttons.
10. WHEN the user taps the `Call` action on `workshop_detail_screen.dart`, THE Flutter_App SHALL invoke the existing telephony flow.
11. WHEN the user taps the `Book Now` action on `workshop_detail_screen.dart`, THE Flutter_App SHALL invoke the existing booking flow.
12. IF the search and filter combination on the `Browse` tab yields zero matching workshops, THEN THE `Browse` tab SHALL render an empty-state message indicating no results match the current search and filter, while keeping the search field and chip row visible and interactive.
13. WHEN the `My Bookings` tab is active and at least one confirmed booking exists, THE `My Bookings` tab SHALL render confirmed-booking cards with `Reschedule` and `Cancel` buttons that invoke the existing booking-management actions.
14. WHEN the `My Bookings` tab is active and no confirmed bookings exist, THE `My Bookings` tab SHALL render an empty state with a `Browse Workshops` call to action; exactly one of the populated and empty states SHALL be visible at any time.

### Requirement 8: Vehicle and Vehicle Customizer Screens Redesign

**User Story:** As a user managing my car, I want the redesigned vehicle and customizer screens, so that I see a hero vehicle card, health metrics, maintenance history, and upcoming tasks with the improved visuals.

#### Acceptance Criteria

1. THE `vehicle_screen.dart` Improved_Screen SHALL render a hero vehicle card with a linear gradient from `#2563EB` (blue-600) at the top-left to `#4338CA` (indigo-700) at the bottom-right, the car emoji, plate number, and an `Edit` `AppIconButton` overlay positioned in the top-right corner.
2. THE `vehicle_screen.dart` Improved_Screen SHALL render a four-tile health metrics grid for `Engine`, `Brakes`, `Battery`, and `Tires` whose percentage values are pulled from the existing `VehicleInsights` source and clamped to the inclusive range `[0, 100]`.
3. IF a health metric value from `VehicleInsights` is unavailable or surfaces an error, THEN the corresponding tile SHALL render `--%` instead of a numeric value.
4. THE `vehicle_screen.dart` Improved_Screen SHALL render a maintenance history list whose entries match the existing maintenance data source and use `AppListTile` styling, ordered from most recent to oldest.
5. THE `vehicle_screen.dart` Improved_Screen SHALL render an upcoming tasks list with a priority indicator per task whose color encoding distinguishes `high`, `medium`, and `low` priorities through three distinct semantic colors.
6. IF the maintenance history list contains zero entries, THEN THE `vehicle_screen.dart` Improved_Screen SHALL render an empty-state message in place of the list.
7. IF the upcoming tasks list contains zero entries, THEN THE `vehicle_screen.dart` Improved_Screen SHALL render an empty-state message in place of the list.
8. WHEN the user taps the hero card `Edit` `AppIconButton`, THE Flutter_App SHALL present `vehicle_customizer_screen.dart` using the redesigned design tokens while preserving the existing customizer logic and persistence.
9. THE `vehicle_customizer_screen.dart` Improved_Screen SHALL apply `AppPrimaryButton`, `AppGradientButton`, `AppTextField`, `AppCard`, and `AppFeedbackBanner` from the Component_Library, while keeping its existing form fields, validation rules, and save behavior unchanged.

### Requirement 9: Refuel Log Screen Redesign

**User Story:** As a user logging fuel, I want the redesigned refuel screen, so that I can quickly add entries, browse history, and view efficiency insights using the new visual style.

#### Acceptance Criteria

1. THE `refuel_log_screen.dart` Improved_Screen SHALL render a top tab switcher with `Log`, `History`, and `Insights` tabs, with the `Log` tab selected by default on screen open.
2. THE `Log` tab SHALL render `AppTextField` instances for distance in kilometers, liters, and price-per-liter that accept positive decimal numeric input only, plus an `AppCategoryChip` row for fuel type with the presets `Budi95`, `RON95`, `RON97`, and `Diesel`, each chip carrying its preset price displayed below the label.
3. WHEN the user selects a fuel type chip, THE `refuel_log_screen.dart` Improved_Screen SHALL pre-fill the price-per-liter `AppTextField` with the selected preset value while keeping the field editable, overwriting any previously entered value in that field.
4. WHEN the user taps the `Save Refuel` `AppGradientButton` and all three numeric fields contain values greater than zero and a fuel type chip is selected, THE `refuel_log_screen.dart` Improved_Screen SHALL persist the entry through the existing refuel-log database service and reset the form to its initial empty state.
5. IF the user taps the `Save Refuel` `AppGradientButton` while any of distance, liters, or price-per-liter is empty, non-numeric, or not greater than zero, or no fuel type chip is selected, THEN THE `refuel_log_screen.dart` Improved_Screen SHALL display an inline validation indicator on each invalid input and SHALL NOT invoke the refuel-log database service.
6. IF the refuel-log database service fails to persist the entry, THEN THE `refuel_log_screen.dart` Improved_Screen SHALL display an error indicator informing the user that the save failed and SHALL retain the entered field values for retry.
7. THE `History` tab SHALL render the existing refuel-log entries as `AppCard` items showing date, distance in kilometers, liters, fuel type chip, efficiency in km/L computed as distance divided by liters, total cost, and station when available, ordered from most recent to oldest.
8. WHEN the refuel-log database service returns zero entries on the `History` tab, THE `History` tab SHALL render an empty-state message indicating no refuel entries yet.
9. THE `Insights` tab SHALL render the existing `FuelChart` widget wrapped in an `AppCard` with the redesigned typography and spacing, preserving the chart's data source and computations.
10. WHEN the refuel-log database service returns zero entries on the `Insights` tab, THE `Insights` tab SHALL render an empty-state message in place of the chart.

### Requirement 10: Document Vault Screen Redesign

**User Story:** As a user storing documents, I want the redesigned vault, so that I can browse, search, filter, and add documents with the improved visuals.

#### Acceptance Criteria

1. THE `document_vault_screen.dart` Improved_Screen SHALL render a top search `AppTextField` and an `AppCategoryChip` row for `All`, `Insurance`, `Tax`, `Receipt`, and `Warranty`, with the `All` chip selected by default, exactly one chip selected at any time, and the displayed document list filtered to documents whose title contains the search text as a case-insensitive substring AND whose category equals the selected chip's value (or all categories when `All` is selected).
2. THE `document_vault_screen.dart` Improved_Screen SHALL render a list/grid `viewMode` toggle with `list` selected by default, and WHEN the user taps the toggle, THE Screen SHALL switch the document layout between list and grid views and retain the chosen mode for the remainder of the current screen session.
3. THE `document_vault_screen.dart` Improved_Screen SHALL render each document as an `AppCard` showing the document title (truncated with an ellipsis when longer than the card's single-line width), a category badge for one of `Insurance`, `Tax`, `Receipt`, or `Warranty`, the expiry date (or a `No expiry` label when `expiryDate` is null), the file size formatted with unit `B`, `KB`, or `MB`, and an expiry-status indicator.
4. WHEN a document's `expiryDate` is within 30 days of the current date in either direction (upcoming within 30 days or expired within the last 30 days), THE document card SHALL display its expiry-status indicator using the `warning` semantic color.
5. IF a document's `expiryDate` is more than 30 days before the current date, THEN THE document card SHALL display its expiry-status indicator using the `error` semantic color.
6. WHEN the user taps the floating add button, THE `document_vault_screen.dart` Improved_Screen SHALL present an `AppBottomSheet` containing the existing add-document form, preserving the upload, validation, and Firestore persistence behavior.
7. IF the add-document submission within the `AppBottomSheet` fails due to validation or Firestore persistence error, THEN THE `document_vault_screen.dart` Improved_Screen SHALL keep the bottom sheet open with the user's entered values retained and display an error indication identifying the cause of failure.

### Requirement 11: Wallet History Screen Redesign

**User Story:** As a user reviewing my wallet, I want the redesigned wallet screen, so that I see balance, transactions, and insights with the improved visuals.

#### Acceptance Criteria

1. THE `wallet_history_screen.dart` Improved_Screen SHALL render a hero balance card that displays the current wallet balance with currency formatting, uses the gradient brand fill, and contains a `Top Up` `AppGradientButton`.
2. WHEN the `wallet_history_screen.dart` Improved_Screen first opens, THE Screen SHALL render a top tab switcher with `Overview`, `Transactions`, and `Insights` tabs and SHALL set `Overview` as the active tab.
3. THE `Transactions` tab SHALL render each transaction as an `AppListTile` with a leading icon whose color is one of three distinct colors mapped one-to-one to the transaction `type` values `top-up`, `payment`, and `refund`, and SHALL render a status badge whose label and visual treatment are one of three distinct treatments mapped one-to-one to the `status` values `completed`, `pending`, and `failed`.
4. THE `Transactions` tab SHALL render an `AppCategoryChip` filter row with `All`, `Top-up`, `Payment`, and `Refund` filters, SHALL set `All` as the active filter on first render, and WHEN the user taps a filter chip, THE Tab SHALL update the rendered list locally from the already-loaded transactions without issuing a new fetch.
5. WHEN the user taps the hero `Top Up` button, THE `wallet_history_screen.dart` Improved_Screen SHALL invoke the existing `WalletTopUpSheet` flow.
6. IF the `WalletTopUpSheet` flow fails to launch from acceptance criterion 5, THEN THE `wallet_history_screen.dart` Improved_Screen SHALL render an `AppFeedbackBanner` of kind `error` indicating that the top-up flow could not be opened, SHALL keep the user on the wallet screen, and SHALL preserve the currently selected tab and filter selection.
7. IF the filtered transactions list contains zero items after applying the active filter, THEN THE `Transactions` tab SHALL render an empty-state message indicating that no transactions match the selected filter and SHALL keep the `AppCategoryChip` filter row visible and interactive.
8. WHILE the wallet balance or transactions data is loading on first open or refresh, THE `wallet_history_screen.dart` Improved_Screen SHALL render a loading indicator in place of the affected section and SHALL NOT render partial or stale values for that section.

### Requirement 12: Consistency Across Screens Without Mockups

**User Story:** As a user, I want every screen in the app to feel like it belongs to the same redesigned system, so that screens without dedicated Figma mockups still adopt the new tokens, typography, and component primitives.

#### Acceptance Criteria

1. THE `booking_screen.dart`, `journey_log_screen.dart`, `maintenance_screen.dart`, `notifications_screen.dart`, `splash_screen.dart`, `toyyibpay_webview_screen.dart`, `trip_planner_screen.dart`, and `trip_tracking_screen.dart` files SHALL read every color, typography style, spacing value, and border radius from the Design_Tokens_Module, and SHALL NOT contain hard-coded hex color, spacing, radius, or typography literals for tokens that exist in the Token_Sets.
2. WHERE an Unmocked_Screen contains a Material `ElevatedButton`, `TextField`, `Card`, or `AppBar` whose styling and behavior are equivalent to a Component_Library widget (`AppPrimaryButton`/`AppGradientButton`/`AppSecondaryButton`, `AppTextField`, `AppCard`, `AppSectionHeader`), THE Unmocked_Screen SHALL render the corresponding Component_Library widget instead of the Material widget.
3. WHERE an Unmocked_Screen contains a Material widget for which no Component_Library counterpart exists, THE Unmocked_Screen SHALL retain the Material widget but apply the Design_Tokens_Module values for color, typography, spacing, and radii to align it visually with the redesign.
4. WHERE an Unmocked_Screen renders a button as the screen's primary call-to-action (the most visually emphasized actionable button on that screen), THE button SHALL be rendered as `AppGradientButton`.
5. WHERE an Unmocked_Screen renders a status, success, error, warning, or info banner, THE banner SHALL be rendered through `AppFeedbackBanner` using the matching semantic color from the color Token_Set.
6. THE Unmocked_Screens SHALL preserve the same data sources, controllers, listeners, navigation calls, and navigation arguments as the pre-redesign implementation.

### Requirement 13: Accessibility Floors

**User Story:** As a user relying on assistive features, I want the redesigned UI to meet baseline accessibility floors, so that text remains readable and controls remain usable.

#### Acceptance Criteria

1. THE Flutter_App SHALL render every body text through `AppTypography.body` or a larger `AppTypography` variant, where `body` has a base font size of no less than 12 logical pixels at the platform default text scale.
2. THE Flutter_App SHALL render every label or badge through `AppTypography.label` or a larger `AppTypography` variant, where `label` has a base font size of no less than 10 logical pixels at the platform default text scale.
3. THE Flutter_App SHALL render every interactive surface (buttons, tiles, toggles, chips, navigation items) with a tappable hit area of at least `Touch_Target_Floor` (48 by 48 logical pixels), and WHERE the visual element is smaller than 48x48 logical pixels, THE Flutter_App SHALL extend the hit area to meet the floor.
4. THE Flutter_App SHALL maintain at least 8 logical pixels of horizontal or vertical spacing between adjacent interactive hit areas to prevent overlapping or adjacent mis-taps.
5. THE Flutter_App SHALL render every text-on-background pair in default, pressed, focused, and selected states with a contrast ratio of at least 4.5:1 in both Light_Theme and Dark_Theme, computed using the WCAG 2.1 relative luminance formula, with an exception that text rendered at 18 logical pixels or 14 logical pixels bold or larger SHALL meet at least 3:1, and disabled text SHALL be exempt.
6. IF a text-on-background pair fails the contrast threshold from acceptance criterion 5, THEN THE Flutter_App SHALL fail its accessibility lint or static-check step before merging.
7. THE Flutter_App SHALL render every text element so that it reflows onto additional lines without truncation in the redesigned layouts at the platform default text scale and at platform-level text scaling factors in the inclusive range `[1.0, 2.0]`, by routing typography Token_Set entries through the `MediaQuery.textScaler` chain.
8. THE Flutter_App SHALL render every icon-only interactive control with a non-empty `Semantics.label` describing its action, so that assistive technology can announce the control by name.
9. THE Flutter_App SHALL render a visible focus indicator on every interactive control when that control receives keyboard or directional focus, with the indicator using a contrasting color from the color Token_Set.

### Requirement 14: Functional Preservation

**User Story:** As a user of the existing application, I want my data, sessions, and integrations to keep working through the redesign, so that the visual change does not regress any feature.

#### Acceptance Criteria

1. WHEN a user or app code navigates to an existing route name, THE Flutter_App SHALL resolve that route to the corresponding Improved_Screen or Unmocked_Screen and apply the same navigation transition direction and back-stack behavior as the pre-redesign implementation.
2. WHEN a user submits sign-in, sign-up, sign-out, or password-reset, THE Flutter_App SHALL invoke the existing Firebase Authentication methods with the same input fields and produce the same authentication state outcomes (signed-in, signed-out, reset-email-sent) and same error categories as the pre-redesign implementation.
3. WHEN a redesigned screen performs a Firestore read or write, THE Flutter_App SHALL invoke the same `WorkshopFirebaseService`, `JourneyDatabase`, `CarDatabase`, `MarketplaceRepository`, or `ProfileService` method with parameters of the same type and persist or retrieve documents containing the same field set as the pre-redesign implementation.
4. WHEN a user initiates a ToyyibPay top-up, THE Flutter_App SHALL submit bill-creation requests with the same parameters and route the payment callback through `ToyyibpayWebviewScreen`, producing the same success and failure outcomes as the pre-redesign implementation.
5. WHEN a workshop or trip-tracking screen displays a map, THE Flutter_App SHALL render the same marker set, apply the same camera positioning logic, and draw the same route polylines as the pre-redesign implementation.
6. WHEN `HomeScreen.initState` runs, THE Flutter_App SHALL invoke `ActivityRecognitionService`, `LocationTracker`, and the journey-tracking lifecycle hooks in the same order and at the same lifecycle point as the pre-redesign implementation.
7. THE Flutter_App SHALL read and write the SharedPreferences keys `theme_primary_color`, `theme_mode_index`, and `has_seen_onboarding_guide` using the same key names and the same value type and encoding as the pre-redesign implementation, without performing data migration.
8. IF a redesigned widget cannot host an existing user-invocable action within its native layout, THEN THE Flutter_App SHALL expose that action through an alternate control on the same screen that triggers the same handler and produces the same observable outcome, rather than removing the action.
9. WHEN a redesigned screen loads data that was persisted by the pre-redesign implementation, THE Flutter_App SHALL accept that data without requiring a schema migration and display it through the redesigned controls.
10. IF a service call, Firestore operation, or SharedPreferences read that succeeded with identical input in the pre-redesign implementation fails after redesign, THEN THE Flutter_App SHALL surface an error indicator on the affected screen and retain the previously persisted data unchanged.

### Requirement 15: Reference-Only Source Folder

**User Story:** As a maintainer, I want the `UI Improvement Suggestion/` folder to remain a reference-only artifact, so that no React, TypeScript, or Tailwind dependency leaks into the production Flutter build.

#### Acceptance Criteria

1. THE Flutter_App SHALL NOT reference any file under `UI Improvement Suggestion/` through Dart `import`, `export`, or `part` directives, nor through any runtime file or asset loading API.
2. THE Flutter_App's `pubspec.yaml` SHALL NOT contain any `assets`, `flutter_assets`, font, or platform-specific bundle entry whose resolved path falls within `UI Improvement Suggestion/`.
3. THE `.gitignore` file SHALL retain the existing `UI Improvement Suggestion/` ignore entry, AND the redesign SHALL NOT remove or alter that entry.
4. WHERE a Reference_Source value (such as a color, spacing token, string, or component layout) is reproduced inside the Flutter codebase, THE reproduction SHALL be authored directly as a Dart constant or Dart widget within the `lib/` tree, with no build step, code generator, or script that reads from any file under `UI Improvement Suggestion/`.
5. THE Flutter_App SHALL include a static check (Dart analyzer rule, custom lint, or CI script) that, on every `dart analyze`, pre-commit hook, and CI pipeline run, scans for Dart imports, `pubspec.yaml` asset entries, or runtime references resolving into `UI Improvement Suggestion/`.
6. IF the static check from criterion 5 detects any such Dart import, asset entry, or runtime reference into `UI Improvement Suggestion/`, THEN THE CI pipeline SHALL exit with a non-zero status and SHALL block the merge until the violating reference is removed.
