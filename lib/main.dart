import 'package:flutter/material.dart';

import 'app.dart';
import 'services/firebase_bootstrap.dart';
import 'services/profile_service.dart';
import 'services/theme_service.dart';
import 'services/vehicle_insights.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  // Pre-load local vehicle caching & dynamic theme cache
  await VehicleInsights.instance.loadFromPrefs();
  await ThemeService.instance.init();
  await ProfileService.instance.init();
  runApp(const DriveCarePlusApp());
}
