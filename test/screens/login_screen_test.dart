// Feature: figma-ui-redesign — Widget tests for the redesigned
// `LoginScreen`.
//
// Validates:
//   * Requirement 5.1  — Hero block (128 x 128, AppRadii.large gradient
//                        tile, centred 🚗 emoji).
//   * Requirement 5.2  — Email + password AppTextFields with prefix
//                        icons.
//   * Requirement 5.3  — Initial password obscured + visibility-toggle
//                        icon shows the "show password" indicator.
//   * Requirement 5.5  — Sign In is an AppGradientButton whose tap
//                        runs the sign-in flow.
//   * Requirement 5.6  — Empty-field validation suppresses the Firebase
//                        call and surfaces inline error text identifying
//                        the missing field.
//   * Requirement 5.8  — Forgot password handler does not modify the
//                        entered field values.
//   * Requirement 5.9  — Sign up free pushes the RegisterScreen route.
//   * Requirement 5.13 — Biometric button is omitted when neither
//                        precondition (device biometric capability +
//                        stored session token) holds.
//
// Why a partial-mount approach instead of a full Firebase mock:
//   * `LoginScreen._login` reaches into Firebase
//     (`FirebaseAuth.instance.signInWithEmailAndPassword`). The
//     `firebase_auth` plugin channels are not registered in
//     `flutter test`, so any code path that reaches the Firebase call
//     will throw a `MissingPluginException` (the screen catches the
//     throw in its offline-fallback branch and ultimately calls
//     `Navigator.pushReplacementNamed(HomeScreen.routeName)`).
//   * The tests below focus on the deterministic layers that do NOT
//     require Firebase: the visual layout (Requirements 5.1 / 5.2),
//     the password visibility toggle (Requirements 5.3 — Requirement
//     5.4 is exhaustively covered by `login_password_toggle_pbt_test`),
//     the empty-field validation that short-circuits BEFORE the
//     Firebase call (Requirement 5.6), the forgot-password no-op when
//     the email field is empty (Requirement 5.8), the route-push for
//     sign-up (Requirement 5.9), and the biometric default-hidden
//     branch (Requirement 5.13). Tests that would otherwise need to
//     observe a successful Firebase invocation are deliberately
//     omitted here — they are exercised at the screen level by
//     `login_signin_inflight_pbt_test.dart` (task 7.5) which uses a
//     dedicated Firebase-free harness.
//   * `_loadBiometricAvailability` schedules a read against
//     `SharedPreferences.getInstance()` from `initState`. Each test
//     calls `SharedPreferences.setMockInitialValues({})` before
//     pumping so the read resolves cleanly to a missing-token state
//     and `_biometricAvailable` stays `false` — the default-hidden
//     branch of Requirement 5.13.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/login_screen.dart';
import 'package:drive_care_plus/screens/register_screen.dart';
import 'package:drive_care_plus/widgets/ui/app_gradient_button.dart';
import 'package:drive_care_plus/widgets/ui/app_icon_button.dart';
import 'package:drive_care_plus/widgets/ui/app_secondary_button.dart';
import 'package:drive_care_plus/widgets/ui/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Test host: a MaterialApp with the design-token theme and routes table
// containing the Login and Register screens. This is the same shape as
// `test/widgets/ui/_test_host.dart`'s `hostApp` helper, extended with a
// `routes` table so the `Sign up free` link's `pushNamed` call resolves
// to a real route entry (Requirement 5.9). The Home route is wired to a
// neutral stub so any code path that reaches `pushReplacementNamed` for
// HomeScreen lands on the stub instead of bubbling up as a "no route
// defined" exception.
// ---------------------------------------------------------------------------

const String _kHomeStubText = 'home-stub';
const String _kRegisterStubText = 'register-stub';

/// Pumps the [LoginScreen] inside a MaterialApp configured with a routes
/// table. By default the Register route resolves to a stub Scaffold so
/// the `Sign up free` link navigation can be observed without dragging
/// the real RegisterScreen widget tree into the harness. Set
/// [useRealRegisterScreen] to `true` if a test needs to observe the
/// actual RegisterScreen render (none of the tests below need that —
/// the parity assertions live in `register_screen_test.dart`).
///
/// The default `flutter test` viewport is 800 x 600 logical pixels,
/// which is shorter than the rendered Login form (hero + heading +
/// body + 2 fields + forgot link + CTA + sign-up row). Setting a
/// deterministic 1080 x 1920 physical size matches the pattern used
/// by `home_widgets_test.dart` and brings every interactive element
/// into view so `tester.tap` doesn't fall outside the rendered area.
Future<void> _pumpLogin(
  WidgetTester tester, {
  bool useRealRegisterScreen = false,
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ThemeData theme =
      AppTheme.buildTheme(AppColors.emerald500, Brightness.light);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: LoginScreen.routeName,
      routes: <String, WidgetBuilder>{
        LoginScreen.routeName: (_) => const LoginScreen(),
        RegisterScreen.routeName: (_) => useRealRegisterScreen
            ? const RegisterScreen()
            : const Scaffold(body: Text(_kRegisterStubText)),
        '/home': (_) => const Scaffold(body: Text(_kHomeStubText)),
      },
    ),
  );
  // Pump once more to drain the post-frame microtask scheduled by
  // `_loadBiometricAvailability` against the mock SharedPreferences
  // store. Without this pump the biometric availability check is
  // still in flight and the widget tree may rebuild mid-test.
  await tester.pump();
}

void main() {
  // `SharedPreferences.getInstance()` is invoked from
  // `LoginScreen.initState` via `_loadBiometricAvailability`. Seed an
  // empty in-memory store so the call resolves to a missing-token
  // state (i.e. `_biometricAvailable == false`) — the default-hidden
  // branch of Requirement 5.13.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // -------------------------------------------------------------------
  // Hero block — Requirement 5.1.
  // -------------------------------------------------------------------
  group('Hero block', () {
    testWidgets(
      'renders 128 x 128 brand-gradient tile with the 🚗 emoji',
      (tester) async {
        await _pumpLogin(tester);

        // The 🚗 emoji is rendered with `AppTypography.display`. We use
        // a widget predicate so the assertion is robust to any future
        // wrapping widget that doesn't change the visible text.
        expect(
          find.byWidgetPredicate(
            (Widget w) => w is Text && w.data == '🚗',
          ),
          findsOneWidget,
          reason: 'Login hero must render the 🚗 emoji per Requirement 5.1.',
        );

        // The hero is the unique `Container` with both a 128-pixel
        // width and a 128-pixel height in the rendered tree. Searching
        // by exact box constraints from the rendered RenderBox keeps
        // the assertion independent of the surrounding layout.
        final Finder heroFinder = find.byWidgetPredicate(
          (Widget w) {
            if (w is! Container) return false;
            return w.constraints?.maxWidth == 128 &&
                w.constraints?.maxHeight == 128;
          },
        );
        // The Container is built inside `Center` so it produces exactly
        // one match in the rendered tree.
        expect(
          heroFinder,
          findsOneWidget,
          reason: 'Login hero must be a 128x128 Container per Requirement 5.1.',
        );

        // The decoration must declare the brand gradient and the
        // `AppRadii.large` (24-logical-pixel) corner radius.
        final Container hero = tester.widget<Container>(heroFinder);
        final BoxDecoration decoration = hero.decoration as BoxDecoration;
        expect(
          decoration.gradient,
          isA<LinearGradient>(),
          reason: 'Hero must use a LinearGradient per Requirement 5.1.',
        );
        final LinearGradient gradient = decoration.gradient as LinearGradient;
        expect(
          gradient.colors,
          containsAll(<Color>[AppColors.emerald500, AppColors.teal400]),
          reason: 'Hero gradient must run from emerald500 to teal400 per Requirement 5.1.',
        );
        expect(
          decoration.borderRadius,
          BorderRadius.circular(AppRadii.large),
          reason: 'Hero must use AppRadii.large corner radius per Requirement 5.1.',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Email + password fields — Requirement 5.2.
  // -------------------------------------------------------------------
  group('Form fields', () {
    testWidgets(
      'renders Email and Password AppTextFields with prefix icons',
      (tester) async {
        await _pumpLogin(tester);

        // Two AppTextFields must be present (email + password). Any
        // additional AppTextField would imply an extra unspecified
        // field, so the count is asserted to exactly two.
        expect(
          find.byType(AppTextField),
          findsNWidgets(2),
          reason: 'Login form must render exactly two AppTextFields '
              '(email + password) per Requirement 5.2.',
        );

        // The two fields must declare their leading icons via
        // `prefixIcon`, matching Requirement 5.2's "leading email
        // icon" / "leading lock icon" wording.
        final List<AppTextField> fields = tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .toList();
        final List<IconData?> prefixIcons =
            fields.map((AppTextField f) => f.prefixIcon).toList();
        expect(
          prefixIcons,
          containsAll(<IconData>[Icons.mail_outline, Icons.lock_outline]),
          reason: 'Email field must use mail_outline and password field '
              'must use lock_outline per Requirement 5.2.',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Empty-field validation — Requirement 5.6.
  // -------------------------------------------------------------------
  group('Empty-field validation', () {
    testWidgets(
      'tapping Sign In with empty fields surfaces inline errors and '
      'does not navigate',
      (tester) async {
        await _pumpLogin(tester);

        // No errorText is set on either field before the tap.
        for (final AppTextField field
            in tester.widgetList<AppTextField>(find.byType(AppTextField))) {
          expect(
            field.errorText,
            isNull,
            reason: 'AppTextFields must start with no error text before '
                'the user taps Sign In (Requirement 5.6).',
          );
        }

        // Tap the Sign In gradient button. With both fields empty the
        // local validator must short-circuit before the Firebase call,
        // so no plugin exception will fire (the test would crash
        // otherwise).
        await tester.tap(find.byType(AppGradientButton));
        await tester.pump();

        // After the tap, both fields surface a non-null errorText
        // identifying the missing field. The exact strings come from
        // the screen's local validation — we assert their presence
        // rather than their wording so a future copy tweak doesn't
        // break the test.
        final List<AppTextField> fieldsAfter = tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .toList();
        for (final AppTextField field in fieldsAfter) {
          expect(
            field.errorText,
            isNotNull,
            reason: 'Tapping Sign In with empty fields must surface '
                'inline errorText on the failing field per Requirement 5.6.',
          );
          expect(
            field.errorText,
            isNotEmpty,
            reason: 'Inline errorText must be non-empty per Requirement 5.6.',
          );
        }

        // The Login screen must still be on screen — no navigation
        // happens when validation fails.
        expect(
          find.text(_kHomeStubText),
          findsNothing,
          reason: 'Failed validation must NOT navigate away from '
              'LoginScreen (Requirement 5.6).',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Password visibility toggle — Requirement 5.3.
  // -------------------------------------------------------------------
  group('Password visibility toggle', () {
    testWidgets(
      'first display: password obscured + suffix shows show-password icon',
      (tester) async {
        await _pumpLogin(tester);

        // The password field is the AppTextField with the lock prefix
        // icon. Locate it directly.
        final AppTextField passwordField = tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .firstWhere((f) => f.prefixIcon == Icons.lock_outline);
        expect(
          passwordField.obscureText,
          isTrue,
          reason: 'Password field must render obscured on first display '
              '(Requirement 5.3).',
        );

        // The suffix is an AppIconButton; on first display it must be
        // the "show password" indicator (visibility_off glyph means
        // "tap to reveal").
        final AppIconButton suffix =
            passwordField.suffix as AppIconButton;
        expect(
          suffix.icon,
          Icons.visibility_off,
          reason: 'Initial visibility-toggle icon must be the '
              'show-password indicator (Requirement 5.3).',
        );
      },
    );

    testWidgets(
      'tapping the suffix flips obscureText and swaps the icon glyph',
      (tester) async {
        await _pumpLogin(tester);

        // Locate the password field's AppIconButton suffix and tap it.
        // Two AppIconButtons could in theory exist (one in the suffix,
        // one elsewhere) — `findsOneWidget` would catch any drift.
        expect(
          find.byType(AppIconButton),
          findsOneWidget,
          reason: 'LoginScreen must render exactly one AppIconButton '
              '(the password visibility toggle).',
        );
        await tester.tap(find.byType(AppIconButton));
        await tester.pump();

        // After the tap, obscureText flips to false and the suffix
        // glyph swaps to the "hide password" indicator.
        final AppTextField passwordField = tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .firstWhere((f) => f.prefixIcon == Icons.lock_outline);
        expect(passwordField.obscureText, isFalse);
        final AppIconButton suffix =
            passwordField.suffix as AppIconButton;
        expect(suffix.icon, Icons.visibility);
      },
    );
  });

  // -------------------------------------------------------------------
  // Forgot password — Requirement 5.8 (preserves entered values).
  // -------------------------------------------------------------------
  group('Forgot password', () {
    testWidgets(
      'with empty email surfaces a snackbar and preserves field values',
      (tester) async {
        await _pumpLogin(tester);

        // Type a value into the password field but leave the email
        // empty. Tapping `Forgot password?` must NOT modify either
        // controller's text (Requirement 5.8).
        final Finder passwordFinder = find.byWidgetPredicate(
          (w) => w is AppTextField && w.prefixIcon == Icons.lock_outline,
        );
        await tester.enterText(passwordFinder, 'kept-value');
        await tester.pump();

        // Tap the `Forgot password?` link. With an empty email the
        // handler short-circuits before the Firebase call and shows a
        // snackbar — see `LoginScreen._onForgotPassword`.
        await tester.tap(find.text('Forgot password?'));
        await tester.pump();

        // The early-return branch surfaces the snackbar text below.
        // Asserting on it confirms we hit the empty-email guard rather
        // than reaching `sendPasswordResetEmail` (which would throw a
        // MissingPluginException in the test host).
        expect(
          find.text('Enter your email above first.'),
          findsOneWidget,
          reason: 'Forgot password handler must surface the empty-email '
              'snackbar when no email is entered (Requirement 5.8 — '
              "handler must run without modifying field values).",
        );

        // Crucially, the password value the user typed must still be
        // present (Requirement 5.8 — "without modifying the values
        // entered in the email or password fields").
        final AppTextField passwordFieldAfter =
            tester.widget<AppTextField>(passwordFinder);
        expect(
          passwordFieldAfter.controller.text,
          'kept-value',
          reason: 'Forgot password must NOT mutate the password value '
              '(Requirement 5.8).',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Sign up navigation — Requirement 5.9.
  // -------------------------------------------------------------------
  group('Sign up free link', () {
    testWidgets(
      'tapping Sign up free pushes the RegisterScreen route',
      (tester) async {
        await _pumpLogin(tester);

        // Tap the `Sign up free` text link.
        await tester.tap(find.text('Sign up free'));
        await tester.pumpAndSettle();

        // The route table maps `RegisterScreen.routeName` to a stub
        // Scaffold whose body text is `_kRegisterStubText`. After the
        // route push, that stub must be on screen.
        expect(
          find.text(_kRegisterStubText),
          findsOneWidget,
          reason: 'Tapping Sign up free must push '
              'RegisterScreen.routeName onto the navigator '
              '(Requirement 5.9).',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Biometric branch — Requirement 5.13 (default-hidden).
  // -------------------------------------------------------------------
  group('Biometric button', () {
    testWidgets(
      'is omitted when neither precondition holds (default-hidden branch)',
      (tester) async {
        // Empty SharedPreferences store + the project's stub
        // `_canCheckBiometrics()` returning `false` means
        // `_biometricAvailable` stays `false`. The button is omitted
        // entirely from the widget tree, satisfying Requirement 5.13.
        await _pumpLogin(tester);
        // Settle the post-frame async biometric probe so any latent
        // setState would have already fired before we assert.
        await tester.pumpAndSettle();

        expect(
          find.byType(AppSecondaryButton),
          findsNothing,
          reason: 'Biometric AppSecondaryButton must NOT render when '
              'the device exposes no biometric authentication and no '
              'biometric_session_token is stored (Requirement 5.13).',
        );
      },
    );

    testWidgets(
      'stays hidden even when a biometric_session_token is present '
      'because the device-level capability check returns false',
      (tester) async {
        // Seed the SharedPreferences store with a biometric session
        // token so half of the predicate (token presence) is `true`.
        // The other half — the device-level
        // `_canCheckBiometrics()` — is hard-wired to `false` in the
        // current project (the `local_auth` plugin is not a
        // dependency), so the button must STILL stay hidden. This
        // test pins down Requirement 5.13's "WHERE the device does
        // NOT expose biometric authentication ... THE Login screen
        // SHALL NOT render the Biometric button" branch.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'biometric_session_token': 'abc123',
        });

        await _pumpLogin(tester);
        await tester.pumpAndSettle();

        expect(
          find.byType(AppSecondaryButton),
          findsNothing,
          reason: 'Even with a biometric_session_token present, the '
              'button must stay hidden when the device-level '
              'capability check is false (Requirement 5.13).',
        );
      },
    );
  });
}
