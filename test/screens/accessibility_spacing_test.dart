import 'dart:math' as math;
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/screens/login_screen.dart';
import 'package:drive_care_plus/screens/register_screen.dart';
import 'package:drive_care_plus/screens/notifications_screen.dart';
import 'package:drive_care_plus/screens/maintenance_screen.dart';
import 'package:drive_care_plus/widgets/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget hostApp(Widget child) {
  final ThemeData theme = AppTheme.buildTheme(AppColors.emerald500, Brightness.light);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Scaffold(body: child),
  );
}

double distanceBetweenRects(Rect a, Rect b) {
  final double xDist = (a.left > b.right) ? (a.left - b.right) : ((b.left > a.right) ? (b.left - a.right) : 0);
  final double yDist = (a.top > b.bottom) ? (a.top - b.bottom) : ((b.top > a.bottom) ? (b.top - a.bottom) : 0);
  
  if (xDist == 0 && yDist == 0) {
    return 0; // Overlapping or nested
  }
  
  if (xDist > 0 && yDist > 0) {
    return math.sqrt(xDist * xDist + yDist * yDist);
  }
  
  return math.max(xDist, yDist);
}

void auditInteractiveSpacing(WidgetTester tester, String screenName) {
  // Find all elements that are potentially interactive
  final List<Element> elements = tester.elementList(
    find.byElementPredicate((e) {
      final widget = e.widget;
      return widget is AppPrimaryButton ||
          widget is AppSecondaryButton ||
          widget is AppIconButton ||
          widget is AppGradientButton ||
          widget is AppToggleSwitch ||
          widget is AppCategoryChip ||
          widget is AppTextField ||
          widget is GestureDetector ||
          widget is InkWell;
    }),
  ).toList();

  final List<({Rect rect, Widget widget})> targets = [];

  for (final Element e in elements) {
    final RenderObject? renderObject = e.renderObject;
    if (renderObject is RenderBox && renderObject.hasSize && renderObject.attached) {
      final translation = renderObject.getTransformTo(null).getTranslation();
      final Offset offset = Offset(translation.x, translation.y);
      final Rect rect = offset & renderObject.size;
      
      // Filter out duplicates with the exact same rectangle to avoid false positives
      if (!targets.any((t) => t.rect == rect)) {
        targets.add((rect: rect, widget: e.widget));
      }
    }
  }

  // Compare every pair
  for (int i = 0; i < targets.length; i++) {
    for (int j = i + 1; j < targets.length; j++) {
      final a = targets[i];
      final b = targets[j];

      // Check if one contains the other (nested elements like gesture inside button are fine)
      final bool nested = a.rect.contains(b.rect.center) || b.rect.contains(a.rect.center);
      if (nested) {
        continue;
      }

      final double distance = distanceBetweenRects(a.rect, b.rect);
      if (distance > 0 && distance < 8.0) {
        fail(
          'Spacing violation on $screenName: adjacent interactive touch targets are too close!\n'
          'Target A: ${a.widget.runtimeType} at ${a.rect}\n'
          'Target B: ${b.widget.runtimeType} at ${b.rect}\n'
          'Distance is only ${distance.toStringAsFixed(2)} logical pixels (must be >= 8.0 per Requirement 13.4).'
        );
      }
    }
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Property 13.4: Adjacent Touch Target Spacing Gap (Task 16.4)', () {
    testWidgets('LoginScreen spacing audit passes', (tester) async {
      await tester.pumpWidget(hostApp(const LoginScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      auditInteractiveSpacing(tester, 'LoginScreen');
    });

    testWidgets('RegisterScreen spacing audit passes', (tester) async {
      await tester.pumpWidget(hostApp(const RegisterScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      auditInteractiveSpacing(tester, 'RegisterScreen');
    });

    testWidgets('NotificationsScreen spacing audit passes', (tester) async {
      await tester.pumpWidget(hostApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      auditInteractiveSpacing(tester, 'NotificationsScreen');
    });

    testWidgets('MaintenanceScreen spacing audit passes', (tester) async {
      await tester.pumpWidget(hostApp(const MaintenanceScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      auditInteractiveSpacing(tester, 'MaintenanceScreen');
    });
  });
}
