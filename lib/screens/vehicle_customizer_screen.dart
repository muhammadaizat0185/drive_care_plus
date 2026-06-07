// ignore_for_file: deprecated_member_use
//
// Restyled vehicle customizer for the figma-ui-redesign
// (Task 10.7 — Requirement 8.9).
//
// The restyle applies the DriveCare+ Component_Library widgets
// (`AppGradientButton`, `AppCard`, `AppCategoryChip`,
// `AppFeedbackBanner`) on top of the existing customizer logic. The
// form fields (body-style chip row), validation rules (selected style
// must be one of the supported entries), and save behavior (`await
// VehicleInsights.instance.updateVehicle(...)` followed by
// `Navigator.pop`) are preserved verbatim from the legacy customizer.
//
// `routeName` is exposed so `lib/app.dart` can register the screen and
// the Vehicle screen's hero Edit `AppIconButton` can push it via
// `Navigator.pushNamed(context, VehicleCustomizerScreen.routeName)`
// (Task 10.6 — Requirement 8.8).

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/color_utils.dart';

import '../core/theme/tokens/tokens.dart';
import '../services/profile_service.dart';
import '../services/vehicle_insights.dart';
import '../widgets/ui/ui.dart';
import 'home_screen.dart';

class VehicleCustomizerScreen extends StatefulWidget {
  const VehicleCustomizerScreen({super.key});

  /// Named route registered in `lib/app.dart`.
  static const String routeName = '/vehicle/customizer';

  @override
  State<VehicleCustomizerScreen> createState() =>
      _VehicleCustomizerScreenState();
}

class _VehicleCustomizerScreenState extends State<VehicleCustomizerScreen> {
  /// Supported body-style names (mapped to `assets/images/cars/...` SVGs).
  static const List<String> _carTypes = <String>[
    'sedan',
    'suv',
    'sport',
    'pickup',
    'jeep',
    'coupe',
    'compact',
    'cabriolet',
    'exoraGold',
    'axiaBlue',
    'axiaRed',
    'axiaWhite',
    'exoraBrown',
    'myviBlack',
    'myviBlue',
    'myviRed',
    'myviWhite',
    'sagaBlack',
    'sagaRed',
    'sagaSilver',
  ];

  static const Set<String> _premiumTypes = <String>{
    'exoraGold',
    'axiaBlue',
    'axiaRed',
    'axiaWhite',
    'exoraBrown',
    'myviBlack',
    'myviBlue',
    'myviRed',
    'myviWhite',
    'sagaBlack',
    'sagaRed',
    'sagaSilver',
  };

  late String _selectedType;

  /// Banner copy when a save attempt fails. `null` → no banner rendered.
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _selectedType = VehicleInsights.instance.carType;
  }

  /// Persist the selected body style through the existing
  /// `VehicleInsights.updateVehicle` save behavior. On failure, render
  /// an `AppFeedbackBanner` of kind `error` and retain the user's
  /// selection for retry (mirrors Requirement 6.10's pattern from the
  /// settings save handler).
  Future<void> _handleSave() async {
    setState(() => _saveError = null);
    try {
      final VehicleInsights insights = VehicleInsights.instance;
      await insights.updateVehicle(
        model: insights.model,
        plate: insights.plate,
        fuelType: insights.fuelType,
        currentMileageKm: insights.currentMileageKm,
        carType: _selectedType,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveError = 'Could not save vehicle style: $e');
    }
  }

  String _formatCarType(String type) {
    if (_premiumTypes.contains(type)) {
      final RegExp matchCamelCase = RegExp(r'(^[a-z]+|[A-Z][a-z]*)');
      final List<String> matches = matchCamelCase
          .allMatches(type)
          .map((m) => m.group(0)!)
          .toList();
      if (matches.isNotEmpty) {
        final String capitalized = matches
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
        return capitalized + (ProfileService.instance.isPro ? '' : ' 🔒');
      }
    }
    return type[0].toUpperCase() + type.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: Text(
          'Vehicle style',
          style: typography.headline.copyWith(color: colors.foreground),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(spacing.lg),
          children: <Widget>[
            // Save-failure banner, when present.
            if (_saveError != null) ...<Widget>[
              AppFeedbackBanner(
                kind: FeedbackKind.error,
                message: _saveError!,
                onDismiss: () => setState(() => _saveError = null),
              ),
              SizedBox(height: spacing.lg),
            ],

            // Live preview of the selected body style.
            AppCard(
              padding: EdgeInsets.all(spacing.xl),
              child: Column(
                children: <Widget>[
                  SvgPicture.asset(
                    _premiumTypes.contains(_selectedType)
                        ? 'assets/images/cars/Premium/${_selectedType}_front.svg'
                        : 'assets/images/cars/Car Vector/SVG/${_selectedType}_front.svg',
                    height: 180,
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    _selectedType.toUpperCase(),
                    style: typography.title.copyWith(
                      color: colors.foreground,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: spacing.xl),

            // Body-style chip row — `AppCategoryChip` from the
            // Component_Library so the visuals match the rest of the
            // redesign.
            Text(
              'Choose body style',
              style:
                  typography.headline.copyWith(color: colors.foreground),
            ),
            SizedBox(height: spacing.sm),
            Text(
              'Select the model that best represents your vehicle.',
              style: typography.body.copyWith(
                color: colors.foreground
                    .withValues(alpha: colors.surfaceProminent + 0.4),
              ),
            ),
            SizedBox(height: spacing.lg),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: <Widget>[
                for (final String type in _carTypes)
                  AppCategoryChip(
                    label: _formatCarType(type),
                    selected: _selectedType == type,
                    onTap: () {
                      if (_premiumTypes.contains(type) && !ProfileService.instance.isPro) {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => const ProSubscriptionSheet(),
                        );
                      } else {
                        setState(() => _selectedType = type);
                      }
                    },
                  ),
              ],
            ),

            SizedBox(height: spacing.xxl),

            // Save CTA — `AppGradientButton` so the form's primary action
            // adopts the brand-gradient pill.
            AppGradientButton(
              label: 'Update vehicle style',
              icon: Icons.save_outlined,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    ),);
  }
}
