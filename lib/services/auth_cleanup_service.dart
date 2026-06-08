import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_service.dart';
import 'vehicle_insights.dart';
import 'notification_service.dart';
import 'notification_preferences.dart';
import 'theme_service.dart';
import 'journey_database.dart';

class AuthCleanupService {
  /// Clears all local user-specific data from database, preferences, and service memory.
  static Future<void> clearAllData() async {
    debugPrint('AuthCleanupService: Starting cleanup process...');

    // 1. Clear SharedPreferences
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('AuthCleanupService: SharedPreferences cleared.');
    } catch (e) {
      debugPrint('AuthCleanupService Error: clearing SharedPreferences: $e');
    }

    // 2. Clear SQL Database
    try {
      final db = await JourneyDatabase.instance.database;
      await db.delete('journeys');
      await db.delete('journey_points');
      debugPrint('AuthCleanupService: SQLite JourneyDatabase cleared.');
    } catch (e) {
      debugPrint('AuthCleanupService Error: clearing journeys database: $e');
    }

    // 3. Reset in-memory services to their initial states
    try {
      await ProfileService.instance.clearProfile();
      debugPrint('AuthCleanupService: ProfileService memory cleared.');
    } catch (e) {
      debugPrint('AuthCleanupService Error: clearing ProfileService: $e');
    }

    try {
      await VehicleInsights.instance.clear();
      debugPrint('AuthCleanupService: VehicleInsights memory cleared.');
    } catch (e) {
      debugPrint('AuthCleanupService Error: clearing VehicleInsights: $e');
    }

    try {
      await NotificationService.instance.clearAll();
      debugPrint('AuthCleanupService: NotificationService inbox cleared.');
    } catch (e) {
      debugPrint('AuthCleanupService Error: clearing NotificationService: $e');
    }

    try {
      NotificationPreferences.instance.reset();
      debugPrint('AuthCleanupService: NotificationPreferences reset to default.');
    } catch (e) {
      debugPrint('AuthCleanupService Error: resetting NotificationPreferences: $e');
    }

    // 4. Reset ThemeService (wiping preferences will make it use defaults)
    try {
      await ThemeService.instance.init();
      debugPrint('AuthCleanupService: ThemeService re-initialized to default.');
    } catch (e) {
      debugPrint('AuthCleanupService Error: resetting ThemeService: $e');
    }

    debugPrint('AuthCleanupService: Cleanup process completed successfully.');
  }

  /// Re-loads/initializes user data services on successful login/registration.
  static Future<void> initializeUserData() async {
    debugPrint('AuthCleanupService: Initializing user data services...');
    try {
      await ThemeService.instance.init();
      await ProfileService.instance.init();
      await NotificationPreferences.instance.init();
      await NotificationService.instance.init();
      await VehicleInsights.instance.loadFromPrefs();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await VehicleInsights.instance.syncFromFirestore(user.uid);
      }
      
      debugPrint('AuthCleanupService: User data services initialized successfully.');
    } catch (e) {
      debugPrint('AuthCleanupService Error: initializing user data: $e');
    }
  }
}
