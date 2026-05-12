import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/booking_screen.dart';
import 'screens/document_vault_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/refuel_log_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/trip_tracking_screen.dart';
import 'screens/vehicle_screen.dart';
import 'screens/workshop_map_screen.dart';
import 'services/theme_service.dart';

class DriveCarePlusApp extends StatelessWidget {
  const DriveCarePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final themeService = ThemeService.instance;
        return MaterialApp(
          title: 'DriveCare+',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.buildTheme(themeService.primaryColor, Brightness.light),
          darkTheme: AppTheme.buildTheme(themeService.primaryColor, Brightness.dark),
          themeMode: themeService.themeMode,
          initialRoute: SplashScreen.routeName,
          routes: {
            SplashScreen.routeName: (_) => const SplashScreen(),
            LoginScreen.routeName: (_) => const LoginScreen(),
            RegisterScreen.routeName: (_) => const RegisterScreen(),
            HomeScreen.routeName: (_) => const HomeScreen(),
            VehicleScreen.routeName: (_) => const VehicleScreen(),
            MaintenanceScreen.routeName: (_) => const MaintenanceScreen(),
            TripTrackingScreen.routeName: (_) => const TripTrackingScreen(),
            BookingScreen.routeName: (_) => const BookingScreen(),
            RefuelLogScreen.routeName: (_) => const RefuelLogScreen(),
            WorkshopMapScreen.routeName: (_) => const WorkshopMapScreen(),
            DocumentVaultScreen.routeName: (_) => const DocumentVaultScreen(),
            NotificationsScreen.routeName: (_) => const NotificationsScreen(),
            SettingsScreen.routeName: (_) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
