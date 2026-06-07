import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

/// Shared test scaffolding for the Component_Library widget suite.
///
/// Each widget test in `test/widgets/ui/` is rendered through
/// [hostApp] so the design-token `ThemeExtension`s registered in
/// `AppTheme.buildTheme` are present at the call site (`Theme.of` →
/// `extension<AppColorsExt>` etc.).
///
/// `brightness` flips between `Brightness.light` and `Brightness.dark`
/// so visual contracts that vary by mode (e.g. text-field border using
/// `AppColors.lightBorder` vs `AppColors.darkBorder`) can be asserted
/// in both modes from the same test.
Widget hostApp({
  required Widget child,
  Brightness brightness = Brightness.light,
}) {
  final ThemeData theme =
      AppTheme.buildTheme(AppColors.emerald500, brightness);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Scaffold(body: child),
  );
}
