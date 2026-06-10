// Phase 2 — Trip Confirmation bottom sheet.
//
// Allows bulk attribution of all PENDING_CONFIRMATION journeys for a given
// day. Features:
//   • Master vehicle selector that propagates to all trip cards.
//   • Per-trip chip override to correct individual attributions.
//   • "Confirm All" writes attribution via JourneyDatabase.updateJourneyAttribution
//     and triggers VehicleInsights.updateCurrentMileageForVehicle for each
//     confirmed-my-car entry.
//
// Usage:
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     builder: (_) => TripConfirmationSheet(
//       pendingJourneys: journeys,
//       registeredVehicles: vehicles,
//       onConfirmed: () { /* refresh */ },
//     ),
//   );

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/color_utils.dart';
import '../../core/theme/tokens/tokens.dart';
import '../../services/audio_service.dart';
import '../../services/journey_database.dart';
import '../../services/vehicle_insights.dart';
import '../../widgets/ui/ui.dart';

/// Possible attribution choices for a single journey.
enum _TripAttribution { vehicle, other, publicTransport, passenger }

/// Per-trip state held in the sheet's local state map.
class _TripState {
  _TripAttribution attribution;
  String? vehicleId; // only set when attribution == vehicle

  _TripState({required this.attribution, this.vehicleId});

  _TripState copyWith({_TripAttribution? attribution, String? vehicleId}) =>
      _TripState(
        attribution: attribution ?? this.attribution,
        vehicleId: vehicleId ?? this.vehicleId,
      );
}

class TripConfirmationSheet extends StatefulWidget {
  final List<Map<String, dynamic>> pendingJourneys;

  /// All vehicles from [VehicleInsights._vehicles].
  final List<Map<String, dynamic>> registeredVehicles;

  /// Called after all attributions are committed so the parent can refresh.
  final VoidCallback onConfirmed;

  const TripConfirmationSheet({
    super.key,
    required this.pendingJourneys,
    required this.registeredVehicles,
    required this.onConfirmed,
  });

  @override
  State<TripConfirmationSheet> createState() => _TripConfirmationSheetState();
}

class _TripConfirmationSheetState extends State<TripConfirmationSheet> {
  // journeyId → _TripState
  late Map<int, _TripState> _attributions;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _attributions = {
      for (final j in widget.pendingJourneys)
        (j['id'] as int): _TripState(attribution: _TripAttribution.vehicle),
    };
    // Default to first registered vehicle for all trips if available.
    if (widget.registeredVehicles.isNotEmpty) {
      final defaultId = widget.registeredVehicles.first['id']?.toString();
      for (final id in _attributions.keys) {
        _attributions[id] = _TripState(
          attribution: _TripAttribution.vehicle,
          vehicleId: defaultId,
        );
      }
    }
  }

  /// Applies a master selection to all trips.
  void _applyMaster(_TripAttribution attr, {String? vehicleId}) {
    setState(() {
      for (final id in _attributions.keys) {
        _attributions[id] = _TripState(
          attribution: attr,
          vehicleId: vehicleId,
        );
      }
    });
  }

  Future<void> _confirmAll() async {
    setState(() => _isConfirming = true);
    try {
      for (final entry in _attributions.entries) {
        final journeyId = entry.key;
        final state = entry.value;

        switch (state.attribution) {
          case _TripAttribution.vehicle:
            await JourneyDatabase.instance.updateJourneyAttribution(
              journeyId,
              vehicleId: state.vehicleId,
              vehicleType: 'my_car',
              transportMode: 'driving',
              source: 'user_confirmed',
            );
            // Update vehicle odometer immediately if we have distance data.
            if (state.vehicleId != null) {
              final journeys =
                  await JourneyDatabase.instance.getJourneys();
              final j = journeys.firstWhere((j) => j['id'] == journeyId,
                  orElse: () => {});
              final distKm =
                  (j['distance_km'] as num?)?.toDouble() ?? 0.0;
              if (distKm > 0) {
                await VehicleInsights.instance.updateCurrentMileageForVehicle(
                  vehicleId: state.vehicleId!,
                  additionalKm: distKm,
                );
              }
            }
            break;

          case _TripAttribution.other:
            await JourneyDatabase.instance.updateJourneyAttribution(
              journeyId,
              vehicleType: 'other',
              transportMode: 'other',
              source: 'user_confirmed',
            );
            break;

          case _TripAttribution.publicTransport:
            await JourneyDatabase.instance.updateJourneyAttribution(
              journeyId,
              vehicleType: 'public_transport',
              transportMode: 'bus',
              source: 'user_confirmed',
            );
            break;

          case _TripAttribution.passenger:
            await JourneyDatabase.instance.updateJourneyAttribution(
              journeyId,
              vehicleType: 'other',
              transportMode: 'other',
              source: 'user_confirmed',
            );
            break;
        }
      }

      if (mounted) Navigator.of(context).pop();
      widget.onConfirmed();
    } catch (e) {
      debugPrint('TripConfirmationSheet confirm error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving confirmations.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '--';
    return DateFormat('HH:mm').format(DateTime.parse(isoString));
  }

  String _formatDistance(double? km) {
    if (km == null) return '--';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    final AppShadowsExt shadows = theme.extension<AppShadowsExt>()!;

    final Color mutedFg =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(radii.xLarge)),
            boxShadow: shadows.large,
          ),
          child: Column(
            children: [
              // Grab handle
              SizedBox(height: spacing.md),
              Center(
                child: Container(
                  width: spacing.xxxl,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.muted,
                    borderRadius: BorderRadius.circular(radii.small),
                  ),
                ),
              ),
              SizedBox(height: spacing.lg),

              // Header
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: spacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Confirm Your Trips',
                            style: typography.title
                                .copyWith(color: colors.foreground)),
                        Text(
                          '${widget.pendingJourneys.length} unconfirmed',
                          style:
                              typography.body.copyWith(color: mutedFg),
                        ),
                      ],
                    ),
                    AppIconButton(
                      icon: Icons.close,
                      semanticsLabel: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.lg),

              // Master vehicle selector
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: spacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apply to all trips:',
                        style: typography.label
                            .copyWith(color: mutedFg)),
                    SizedBox(height: spacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...widget.registeredVehicles.map((v) {
                            final id = v['id']?.toString();
                            final model =
                                v['model']?.toString() ?? 'Vehicle';
                            return Padding(
                              padding: EdgeInsets.only(right: spacing.sm),
                              child: _MasterChip(
                                label: model,
                                icon: Icons.directions_car_outlined,
                                color: colors.emerald500,
                                onTap: () => _applyMaster(
                                    _TripAttribution.vehicle,
                                    vehicleId: id),
                              ),
                            );
                          }),
                          Padding(
                            padding: EdgeInsets.only(right: spacing.sm),
                            child: _MasterChip(
                              label: 'Public Transport',
                              icon: Icons.directions_bus_outlined,
                              color: colors.muted,
                              onTap: () => _applyMaster(
                                  _TripAttribution.publicTransport),
                            ),
                          ),
                          _MasterChip(
                            label: 'Not My Car',
                            icon: Icons.block_outlined,
                            color: mutedFg,
                            onTap: () =>
                                _applyMaster(_TripAttribution.other),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: spacing.xl, color: colors.border),

              // Trip list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: spacing.xl),
                  itemCount: widget.pendingJourneys.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: spacing.md),
                  itemBuilder: (context, index) {
                    final journey = widget.pendingJourneys[index];
                    final id = journey['id'] as int;
                    final state = _attributions[id]!;

                    return _TripConfirmationCard(
                      journey: journey,
                      state: state,
                      registeredVehicles: widget.registeredVehicles,
                      colors: colors,
                      spacing: spacing,
                      radii: radii,
                      typography: typography,
                      mutedFg: mutedFg,
                      formatTime: _formatTime,
                      formatDistance: _formatDistance,
                      onChanged: (newState) {
                        setState(() => _attributions[id] = newState);
                      },
                    );
                  },
                ),
              ),

              // Confirm All CTA
              Padding(
                padding: EdgeInsets.fromLTRB(
                    spacing.xl, spacing.md, spacing.xl, spacing.xl),
                child: _isConfirming
                    ? const Center(child: AppSpinner())
                    : AppGradientButton(
                        label: 'Confirm All Trips',
                        icon: Icons.check_circle_outline,
                        onPressed: _confirmAll,
                        soundType: ButtonSoundType.save,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _MasterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MasterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final AppSpacingExt spacing = Theme.of(context).extension<AppSpacingExt>()!;
    final AppRadiiExt radii = Theme.of(context).extension<AppRadiiExt>()!;
    final AppTypographyExt typography =
        Theme.of(context).extension<AppTypographyExt>()!;
    final AppColorsExt colors = Theme.of(context).extension<AppColorsExt>()!;

    return GestureDetector(
      onTap: () {
        AudioService.instance.button(ButtonSoundType.toggle);
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: spacing.md, vertical: spacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: colors.surfaceMedium),
          borderRadius: BorderRadius.circular(radii.large),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: spacing.xs),
            Text(label,
                style: typography.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _TripConfirmationCard extends StatelessWidget {
  final Map<String, dynamic> journey;
  final _TripState state;
  final List<Map<String, dynamic>> registeredVehicles;
  final AppColorsExt colors;
  final AppSpacingExt spacing;
  final AppRadiiExt radii;
  final AppTypographyExt typography;
  final Color mutedFg;
  final String Function(String?) formatTime;
  final String Function(double?) formatDistance;
  final ValueChanged<_TripState> onChanged;

  const _TripConfirmationCard({
    required this.journey,
    required this.state,
    required this.registeredVehicles,
    required this.colors,
    required this.spacing,
    required this.radii,
    required this.typography,
    required this.mutedFg,
    required this.formatTime,
    required this.formatDistance,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        state.attribution == _TripAttribution.vehicle
            ? colors.emerald500
            : state.attribution == _TripAttribution.publicTransport
                ? colors.muted
                : mutedFg;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time + distance row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatTime(journey['start_time'])} → ${formatTime(journey['end_time'])}',
                style: typography.label.copyWith(color: mutedFg),
              ),
              Text(
                formatDistance((journey['distance_km'] as num?)?.toDouble()),
                style: typography.bodyLarge.copyWith(color: colors.foreground),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            '${journey['start_address'] ?? 'Unknown'} → ${journey['destination_address'] ?? 'Unknown'}',
            style: typography.body.copyWith(color: colors.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: spacing.md),

          // Per-trip attribution chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Registered vehicle chips
                ...registeredVehicles.map((v) {
                  final id = v['id']?.toString();
                  final model = v['model']?.toString() ?? 'Vehicle';
                  final isSelected = state.attribution ==
                          _TripAttribution.vehicle &&
                      state.vehicleId == id;
                  return Padding(
                    padding: EdgeInsets.only(right: spacing.xs),
                    child: _AttributionChip(
                      label: model,
                      icon: Icons.directions_car_outlined,
                      isSelected: isSelected,
                      selectedColor: colors.emerald500,
                      colors: colors,
                      spacing: spacing,
                      radii: radii,
                      typography: typography,
                      onTap: () => onChanged(_TripState(
                          attribution: _TripAttribution.vehicle,
                          vehicleId: id)),
                    ),
                  );
                }),
                Padding(
                  padding: EdgeInsets.only(right: spacing.xs),
                  child: _AttributionChip(
                    label: 'Bus / Train',
                    icon: Icons.directions_bus_outlined,
                    isSelected:
                        state.attribution == _TripAttribution.publicTransport,
                    selectedColor: colors.muted,
                    colors: colors,
                    spacing: spacing,
                    radii: radii,
                    typography: typography,
                    onTap: () => onChanged(
                        _TripState(attribution: _TripAttribution.publicTransport)),
                  ),
                ),
                _AttributionChip(
                  label: 'Other',
                  icon: Icons.block_outlined,
                  isSelected: state.attribution == _TripAttribution.other ||
                      state.attribution == _TripAttribution.passenger,
                  selectedColor: mutedFg,
                  colors: colors,
                  spacing: spacing,
                  radii: radii,
                  typography: typography,
                  onTap: () =>
                      onChanged(_TripState(attribution: _TripAttribution.other)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final AppColorsExt colors;
  final AppSpacingExt spacing;
  final AppRadiiExt radii;
  final AppTypographyExt typography;
  final VoidCallback onTap;

  const _AttributionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.colors,
    required this.spacing,
    required this.radii,
    required this.typography,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = isSelected ? selectedColor : colors.foreground.withValues(alpha: colors.surfaceProminent + 0.3);
    final Color bg = isSelected
        ? selectedColor.withValues(alpha: colors.surfaceMedium)
        : colors.muted;

    return GestureDetector(
      onTap: () {
        AudioService.instance.button(ButtonSoundType.toggle);
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: spacing.md, vertical: spacing.xs),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radii.large),
          border: Border.all(
            color: isSelected ? selectedColor : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            SizedBox(width: spacing.xs),
            Text(label, style: typography.label.copyWith(color: fg)),
            if (isSelected) ...[
              SizedBox(width: spacing.xs),
              Icon(Icons.check, size: 12, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}
