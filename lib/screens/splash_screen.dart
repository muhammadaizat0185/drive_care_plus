// Token + Component_Library sweep (Group 14, Task 14.5).
//
// This sweep replaces every literal hex/spacing/radius/typography in the
// splash screen with token references read off `Theme.of(context)`
// extensions, while preserving the splash routing logic verbatim:
//   * `Timer(Duration(milliseconds: 2500), …)` delay
//   * `FirebaseAuth.instance.currentUser` read
//   * `SharedPreferences.getInstance().getBool('is_offline_logged_in')` read
//   * `Navigator.pushReplacement(... PageRouteBuilder ... FadeTransition ...)`
//
// Visual constants (font sizes, weights, padding, radii, spacing) come from
// `AppTypographyExt`, `AppSpacingExt`, `AppRadiiExt`, `AppColorsExt`. No raw
// hex or spacing/radius literals remain (Requirement 12.1).

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/color_utils.dart';

import '../core/theme/tokens/tokens.dart';
import '../widgets/ui/ui.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final Widget? homeScreenOverride;
  final Widget? loginScreenOverride;

  const SplashScreen({
    super.key,
    this.homeScreenOverride,
    this.loginScreenOverride,
  });

  static const routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Splash hold duration. Held as a private constant because it is the
  // splash routing contract, not a `AppMotion` token (which tops out at
  // `slow = 500ms`).
  static const Duration _splashHold = Duration(milliseconds: 2500);
  static const Duration _fadeDuration = Duration(milliseconds: 650);

  // Hero logo height. Not a Token_Set value, so encoded locally.
  static const double _logoHeight = 120;
  // Width of the linear progress indicator. Not a Token_Set value.
  static const double _progressWidth = 140;

  @override
  void initState() {
    super.initState();
    _startTransitionTimer();
  }

  void _startTransitionTimer() {
    Timer(_splashHold, () async {
      if (mounted) {
        User? user;
        try {
          user = FirebaseAuth.instance.currentUser;
        } catch (_) {}
        bool isOfflineLoggedIn = false;
        try {
          final prefs = await SharedPreferences.getInstance();
          isOfflineLoggedIn = prefs.getBool('is_offline_logged_in') ?? false;
        } catch (_) {}

        final Widget nextScreen = (user != null || isOfflineLoggedIn)
            ? (widget.homeScreenOverride ?? const HomeScreen())
            : (widget.loginScreenOverride ?? const LoginScreen());

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            settings: RouteSettings(
              name: (user != null || isOfflineLoggedIn)
                  ? HomeScreen.routeName
                  : LoginScreen.routeName,
            ),
            pageBuilder: (context, animation, secondaryAnimation) =>
                nextScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: _fadeDuration,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo/app_logo.png',
                height: _logoHeight,
              ),
              SizedBox(height: spacing.xxl),
              Text(
                'DriveCare+',
                style: typography.headlineLarge.copyWith(
                  color: colors.foreground,
                ),
              ),
              SizedBox(height: spacing.sm),
              Text(
                'Smart vehicle maintenance and trip tracker',
                textAlign: TextAlign.center,
                style: typography.bodyLarge.copyWith(
                  color: mutedForeground,
                ),
              ),
              SizedBox(height: spacing.xxxxl),
              const SizedBox(
                width: _progressWidth,
                child: AppSpinner(),
              ),
              SizedBox(height: spacing.lg),
              Text(
                'Loading profile...',
                style: typography.body.copyWith(
                  color: mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }
}
