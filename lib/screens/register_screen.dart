import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/tokens/tokens.dart';
import '../core/util/in_flight_gate.dart';
import '../widgets/ui/ui.dart';
import 'home_screen.dart';

/// Account-creation screen for DriveCare+.
///
/// Visual structure mirrors the `LoginImproved` mockup so the redesigned
/// login and register screens read as a single auth flow
/// (Requirement 5.10):
///
///   * Hero block — 128 × 128 logical-pixel tile, `AppRadii.large`
///     corner radius, `emerald500 → teal400` brand gradient, centred
///     🚗 emoji rendered with `AppTypography.display` — identical to
///     `login_screen.dart`.
///   * Heading + body copy with the same typography scale as login
///     (`typography.headlineLarge`, `typography.bodyLarge`) so the two
///     screens land on the same baseline grid.
///   * Form fields rebuilt as [AppTextField] with prefix icons and the
///     2-logical-pixel border treatment from the Component_Library
///     (Requirement 3.3 carried via task 4.4). Existing fields — full
///     name, email, password — are preserved; their controllers,
///     validation rules, and trim semantics are unchanged from the
///     previous implementation so the registration form still passes
///     the same payload to Firebase.
///   * Password visibility toggle — same pattern as login. Tapping the
///     suffix [AppIconButton] flips [_obscurePassword] and swaps the
///     trailing icon without touching the controller, so the entered
///     value is preserved across toggles.
///   * Primary CTA rebuilt as [AppGradientButton]. Tapping the button
///     routes the existing `createUserWithEmailAndPassword` call
///     through an [InFlightGate] so rapid taps still produce exactly
///     one Firebase invocation per user gesture; the button's
///     `isLoading` slot tracks the gate so the spinner state is in
///     lock-step with the underlying async work. Empty-field
///     validation runs locally before the Firebase call so a missing
///     field short-circuits the network round-trip and surfaces inline
///     `errorText` on the failing input — same contract as login. The
///     existing 6-character minimum-password check is retained.
///   * `Sign In` link returns to the previous route via
///     `Navigator.pop`, mirroring the login screen's `Sign up free`
///     affordance so the two screens form a closed navigation pair.
///
/// All existing service interactions — `FirebaseAuth.instance
/// .createUserWithEmailAndPassword`, the `updateDisplayName` follow-up
/// call, and the offline-fallback success path that pushes
/// [HomeScreen.routeName] — are preserved verbatim from the previous
/// implementation. The redesign is visual.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const routeName = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Per-screen in-flight guard for the `Create Account` gesture. `run`
  /// drops re-entrant taps while a previous
  /// `createUserWithEmailAndPassword` call is still in flight. The
  /// button's `isLoading` slot and the input fields' `enabled` flag are
  /// driven off [InFlightGate.isRunning] via a [ListenableBuilder] so
  /// the loading visual is in lock-step with the underlying async work.
  final InFlightGate _registerGate = InFlightGate();

  /// Password visibility toggle state. The field renders obscured on
  /// first display; tapping the suffix flips this flag, swaps the
  /// trailing icon, and leaves [_passwordController] untouched so the
  /// entered value is preserved across toggles. Same contract as
  /// `login_screen.dart`.
  bool _obscurePassword = true;

  /// Inline validation message rendered under the name field when the
  /// user attempts to register with an empty name. Cleared on the next
  /// register attempt.
  String? _nameError;

  /// Inline validation message rendered under the email field when the
  /// user attempts to register with an empty email. Cleared on the next
  /// register attempt.
  String? _emailError;

  /// Inline validation message rendered under the password field. Holds
  /// either the empty-field error or the "must be at least 6
  /// characters" error from the existing minimum-length rule.
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _registerGate.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // Local validation runs before any Firebase call so a missing or
    // too-short field short-circuits the network round-trip and
    // surfaces the failing field via `AppTextField.errorText`. Trim is
    // applied so a whitespace-only entry is treated as empty. The
    // 6-character minimum-password rule is preserved from the previous
    // implementation.
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    String? nextNameError;
    String? nextEmailError;
    String? nextPasswordError;
    if (name.isEmpty) {
      nextNameError = 'Full name is required';
    }
    if (email.isEmpty) {
      nextEmailError = 'Email is required';
    }
    if (password.isEmpty) {
      nextPasswordError = 'Password is required';
    } else if (password.length < 6) {
      nextPasswordError = 'Password must be at least 6 characters long';
    }
    setState(() {
      _nameError = nextNameError;
      _emailError = nextEmailError;
      _passwordError = nextPasswordError;
    });
    if (nextNameError != null ||
        nextEmailError != null ||
        nextPasswordError != null) {
      return;
    }

    // Route the Firebase call through the in-flight gate so rapid taps
    // produce exactly one `createUserWithEmailAndPassword` invocation
    // per user gesture. The gate releases in a `finally` block inside
    // [InFlightGate.run], so the success-navigation and error-handling
    // pathways below run unmodified.
    await _registerGate.run<void>(() async {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Update the freshly-created user's display name so downstream
        // services (ProfileService, greeting helper) pick up the value
        // on first launch.
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updateDisplayName(name);
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, HomeScreen.routeName);
        }
      } on FirebaseAuthException catch (e) {
        _showSnackbar(e.message ?? 'Registration failed.');
      } catch (e) {
        // Robust Fallback: If Firebase is offline/unconfigured we keep
        // the previous behaviour of pushing through to the cockpit so
        // the user is not blocked on a misconfigured environment.
        debugPrint('Firebase Register Error fallback: $e');
        _showSnackbar('Firebase Offline Mode: Registering dummy account.');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.pushReplacementNamed(context, HomeScreen.routeName);
        }
      }
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSignIn() {
    // The register screen is reached via `Navigator.pushNamed` from the
    // login screen's "Sign up free" link, so popping returns to login
    // without rebuilding it.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        // [ListenableBuilder] rebuilds the form when [_registerGate]
        // notifies a state change so the gradient button's `isLoading`
        // slot, the inputs' `enabled` flag, and the link button's
        // disabled treatment all stay in sync with the in-flight state
        // without manual `setState` plumbing.
        child: ListenableBuilder(
          listenable: _registerGate,
          builder: (BuildContext ctx, _) {
            final bool inFlight = _registerGate.isRunning;
            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.xl,
                vertical: spacing.xl,
              ),
              children: <Widget>[
                SizedBox(height: spacing.xxl),
                // Hero block: 128 × 128 brand-gradient tile with a
                // centred car emoji — identical to login_screen.dart so
                // the two screens read as a single auth flow.
                Center(
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radii.large),
                      gradient: LinearGradient(
                        colors: <Color>[colors.emerald500, colors.teal400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '🚗',
                      style: typography.display,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: spacing.xl),
                Text(
                  'Create your account',
                  style: typography.headlineLarge.copyWith(
                    color: colors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.sm),
                Text(
                  'Join DriveCare+ to track your vehicle, trips, and bookings.',
                  style: typography.bodyLarge.copyWith(
                    color: colors.foreground.withValues(
                      alpha: 1 - colors.surfaceMedium,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.xxl),
                // Full name field with leading person icon. `errorText`
                // surfaces empty-field validation; `enabled` tracks the
                // in-flight gate so the field is read-only while a
                // create-user call is running.
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hintText: 'Jane Doe',
                  prefixIcon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  enabled: !inFlight,
                  errorText: _nameError,
                ),
                SizedBox(height: spacing.lg),
                // Email field with leading mail icon, identical to the
                // login screen's email input.
                AppTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hintText: 'you@example.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !inFlight,
                  errorText: _emailError,
                ),
                SizedBox(height: spacing.lg),
                // Password field with leading lock icon. The trailing
                // visibility toggle flips [_obscurePassword] without
                // touching the controller so the entered value persists
                // across toggles. `errorText` surfaces both the
                // empty-field error and the 6-character minimum-length
                // error.
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'At least 6 characters',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  enabled: !inFlight,
                  errorText: _passwordError,
                  suffix: AppIconButton(
                    icon: _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    semanticsLabel: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: inFlight
                        ? null
                        : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                  ),
                ),
                SizedBox(height: spacing.xl),
                // Primary CTA: brand-gradient pill, identical to the
                // login screen's `Sign In` button. `isLoading` binds to
                // the in-flight gate so the button shows its spinner
                // state and rejects taps while a registration is in
                // flight.
                AppGradientButton(
                  label: 'Create Account',
                  isLoading: inFlight,
                  onPressed: inFlight ? null : _register,
                ),
                SizedBox(height: spacing.lg),
                // "Already have an account? Sign in" affordance —
                // mirrors the login screen's sign-up link so the two
                // screens form a closed navigation pair.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Already have an account? ',
                      style: typography.bodyLarge.copyWith(
                        color: colors.foreground.withValues(
                          alpha: 1 - colors.surfaceMedium,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: inFlight ? null : _onSignIn,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.xs,
                          vertical: spacing.xs,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Sign in',
                        style: typography.bodyLarge.copyWith(
                          color: colors.emerald500,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
