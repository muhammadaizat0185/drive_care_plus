// Feature: figma-ui-redesign — Widget tests for the redesigned
// `RegisterScreen`.
//
// Validates:
//   * Requirement 5.10 — Register screen adopts the same hero block,
//                        typography scale, AppTextField styling, and
//                        AppGradientButton components as the login
//                        screen ("parity with login").
//
// The register screen also re-uses the cross-cutting visual contracts
// established by the login screen tests, so a small subset of those
// is replicated here against the actual `RegisterScreen` widget so a
// regression on either screen is caught independently:
//
//   * Hero block — 128 x 128 brand-gradient tile with the 🚗 emoji
//     identical to login (Requirement 5.10).
//   * Empty-field validation surfaces inline errorText on each missing
//     input (Requirement 5.10's "preserving the existing registration
//     form fields" — the existing form runs the same empty + min-length
//     validation as before).
//   * Password length < 6 surfaces the "must be at least 6 characters
//     long" inline error (preserves the existing 6-character minimum
//     password rule referenced by `RegisterScreen._register`).
//   * `Sign in` link pops the navigator back to the previous route
//     (mirrors the login screen's `Sign up free` affordance and
//     completes the closed navigation pair from Requirement 5.10's
//     "form a closed navigation pair").
//
// Why a partial-mount approach instead of a full Firebase mock:
//   * `RegisterScreen._register` calls
//     `FirebaseAuth.instance.createUserWithEmailAndPassword(...)`. The
//     `firebase_auth` plugin channels are not registered in
//     `flutter test`, so any code path that reaches the Firebase call
//     will throw `MissingPluginException` (the screen catches the
//     throw in its offline-fallback branch and pushes
//     `HomeScreen.routeName`). The tests below focus on the
//     deterministic layers that do NOT require Firebase: hero
//     rendering, empty-field validation that short-circuits BEFORE
//     the Firebase call, and the `Sign in` pop navigation.

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/login_screen.dart';
import 'package:drive_care_plus/screens/register_screen.dart';
import 'package:drive_care_plus/widgets/ui/app_gradient_button.dart';
import 'package:drive_care_plus/widgets/ui/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Test host: a MaterialApp with the design-token theme and routes
// table containing both Login and Register so navigation between them
// can be observed by the tests below. Some tests pump the Register
// screen as the initial route directly; the `Sign in` pop test pushes
// Register from a `LoginScreen` stub so popping has somewhere to land.
// ---------------------------------------------------------------------------

const String _kHomeStubText = 'home-stub';
const String _kLoginStubText = 'login-stub';

/// Pumps [RegisterScreen] as the initial route. Used by tests that
/// don't need to observe the pop-to-login flow.
///
/// The default `flutter test` viewport is 800 x 600 logical pixels,
/// which is too short for the full Register form. Set a deterministic
/// 1080 x 1920 physical size — same pattern as `home_widgets_test.dart`
/// — so layout tests can read the rendered geometry of every element
/// without overflow truncation.
Future<void> _pumpRegister(WidgetTester tester) async {
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
      initialRoute: RegisterScreen.routeName,
      routes: <String, WidgetBuilder>{
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        LoginScreen.routeName: (_) =>
            const Scaffold(body: Text(_kLoginStubText)),
        '/home': (_) => const Scaffold(body: Text(_kHomeStubText)),
      },
    ),
  );
  await tester.pump();
}

/// Pumps a stub login route as the initial route, then pushes the real
/// Register screen on top of it so `Navigator.pop` from the Register
/// screen has the login stub to land on. Used by the `Sign in` pop
/// test.
///
/// The default `flutter test` viewport is 800 x 600 logical pixels,
/// which is too short to fit the entire Register form (hero + heading
/// + body + 3 fields + CTA + Sign-in row). The `Sign in` link sits at
/// the very bottom of the scroll content, so without a taller
/// viewport it lands below the visible area and `tester.tap` fails
/// the hit-test. Setting a deterministic 1080 x 1920 physical size
/// matches the pattern used by `home_widgets_test.dart` and brings
/// the link into view.
Future<void> _pumpRegisterAtopLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ThemeData theme =
      AppTheme.buildTheme(AppColors.emerald500, Brightness.light);

  // A NavigatorKey lets us call `pushNamed` after the initial pump
  // without depending on a BuildContext from inside the stub.
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: LoginScreen.routeName,
      routes: <String, WidgetBuilder>{
        LoginScreen.routeName: (_) =>
            const Scaffold(body: Text(_kLoginStubText)),
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        '/home': (_) => const Scaffold(body: Text(_kHomeStubText)),
      },
    ),
  );
  await tester.pump();

  // Confirm the login stub is the initial route, then push Register on
  // top of it. After this, the Register screen is on top of the stack
  // and `pop` from inside Register lands on the login stub.
  expect(find.text(_kLoginStubText), findsOneWidget);
  navKey.currentState!.pushNamed(RegisterScreen.routeName);
  await tester.pumpAndSettle();
  expect(find.byType(RegisterScreen), findsOneWidget);
}

void main() {
  // Some downstream code reads SharedPreferences on first frame; seed
  // an empty in-memory store so any read resolves cleanly.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // -------------------------------------------------------------------
  // Hero block parity with login — Requirement 5.10.
  // -------------------------------------------------------------------
  group('Hero block parity with login', () {
    testWidgets(
      'renders the same 128 x 128 brand-gradient tile with the 🚗 emoji',
      (tester) async {
        await _pumpRegister(tester);

        // The 🚗 emoji is rendered with `AppTypography.display`, same
        // as the login screen (Requirement 5.10's "same hero block").
        expect(
          find.byWidgetPredicate(
            (Widget w) => w is Text && w.data == '🚗',
          ),
          findsOneWidget,
          reason: 'Register hero must render the 🚗 emoji per Requirement 5.10.',
        );

        // The hero is the unique 128x128 Container with a brand
        // gradient and AppRadii.large corners — identical contract to
        // login_screen_test.dart's hero assertion.
        final Finder heroFinder = find.byWidgetPredicate(
          (Widget w) {
            if (w is! Container) return false;
            return w.constraints?.maxWidth == 128 &&
                w.constraints?.maxHeight == 128;
          },
        );
        expect(heroFinder, findsOneWidget);

        final Container hero = tester.widget<Container>(heroFinder);
        final BoxDecoration decoration = hero.decoration as BoxDecoration;
        final LinearGradient gradient = decoration.gradient as LinearGradient;
        expect(
          gradient.colors,
          containsAll(<Color>[AppColors.emerald500, AppColors.teal400]),
          reason: 'Register hero gradient must run from emerald500 to '
              'teal400 — same as login (Requirement 5.10).',
        );
        expect(
          decoration.borderRadius,
          BorderRadius.circular(AppRadii.large),
          reason: 'Register hero must use AppRadii.large corner radius — '
              'same as login (Requirement 5.10).',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Form fields — preserves the existing registration form fields
  // (Requirement 5.10).
  // -------------------------------------------------------------------
  group('Form fields parity with login', () {
    testWidgets(
      'renders Full Name, Email, and Password AppTextFields with prefix icons',
      (tester) async {
        await _pumpRegister(tester);

        // Three AppTextFields — name + email + password. Login renders
        // two; register adds the name field but the email + password
        // pair is shared and uses the same icons.
        expect(
          find.byType(AppTextField),
          findsNWidgets(3),
          reason: 'Register form must render three AppTextFields '
              '(name + email + password) per Requirement 5.10.',
        );

        final List<IconData?> prefixIcons = tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .map((AppTextField f) => f.prefixIcon)
            .toList();
        expect(
          prefixIcons,
          containsAll(<IconData>[
            Icons.person_outline,
            Icons.mail_outline,
            Icons.lock_outline,
          ]),
          reason: 'Register form must use person/mail/lock prefix icons '
              'on its three fields per Requirement 5.10 (matches the '
              "login screen's mail + lock pair).",
        );
      },
    );

    testWidgets(
      'primary CTA is a full-width AppGradientButton (parity with login)',
      (tester) async {
        await _pumpRegister(tester);

        // Login uses a single AppGradientButton (`Sign In`); register
        // uses a single AppGradientButton (`Create Account`). Asserting
        // the count and type confirms the parity contract from
        // Requirement 5.10.
        expect(
          find.byType(AppGradientButton),
          findsOneWidget,
          reason: 'Register screen must use a single AppGradientButton '
              'as its primary CTA — same as login (Requirement 5.10).',
        );
        final AppGradientButton cta =
            tester.widget<AppGradientButton>(find.byType(AppGradientButton));
        expect(
          cta.fullWidth,
          isTrue,
          reason: 'Primary CTA must stretch full width per Requirement 5.10.',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Empty-field validation parity with login.
  //
  // Requirement 5.10 preserves the existing form fields and validation,
  // and the existing register validation runs locally before the
  // Firebase call. Tapping `Create Account` with empty fields must
  // surface inline errorText on each missing field and NOT navigate
  // away (the Firebase call is short-circuited).
  // -------------------------------------------------------------------
  group('Empty-field validation', () {
    testWidgets(
      'tapping Create Account with empty fields surfaces inline errors '
      'and does not navigate',
      (tester) async {
        await _pumpRegister(tester);

        // No errorText on any field before the tap.
        for (final AppTextField field
            in tester.widgetList<AppTextField>(find.byType(AppTextField))) {
          expect(field.errorText, isNull);
        }

        await tester.tap(find.byType(AppGradientButton));
        await tester.pump();

        // After the tap, all three fields surface a non-null
        // errorText. The exact strings come from the screen's local
        // validation — assert presence rather than wording so a
        // future copy tweak doesn't break the test.
        for (final AppTextField field
            in tester.widgetList<AppTextField>(find.byType(AppTextField))) {
          expect(
            field.errorText,
            isNotNull,
            reason: 'All three required fields must surface inline '
                'errorText when Create Account is tapped with empty '
                'fields.',
          );
          expect(field.errorText, isNotEmpty);
        }

        // No navigation away from the Register screen on validation
        // failure — the Home stub must NOT be visible.
        expect(find.text(_kHomeStubText), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------
  // Password minimum-length rule (preserved from the existing
  // implementation per Requirement 5.10's "preserving the existing
  // registration form fields ... and the existing Firebase create-user
  // behavior" — the 6-character minimum is part of the existing form
  // contract).
  // -------------------------------------------------------------------
  group('Password minimum length', () {
    testWidgets(
      'password shorter than 6 characters surfaces the min-length error',
      (tester) async {
        await _pumpRegister(tester);

        // Fill the name + email fields so they pass validation; only
        // the password field is left short. This isolates the
        // min-length branch.
        final List<AppTextField> fields = tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .toList();
        final AppTextField nameField =
            fields.firstWhere((f) => f.prefixIcon == Icons.person_outline);
        final AppTextField emailField =
            fields.firstWhere((f) => f.prefixIcon == Icons.mail_outline);
        final AppTextField passwordField =
            fields.firstWhere((f) => f.prefixIcon == Icons.lock_outline);

        await tester.enterText(find.byWidget(nameField), 'Jane Doe');
        await tester.enterText(
          find.byWidget(emailField),
          'jane@example.com',
        );
        // Five characters — one short of the 6-character minimum.
        await tester.enterText(find.byWidget(passwordField), 'short');
        await tester.pump();

        await tester.tap(find.byType(AppGradientButton));
        await tester.pump();

        // The password field must surface the min-length error message
        // verbatim (the implementation guidance in the task lists it
        // explicitly so we pin the exact string here).
        final AppTextField passwordAfter = tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .firstWhere((f) => f.prefixIcon == Icons.lock_outline);
        expect(
          passwordAfter.errorText,
          'Password must be at least 6 characters long',
          reason: 'Register screen must surface the existing 6-character '
              'minimum-password error verbatim (Requirement 5.10 — '
              'preserves the existing registration form validation).',
        );

        // Name and email fields must NOT carry an error since their
        // values pass the empty-field check.
        final AppTextField nameAfter = tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .firstWhere((f) => f.prefixIcon == Icons.person_outline);
        final AppTextField emailAfter = tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .firstWhere((f) => f.prefixIcon == Icons.mail_outline);
        expect(nameAfter.errorText, isNull);
        expect(emailAfter.errorText, isNull);

        // No navigation away from the Register screen on validation
        // failure.
        expect(find.text(_kHomeStubText), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------
  // `Sign in` link pops back to login (closed navigation pair from
  // Requirement 5.10).
  // -------------------------------------------------------------------
  group('Sign in link', () {
    testWidgets(
      'tapping Sign in pops Register and returns to the previous route',
      (tester) async {
        await _pumpRegisterAtopLogin(tester);

        // Ensure the `Sign in` link is on screen before tapping. With
        // the 1080 x 1920 viewport set in `_pumpRegisterAtopLogin`
        // the entire form fits, but we call `ensureVisible` defensively
        // so the test stays robust if a future copy or layout tweak
        // pushes the link below the fold on this viewport.
        await tester.ensureVisible(find.text('Sign in'));
        await tester.pump();

        // Tap the `Sign in` link inside Register. The handler calls
        // `Navigator.pop` when `canPop()` is true, returning to the
        // login stub.
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();

        // The login stub must be back on screen and Register must be
        // gone from the tree.
        expect(find.text(_kLoginStubText), findsOneWidget);
        expect(find.byType(RegisterScreen), findsNothing);
      },
    );
  });
}
