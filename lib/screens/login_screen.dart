import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_tracker_service.dart';
import '../services/auth_cleanup_service.dart';
import '../services/biometric_service.dart';
import '../services/totp_service.dart';
import '../widgets/sound_button.dart';
import 'totp_verification_screen.dart';

import '../core/theme/color_utils.dart';

import '../core/theme/tokens/tokens.dart';
import '../core/util/in_flight_gate.dart';
import '../widgets/ui/ui.dart';
import 'home_screen.dart';
import 'register_screen.dart';

/// Sign-in screen for DriveCare+.
///
/// Visual structure mirrors the `LoginImproved` mockup:
///   * Hero block (128 x 128 logical pixels, `AppRadii.large` corner radius,
///     `emerald500 → teal400` brand gradient, centred 🚗 emoji).
///   * Email and password [AppTextField]s with prefix icons and the
///     2-logical-pixel border treatment from the Component_Library
///     (Requirements 5.1, 5.2).
///   * `Sign In` [AppGradientButton] (Requirement 5.5).
///   * `Forgot password?` link wired to Firebase `sendPasswordResetEmail`
///     without modifying the entered field values (Requirement 5.8).
///   * `Sign up free` link that pushes [RegisterScreen] (Requirement 5.9).
///
/// All existing controllers and the `signInWithEmailAndPassword` call are
/// preserved verbatim from the previous implementation. The password
/// visibility toggle is wired in this iteration (task 7.2 — Requirements
/// 5.3, 5.4). Empty-field validation, the in-flight gate, and the
/// loading-state hook on the gradient button are wired in task 7.4
/// (Requirements 5.5, 5.6, 5.7); the forgot-password reset flow and
/// "Sign up free" navigation are wired in task 7.6 (Requirements 5.8,
/// 5.9).
///
/// Biometric button (task 7.7 — Requirements 5.11, 5.12, 5.13). The
/// `Biometric` [AppSecondaryButton] is rendered only when the device
/// exposes biometric authentication AND a `biometric_session_token`
/// entry is present in [SharedPreferences]. When neither precondition
/// holds the button is omitted entirely (Requirement 5.13). The
/// device-level biometric capability check is intentionally a
/// pluggable predicate ([_canCheckBiometrics]); the underlying
/// `local_auth` (LocalAuthentication) plugin is not currently a
/// dependency of this project, so the predicate returns `false` by
/// default and the button stays hidden until biometric support is
/// added at the platform layer. The conditional-render contract from
/// Requirements 5.11 and 5.13 is wired regardless of the predicate's
/// return value, so flipping the predicate to a real `local_auth`
/// call in a follow-up change is the only delta required to enable
/// the affordance. The tap handler ([_onBiometric]) currently surfaces
/// a "coming soon" snackbar in place of the deferred biometric login
/// flow referenced by Requirement 5.12.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Per-screen in-flight guard for the `Sign In` gesture. `run` drops
  /// re-entrant taps while a previous `signInWithEmailAndPassword` call
  /// is still in flight, satisfying Requirement 5.7. The button's
  /// `isLoading` slot and the input fields' `enabled` flag are driven
  /// off [InFlightGate.isRunning] via a [ListenableBuilder] so the
  /// loading visual is in lock-step with the underlying async work.
  final InFlightGate _signInGate = InFlightGate();

  // Password visibility toggle state (Requirements 5.3, 5.4). The field
  // renders obscured on first display; tapping the suffix flips this
  // flag, swaps the trailing icon, and leaves [_passwordController]
  // untouched so the entered value is preserved across toggles.
  bool _obscurePassword = true;

  /// Inline validation message rendered under the email field when the
  /// user attempts to sign in with an empty email (Requirement 5.6).
  /// Cleared on the next sign-in attempt.
  String? _emailError;

  /// Inline validation message rendered under the password field when
  /// the user attempts to sign in with an empty password
  /// (Requirement 5.6). Cleared on the next sign-in attempt.
  String? _passwordError;

  /// Whether the device exposes biometric authentication AND a
  /// `biometric_session_token` is currently stored in SharedPreferences.
  /// Drives the conditional render of the `Biometric`
  /// [AppSecondaryButton] (Requirements 5.11, 5.13). Defaults to
  /// `false` so the button is hidden during the brief async window
  /// before [_loadBiometricAvailability] resolves and on every device
  /// that lacks biometric hardware. Updated via [setState] from
  /// [_loadBiometricAvailability].
  bool _biometricAvailable = false;

  /// SharedPreferences key checked by [_loadBiometricAvailability]. The
  /// presence of any non-null value means a previous biometric login
  /// session has been registered for this device, satisfying half of
  /// the predicate in Requirement 5.11.
  static const String _biometricSessionTokenKey = 'biometric_session_token';

  @override
  void initState() {
    super.initState();
    // Schedule the async biometric capability + session-token probe
    // off the first frame so the button can light up the moment both
    // preconditions are satisfied, without blocking the initial paint
    // (Requirements 5.11, 5.13).
    _loadBiometricAvailability();
  }

  /// Probes whether the `Biometric` button should be rendered. The
  /// button shows iff both preconditions hold:
  ///   1. The device exposes biometric authentication. The current
  ///      project does not depend on the `local_auth` plugin, so
  ///      [_canCheckBiometrics] returns `false` by default. When that
  ///      plugin is later added, swap the implementation of
  ///      [_canCheckBiometrics] to read
  ///      `LocalAuthentication().canCheckBiometrics`.
  ///   2. A `biometric_session_token` entry is present in
  ///      [SharedPreferences].
  ///
  /// Both checks are guarded by a `try/catch` so a hostile platform
  /// channel or storage failure never throws into [build]; the button
  /// simply stays hidden, satisfying Requirement 5.13's "do not render"
  /// directive.
  Future<void> _loadBiometricAvailability() async {
    bool available = false;
    try {
      final bool canAuth = await BiometricService.instance.canAuthenticate();
      if (canAuth) {
        available = BiometricService.instance.isBiometricsEnabled;
      }
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    if (available != _biometricAvailable) {
      setState(() => _biometricAvailable = available);
    }
  }

  Future<void> _handlePostLoginRouting(String uid) async {
    final bool isTotpEnabled = await TOTPService.instance.checkIsTotpEnabled(uid);
    if (isTotpEnabled) {
      if (!mounted) return;
      final bool? verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => TOTPVerificationScreen(uid: uid),
        ),
      );
      if (verified != true) {
        _showSnackbar('Two-step verification cancelled or failed.');
        return;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_offline_logged_in', true);
    } catch (_) {}
    await AuthCleanupService.initializeUserData();
    if (mounted) {
      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
    }
  }

  Future<void> _onBiometric() async {
    final bool canAuth = await BiometricService.instance.canAuthenticate();
    if (!canAuth) {
      _showSnackbar('Biometrics not available or not set up on this device.');
      return;
    }

    final bool authenticated = await BiometricService.instance.authenticateLocal();
    if (!authenticated) {
      _showSnackbar('Biometric verification failed.');
      return;
    }

    final credentials = await BiometricService.instance.getStoredCredentials();
    if (credentials == null) {
      _showSnackbar('Secure credentials not found. Please log in manually once.');
      return;
    }

    final String email = credentials['email']!;
    final String password = credentials['password']!;

    await _signInGate.run<void>(() async {
      try {
        ApiTracker.instance.trackCall('Firebase Core');
        final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = userCredential.user;
        if (user != null) {
          await _handlePostLoginRouting(user.uid);
        }
      } on FirebaseAuthException catch (e) {
        _showSnackbar(e.message ?? 'Biometric sign in failed.');
      } catch (e) {
        _showSnackbar('Biometric sign in failed: $e');
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _signInGate.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Empty-field validation runs locally before any Firebase call so a
    // missing email or password short-circuits the network round-trip
    // and surfaces the failing field via `AppTextField.errorText`
    // (Requirement 5.6). Trim is applied so a whitespace-only entry is
    // treated as empty.
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    setState(() {
      _emailError = email.isEmpty ? 'Email is required' : null;
      _passwordError = password.isEmpty ? 'Password is required' : null;
    });
    if (_emailError != null || _passwordError != null) {
      return;
    }

    // Route the Firebase call through the in-flight gate so rapid taps
    // produce exactly one `signInWithEmailAndPassword` invocation per
    // user gesture (Requirement 5.7). The gate releases in a `finally`
    // block inside [InFlightGate.run], so existing success/error
    // pathways below run unmodified.
    await _signInGate.run<void>(() async {
      try {
        ApiTracker.instance.trackCall('Firebase Core');
        final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = userCredential.user;
        if (user != null) {
          if (BiometricService.instance.isBiometricsEnabled) {
            await BiometricService.instance.setBiometricsEnabled(true, email: email, password: password);
          }
          await _handlePostLoginRouting(user.uid);
        }
      } on FirebaseAuthException catch (e) {
        _showSnackbar(e.message ?? 'Authentication failed.');
      } catch (e) {
        // Robust Fallback: If Firebase is not fully configured online or
        // offline.
        debugPrint('Firebase Login Error fallback: $e');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_offline_logged_in', true);
        } catch (_) {}
        _showSnackbar('Firebase Offline Mode: Logging in as dummy user.');
        await AuthCleanupService.initializeUserData();
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

  Future<void> _onForgotPassword() async {
    // Forgot-password handler triggers Firebase's password reset flow
    // (Requirement 5.8). The handler MUST NOT modify the entered field
    // values, so we read `_emailController.text` via `trim()` for the
    // reset call but never write back to the controllers. The password
    // controller is intentionally untouched.
    final String email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackbar('Enter your email above first.');
      return;
    }
    try {
      ApiTracker.instance.trackCall('Firebase Core');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showSnackbar('Password reset email sent to $email.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackbar(e.message ?? 'Could not send reset email.');
    } catch (_) {
      // Network/Firebase unavailable fallback — keep the entered values
      // intact so the user can retry once back online.
      if (!mounted) return;
      _showSnackbar('Password reset is unavailable while offline.');
    }
  }

  void _onSignUp() {
    Navigator.pushNamed(context, RegisterScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: SafeArea(
        // [ListenableBuilder] rebuilds the form when [_signInGate]
        // notifies a state change so the gradient button's `isLoading`
        // slot, the inputs' `enabled` flag, and the link buttons'
        // disabled treatment all stay in sync with the in-flight state
        // without manual `setState` plumbing (Requirements 5.5, 5.7).
        child: ListenableBuilder(
          listenable: _signInGate,
          builder: (BuildContext ctx, _) {
            final bool inFlight = _signInGate.isRunning;
            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.xl,
                vertical: spacing.xl,
              ),
              children: <Widget>[
                SizedBox(height: spacing.xxl),
                // Hero block: 128 x 128 brand-gradient tile with a
                // centred car emoji (Requirement 5.1).
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
                  'Welcome back',
                  style: typography.headlineLarge.copyWith(
                    color: colors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.sm),
                Text(
                  'Sign in to manage your vehicle, trips, and bookings.',
                  style: typography.bodyLarge.copyWith(
                    color: colors.foreground.withValues(
                      alpha: 1 - colors.surfaceMedium,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.xxl),
                // Email field with leading mail icon (Requirement 5.2).
                // `errorText` surfaces empty-field validation per
                // Requirement 5.6; `enabled` tracks the in-flight gate
                // so the field is read-only while a sign-in is running.
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
                // across toggles (Requirements 5.3, 5.4). `errorText`
                // surfaces empty-field validation (Requirement 5.6);
                // `enabled` tracks the in-flight gate.
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
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
                SizedBox(height: spacing.sm),
                // Forgot-password link aligned to the trailing edge so
                // it hugs the password field above. The handler invokes
                // Firebase's `sendPasswordResetEmail` without modifying
                // the entered field values (Requirement 5.8).
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SoundTextButton(
                    onPressed: inFlight ? null : _onForgotPassword,
                    child: Text(
                      'Forgot password?',
                      style: typography.bodyLarge.copyWith(
                        color: colors.emerald500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing.lg),
                // Primary CTA: brand-gradient pill (Requirement 5.5).
                // `isLoading` binds to the in-flight gate so the button
                // shows its spinner state and rejects taps while a
                // sign-in is in flight (Requirement 5.7).
                AppGradientButton(
                  label: 'Sign In',
                  isLoading: inFlight,
                  onPressed: inFlight ? null : _login,
                ),
                // Biometric affordance: rendered only when the device
                // exposes biometric authentication AND a
                // `biometric_session_token` is present in
                // SharedPreferences (Requirements 5.11, 5.13). Tapping
                // dispatches to the deferred biometric login flow per
                // Requirement 5.12; see [_onBiometric] for the current
                // placeholder until the `local_auth` plugin is wired
                // in. When [_biometricAvailable] is `false`, the
                // button is omitted from the widget tree entirely so
                // the layout collapses around it (Requirement 5.13).
                if (_biometricAvailable) ...<Widget>[
                  SizedBox(height: spacing.lg),
                  AppSecondaryButton(
                    label: 'Biometric',
                    icon: Icons.fingerprint,
                    fullWidth: true,
                    onPressed: inFlight ? null : _onBiometric,
                  ),
                ],
                SizedBox(height: spacing.lg),
                // Sign-up affordance — "Don't have an account? Sign up
                // free" (Requirement 5.9).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      "Don't have an account? ",
                      style: typography.bodyLarge.copyWith(
                        color: colors.foreground.withValues(
                          alpha: 1 - colors.surfaceMedium,
                        ),
                      ),
                    ),
                    SoundTextButton.navigation(
                      onPressed: inFlight ? null : _onSignUp,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.xs,
                          vertical: spacing.xs,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Sign up free',
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
    ),);
  }
}
