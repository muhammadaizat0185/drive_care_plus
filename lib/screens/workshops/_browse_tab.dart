import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../core/util/search_filter.dart';
import '../../core/util/single_select_controller.dart';
import '../../models/workshop.dart';
import '../../widgets/ui/ui.dart';
import '_workshop_card.dart';

/// Visual mode for the Browse tab content area: list of cards or
/// `GoogleMap`. Default is [list] per Requirement 7.4.
enum BrowseViewMode { list, map }

/// Browse-tab body for the redesigned `workshop_map_screen` (Tasks 9.3,
/// 9.4, 9.5, 9.12).
///
/// Pulls together the search field + filter icon (Task 9.3), the category
/// chip row (Task 9.3), the list/map toggle (Task 9.5), the list rendered
/// through [filterWorkshops] (Task 9.4), the empty state when filtering
/// returns nothing (Task 9.12), and the [GoogleMap] preserved unchanged
/// for the map view (Task 9.5).
///
/// All visual constants come from the design-token extensions on
/// `Theme.of(context)`; no hex colors, spacing, radii, or typography
/// literals from the Token_Sets are inlined (Requirement 3.11).
class BrowseTab extends StatefulWidget {
  /// Source list of workshops. When empty, the filter result is also
  /// empty and the empty state is shown.
  final List<Workshop> workshops;

  /// Set of workshop ids the user has favorited. Drives the heart fill
  /// state on each card. The controlling screen owns the optimistic
  /// update; this widget only renders.
  final Set<String> favorites;

  /// Card body tap → workshop detail bottom sheet (Task 9.10).
  final void Function(Workshop)? onWorkshopTap;

  /// Heart toggle → optimistic favorite update (Task 9.8).
  final void Function(Workshop)? onFavoriteToggle;

  /// Navigate button tap on a card (Task 9.6 footer).
  final void Function(Workshop)? onNavigate;

  /// Book Now button tap on a card (Task 9.6 footer).
  final void Function(Workshop)? onBook;

  /// Initial camera position for the map view. The controlling screen
  /// resolves the user's location upstream so this widget receives a
  /// concrete starting position.
  final CameraPosition initialCameraPosition;

  const BrowseTab({
    super.key,
    required this.workshops,
    required this.initialCameraPosition,
    this.favorites = const <String>{},
    this.onWorkshopTap,
    this.onFavoriteToggle,
    this.onNavigate,
    this.onBook,
  });

  @override
  State<BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<BrowseTab> {
  final TextEditingController _searchController = TextEditingController();
  late final SingleSelectController<String> _categoryController;
  BrowseViewMode _viewMode = BrowseViewMode.list;

  // Chip labels mirror the design's Browse chip row exactly. The first
  // label is the "All" sentinel that disables the per-element category
  // check inside [filterWorkshops]. The remaining labels match
  // `WorkshopCategory.{repair, carWash, parts}.name` so the filter helper
  // can compare them via `Workshop.category.name`.
  static const String _allLabel = 'All';
  static const Map<String, String> _categoryLabels = <String, String>{
    'All': 'all',
    'Repair': 'repair',
    'Car Wash': 'carWash',
    'Parts': 'parts',
  };

  @override
  void initState() {
    super.initState();
    _categoryController = SingleSelectController<String>(
      values: _categoryLabels.keys.toList(growable: false),
      initial: _allLabel,
    );
    _categoryController.addListener(_onChange);
    _searchController.addListener(_onChange);
  }

  @override
  void dispose() {
    _categoryController.removeListener(_onChange);
    _searchController.removeListener(_onChange);
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// Resolves the chip label currently selected (e.g. `'Car Wash'`) to
  /// the canonical category key the filter compares against
  /// (`'carWash'`). The "All" sentinel is passed through verbatim because
  /// [filterWorkshops] case-insensitively recognises it as the
  /// disable-category-check value.
  String get _activeCategoryKey {
    final String? selected = _categoryController.selected;
    if (selected == null || selected == _allLabel) {
      return 'all';
    }
    return _categoryLabels[selected] ?? 'all';
  }

  List<Workshop> get _filtered => filterWorkshops(
        widget.workshops,
        _searchController.text,
        _activeCategoryKey,
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final List<Workshop> visible = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.md,
            spacing.lg,
            spacing.sm,
          ),
          child: AppTextField(
            controller: _searchController,
            hintText: 'Search workshops',
            prefixIcon: Icons.search,
            suffix: AppIconButton(
              icon: Icons.tune,
              onPressed: () {},
              semanticsLabel: 'Filters',
            ),
          ),
        ),
        // Category chip row — single-selection via SingleSelectController.
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            itemCount: _categoryLabels.length,
            separatorBuilder: (BuildContext _, int _) =>
                SizedBox(width: spacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final String label =
                  _categoryLabels.keys.elementAt(index);
              return AppCategoryChip(
                label: label,
                selected: _categoryController.selected == label,
                onTap: () => _categoryController.select(label),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _ViewModeToggle(
                mode: _viewMode,
                onChanged: (BrowseViewMode mode) {
                  setState(() => _viewMode = mode);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _viewMode == BrowseViewMode.list
              ? _buildList(visible)
              : _buildMap(visible),
        ),
      ],
    );
  }

  Widget _buildList(List<Workshop> visible) {
    if (visible.isEmpty) {
      return const AppEmptyState(
        key: ValueKey<String>('workshops_browse_empty'),
        icon: Icons.search_off,
        title: 'No workshops found',
        message: 'Try a different search term or category.',
      );
    }
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    return ListView.separated(
      key: const ValueKey<String>('workshops_browse_list'),
      padding: EdgeInsets.all(spacing.lg),
      itemCount: visible.length,
      separatorBuilder: (BuildContext _, int _) =>
          SizedBox(height: spacing.md),
      itemBuilder: (BuildContext context, int index) {
        final Workshop workshop = visible[index];
        return WorkshopCard(
          workshop: workshop,
          specialties: _specialtiesFor(workshop),
          isFavorite: widget.favorites.contains(workshop.id),
          onTap: widget.onWorkshopTap == null
              ? null
              : () => widget.onWorkshopTap!(workshop),
          onFavoriteToggle: widget.onFavoriteToggle == null
              ? null
              : () => widget.onFavoriteToggle!(workshop),
          onNavigate: widget.onNavigate == null
              ? null
              : () => widget.onNavigate!(workshop),
          onBook: widget.onBook == null
              ? null
              : () => widget.onBook!(workshop),
        );
      },
    );
  }

  Widget _buildMap(List<Workshop> visible) {
    final Set<Marker> markers = <Marker>{
      for (final Workshop w in visible)
        if (w.location != null)
          Marker(
            markerId: MarkerId(w.id),
            position: w.location!,
            infoWindow: InfoWindow(title: w.name),
          ),
    };
    return GoogleMap(
      key: const ValueKey<String>('workshops_browse_map'),
      initialCameraPosition: widget.initialCameraPosition,
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  /// Derives a small set of specialty labels from a workshop's `types`.
  /// Translates common Google-Places type keys into user-facing copy and
  /// drops anything we do not have a label for so the chip row never
  /// renders an opaque taxonomy code.
  List<String> _specialtiesFor(Workshop workshop) {
    const Map<String, String> labels = <String, String>{
      'car_repair': 'Repair',
      'car_repairer': 'Repair',
      'car_wash': 'Car Wash',
      'car_dealer': 'Dealer',
      'gas_station': 'Fuel',
      'tire_shop': 'Tires',
      'auto_parts_store': 'Parts',
      'electric_vehicle_charging_station': 'EV',
    };
    final List<String> mapped = <String>[];
    for (final String t in workshop.types) {
      final String? label = labels[t];
      if (label != null && !mapped.contains(label)) {
        mapped.add(label);
      }
    }
    if (mapped.isEmpty) {
      mapped.add(workshop.category.name);
    }
    return mapped;
  }
}

/// list/map view mode toggle. Two icon buttons inside a rounded surface;
/// the selected mode uses the brand emerald foreground while the other
/// uses muted-foreground.
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChanged});

  final BrowseViewMode mode;
  final ValueChanged<BrowseViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    return Container(
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(radii.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppIconButton(
            icon: Icons.view_list,
            onPressed: () => onChanged(BrowseViewMode.list),
            semanticsLabel: 'List view',
            color: mode == BrowseViewMode.list
                ? colors.emerald500
                : colors.foreground
                    .withValues(alpha: colors.surfaceProminent),
          ),
          AppIconButton(
            icon: Icons.map_outlined,
            onPressed: () => onChanged(BrowseViewMode.map),
            semanticsLabel: 'Map view',
            color: mode == BrowseViewMode.map
                ? colors.emerald500
                : colors.foreground
                    .withValues(alpha: colors.surfaceProminent),
          ),
        ],
      ),
    );
  }
}
