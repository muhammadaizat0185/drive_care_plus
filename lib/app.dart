import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/tokens/app_colors.dart';
import 'screens/booking_screen.dart';
import 'screens/document_vault/_widgets.dart';
import 'screens/document_vault_screen.dart';
import 'screens/document_viewer_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/refuel_log_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/trip_tracking_screen.dart';
import 'screens/vehicle_customizer_screen.dart';
import 'screens/vehicle_screen.dart';
import 'screens/workshop_map_screen.dart';
import 'screens/wallet_history_screen.dart';
import 'services/theme_service.dart';

/// Root application widget.
///
/// Listens to `ThemeService` and, on every change, asks
/// `AppTheme.buildThemePair(seed)` for both the light and dark `ThemeData`
/// instances at once. The pair is cached in `_cachedPair`; if the
/// derivation throws for any reason, the cached pair is reused without
/// partial updates so `MaterialApp.theme` and `MaterialApp.darkTheme`
/// always move in lockstep (Requirements 2.6, 2.8).
class DriveCarePlusApp extends StatefulWidget {
  const DriveCarePlusApp({super.key});

  @override
  State<DriveCarePlusApp> createState() => _DriveCarePlusAppState();
}

class _DriveCarePlusAppState extends State<DriveCarePlusApp> {
  /// Last successfully built `(light, dark)` pair. Initialised eagerly in
  /// `initState` from the current `ThemeService.primaryColor` so the first
  /// frame already has a valid pair to render. Only ever reassigned to a
  /// fully-built pair, never partially updated.
  ({ThemeData light, ThemeData dark})? _cachedPair;

  @override
  void initState() {
    super.initState();
    _cachedPair = _safeBuildPair(ThemeService.instance.primaryColor);
  }

  /// Wraps `AppTheme.buildThemePair` in a try/catch. On failure, falls back
  /// to the canonical brand seed (`AppColors.emerald500`) so the very first
  /// build in `initState` cannot leave the app without a theme.
  ({ThemeData light, ThemeData dark}) _safeBuildPair(Color seed) {
    try {
      return AppTheme.buildThemePair(seed);
    } catch (e, st) {
      debugPrint('AppTheme.buildThemePair failed for seed $seed: $e\n$st');
      // Last-resort fallback: the canonical brand seed must always succeed
      // because all token values feeding it are compile-time constants.
      return AppTheme.buildThemePair(AppColors.emerald500);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final themeService = ThemeService.instance;
        // Atomic theme rebuild: build the entire pair, only commit on
        // success (Requirements 2.6, 2.8).
        try {
          final pair = AppTheme.buildThemePair(themeService.primaryColor);
          _cachedPair = pair;
        } catch (e, st) {
          debugPrint(
            'AppTheme.buildThemePair failed for seed '
            '${themeService.primaryColor}: $e\n$st',
          );
          // Re-use the cached pair without partial updates. If no cache
          // exists yet (extremely unlikely — initState seeds it), fall
          // back to the canonical brand seed.
          _cachedPair ??= AppTheme.buildThemePair(AppColors.emerald500);
        }

        final pair = _cachedPair!;
        return MaterialApp(
          title: 'DriveCare+',
          debugShowCheckedModeBanner: false,
          theme: pair.light,
          darkTheme: pair.dark,
          themeMode: themeService.themeMode,
          initialRoute: SplashScreen.routeName,
          routes: {
            SplashScreen.routeName: (_) => const SplashScreen(),
            LoginScreen.routeName: (_) => const LoginScreen(),
            RegisterScreen.routeName: (_) => const RegisterScreen(),
            HomeScreen.routeName: (_) => const HomeScreen(),
            VehicleScreen.routeName: (_) => const VehicleScreen(),
            VehicleCustomizerScreen.routeName: (_) =>
                const VehicleCustomizerScreen(),
            MaintenanceScreen.routeName: (_) => const MaintenanceScreen(),
            TripTrackingScreen.routeName: (_) => const TripTrackingScreen(),
            BookingScreen.routeName: (_) => const BookingScreen(),
            RefuelLogScreen.routeName: (_) => const RefuelLogScreen(),
            WorkshopMapScreen.routeName: (_) => const WorkshopMapScreen(),
            DocumentVaultScreen.routeName: (_) => const DocumentVaultScreen(),
            DocumentViewerScreen.routeName: (context) {
              final VaultDocument document =
                  ModalRoute.of(context)!.settings.arguments as VaultDocument;
              return DocumentViewerScreen(document: document);
            },
            NotificationsScreen.routeName: (_) => const NotificationsScreen(),
            SettingsScreen.routeName: (_) => const SettingsScreen(),
            WalletHistoryScreen.routeName: (_) => const WalletHistoryScreen(),
          },
        );
      },
    );
  }
}
