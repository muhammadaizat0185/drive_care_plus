import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/audio_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/notification_preferences.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/theme_service.dart';
import 'services/vehicle_insights.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await const MethodChannel('com.drivecare.plus/bluetooth').invokeMethod('clearSecureFlags');
  } catch (e) {
    debugPrint('Failed to clear secure flags: $e');
  }
  await FirebaseBootstrap.initialize();
  // Pre-load local vehicle caching & dynamic theme cache
  await AudioService.instance.init();
  await VehicleInsights.instance.loadFromPrefs();
  await ThemeService.instance.init();
  await ProfileService.instance.init();
  // Fix: init notification preferences so persisted toggles survive restarts
  await NotificationPreferences.instance.init();
  // Init notification service and check for overdue maintenance items
  await NotificationService.instance.init();
  await NotificationService.instance.checkAndSendMaintenanceReminders();
  // Phase 3: Register/refresh the daily 9 PM trip-review notification and
  // fire an immediate review prompt if there are unconfirmed journeys.
  await NotificationService.instance.scheduleDailyTripReviewNotification();
  unawaited(NotificationService.instance.checkAndSendTripReviewIfNeeded());
  runApp(const DriveCarePlusApp());
}

