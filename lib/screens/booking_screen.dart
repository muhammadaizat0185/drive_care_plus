// Token + Component_Library sweep (Group 14, Task 14.1).
//
// Sweep summary:
//   * Hex literals (#0F172A, #F9FAFB, #1E293B, #1F2937) replaced with
//     token-driven background and surface colors.
//   * Search bar swapped to `AppTextField`.
//   * Workshop list cards extracted to `BookingWorkshopCard` (uses
//     `AppCard` + `AppSecondaryButton` + `AppGradientButton`).
//   * Confirmed booking cards extracted to `BookingConfirmedCard`
//     (uses `AppCard`).
//   * Inline `CircularProgressIndicator` swapped to `AppSpinner`.
//   * Empty branches rendered via `AppEmptyState`.
//
// PRESERVED (Requirements 12.6, 14.5):
//   * `Geolocator.checkPermission`, `requestPermission`, `getCurrentPosition`,
//     `distanceBetween` calls unchanged.
//   * `GoogleMapsService.searchNearbyWorkshops(LatLng, maxDistance,
//     includedTypes: [...])` call signature unchanged.
//   * `Workshop.fromGooglePlace(json)` mapping unchanged.
//   * `VehicleInsights.instance.bookings` listener unchanged.
//   * `WorkshopDetailScreen(workshop: workshop)` navigation unchanged.

import 'package:flutter/material.dart';

import '../core/theme/color_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/tokens/tokens.dart';
import '../models/workshop.dart';
import '../services/google_maps_service.dart';
import '../services/vehicle_insights.dart';
import '../services/workshop_firebase_service.dart';
import '../widgets/ui/ui.dart';
import 'booking/_widgets.dart';
import 'workshops/_edit_booking_sheet.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  static const routeName = '/booking';

  // Static notifier to allow programmatic tab selection (0 = Find Workshops, 1 = My Bookings)
  static final ValueNotifier<int> activeTabNotifier = ValueNotifier<int>(0);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = BookingScreen.activeTabNotifier.value;
    BookingScreen.activeTabNotifier.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    BookingScreen.activeTabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        _selectedIndex = BookingScreen.activeTabNotifier.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Also support fallback route arguments if needed (Requirement 14.5).
    final int argTab =
        (ModalRoute.of(context)?.settings.arguments as int?) ?? _selectedIndex;

    return AppBackground(
      child: DefaultTabController(
        key: ValueKey(argTab),
        length: 2,
        initialIndex: argTab,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Workshops & Bookings'),
            bottom: const TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.storefront_outlined),
                  text: 'Find Workshops',
                ),
                Tab(
                  icon: Icon(Icons.event_available_outlined),
                  text: 'My Bookings',
                ),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _FindWorkshopsTab(),
              _MyBookingsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindWorkshopsTab extends StatefulWidget {
  const _FindWorkshopsTab();

  @override
  State<_FindWorkshopsTab> createState() => _FindWorkshopsTabState();
}

class _FindWorkshopsTabState extends State<_FindWorkshopsTab> {
  String selectedCategory = 'Repair';
  String searchQuery = '';
  double maxDistance = 5.0;
  List<Workshop> workshops = [];
  bool isLoading = false;
  Position? currentPosition;
  late final TextEditingController _searchController;

  // Horizontal category row height. Not a Token_Set value.
  static const double _categoryRowHeight = 115;

  final List<Map<String, dynamic>> categories = [
    {'name': 'Carwash', 'icon': Icons.local_car_wash_rounded},
    {'name': 'Repair', 'icon': Icons.build_rounded},
    {'name': 'Car Accessories', 'icon': Icons.settings_input_component_rounded},
    {'name': 'Other', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _getCurrentLocationAndSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocationAndSearch() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
        if (!mounted) return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => currentPosition = position);

      await _searchWorkshops();
    } catch (e) {
      debugPrint('Location Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _searchWorkshops() async {
    if (currentPosition == null || !mounted) return;

    setState(() => isLoading = true);

    List<String>? includedTypes;
    if (selectedCategory == 'Repair') {
      includedTypes = ['car_repair'];
    } else if (selectedCategory == 'Carwash') {
      includedTypes = ['car_wash'];
    } else if (selectedCategory == 'Car Accessories') {
      includedTypes = ['auto_parts_store'];
    }

    final results = await GoogleMapsService.searchNearbyWorkshops(
      LatLng(currentPosition!.latitude, currentPosition!.longitude),
      maxDistance,
      includedTypes: includedTypes,
    );

    if (!mounted) return;
    setState(() {
      workshops = results
          .map((json) => Workshop.fromGooglePlace(json))
          .where((w) => !w.isGasStation)
          .map((w) {
        if (w.location != null && currentPosition != null) {
          final dist = Geolocator.distanceBetween(
            currentPosition!.latitude,
            currentPosition!.longitude,
            w.location!.latitude,
            w.location!.longitude,
          );
          final km = dist / 1000;
          return Workshop(
            id: w.id,
            name: w.name,
            address: w.address,
            rating: w.rating,
            reviewCount: w.reviewCount,
            location: w.location,
            isGooglePlace: true,
            openingHours: w.openingHours,
            distance: '${km.toStringAsFixed(1)} km',
            distanceValue: km,
            types: w.types,
            isOpenNow: w.isOpenNow,
          );
        }
        return w;
      }).toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    final bool isDark = theme.brightness == Brightness.dark;

    final Color mutedForeground =
        colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        spacing.xl,
        spacing.lg,
        spacing.xl,
        spacing.xxxxl + spacing.xxl,
      ),
      children: [
        Text(
          'Choose the best\nservice for you',
          style: typography.headlineLarge.copyWith(color: colors.foreground),
        ),
        SizedBox(height: spacing.lg),

        AppTextField(
          controller: _searchController,
          hintText: 'Search services, workshops...',
          prefixIcon: Icons.search,
          onChanged: (val) {
            setState(() {
              searchQuery = val;
            });
          },
        ),
        SizedBox(height: spacing.lg),

        Row(
          children: [
            Icon(Icons.location_on,
                color: colors.emerald500,
                size: typography.title.fontSize),
            SizedBox(width: spacing.sm),
            Text(
              'Within ${maxDistance.toInt()} km',
              style: typography.bodyLarge.copyWith(color: colors.foreground),
            ),
            Expanded(
              child: Slider(
                value: maxDistance,
                min: 1.0,
                max: 50.0,
                divisions: 49,
                label: '${maxDistance.toInt()} km',
                onChanged: (val) {
                  setState(() => maxDistance = val);
                },
                onChangeEnd: (val) {
                  _searchWorkshops();
                },
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.lg),

        Text(
          'Service Categories',
          style: typography.bodyLarge.copyWith(color: colors.foreground),
        ),
        SizedBox(height: spacing.md),
        SizedBox(
          height: _categoryRowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, index) => SizedBox(width: spacing.md),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat['name'] == selectedCategory;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = cat['name'] as String;
                  });
                  _searchWorkshops();
                },
                child: AnimatedContainer(
                  duration: theme.extension<AppMotionExt>()!.normal,
                  curve: theme.extension<AppMotionExt>()!.standard,
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.lg,
                    vertical: spacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.emerald500
                            .withValues(alpha: colors.surfaceMedium)
                        : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? colors.emerald500 : Colors.grey.withOpacity(0.1),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: spacing.xxxxl,
                        height: spacing.xxxxl,
                        decoration: BoxDecoration(
                          color: colors.emerald500
                              .withValues(alpha: colors.surfaceMedium),
                          borderRadius: BorderRadius.circular(radii.medium),
                        ),
                        child: Icon(
                          cat['icon'] as IconData,
                          color: colors.emerald500,
                          size: typography.title.fontSize,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        cat['name'] as String,
                        style: typography.body.copyWith(
                          color: isSelected
                              ? colors.emerald500
                              : mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: spacing.xl),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top Recommended Workshops',
              style:
                  typography.bodyLarge.copyWith(color: colors.foreground),
            ),
            if (isLoading) const AppSpinner(size: 14),
          ],
        ),
        SizedBox(height: spacing.lg),

        if (isLoading && workshops.isEmpty)
          Padding(
            padding: EdgeInsets.all(spacing.xxl),
            child: const Center(child: AppSpinner()),
          )
        else if (workshops.isEmpty)
          const AppEmptyState(
            icon: Icons.search_off_outlined,
            title: 'No workshops found',
            message: 'Try a different category or expand your search radius.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: workshops.length,
            separatorBuilder: (_, index) => SizedBox(height: spacing.md),
            itemBuilder: (context, index) {
              final workshop = workshops[index];
              // Apply search filter at render time (preserved logic).
              if (searchQuery.isNotEmpty &&
                  !workshop.name
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase())) {
                return const SizedBox.shrink();
              }
              return BookingWorkshopCard(workshop: workshop);
            },
          ),
      ],
    );
  }
}

class _MyBookingsTab extends StatelessWidget {
  const _MyBookingsTab();

  void _onBookingTap(BuildContext context, Map<String, dynamic> booking) {
    final String firestoreId = booking['id']?.toString() ?? '';
    final String localId = booking['id']?.toString() ?? booking['workshopId']?.toString() ?? '';

    if (localId.isEmpty) return;

    final WorkshopFirebaseService firebaseService = WorkshopFirebaseService();

    AppBottomSheet.show<void>(
      context,
      initialHeightFraction: 0.65,
      builder: (BuildContext sheetCtx) => EditBookingBottomSheet(
        booking: booking,
        onSave: (Map<String, dynamic> updates) async {
          Navigator.of(sheetCtx).pop(); // Close sheet
          try {
            // SharedPreferences local updates
            final Map<String, dynamic> localUpdates = <String, dynamic>{
              'serviceName': updates['serviceName'],
              'status': updates['status'],
              'date': updates['localDate'],
              'time': updates['localTime'],
            };
            await VehicleInsights.instance.updateBooking(localId, localUpdates);

            // Firestore updates (if firestore ID is present)
            if (firestoreId.isNotEmpty) {
              final Map<String, dynamic> firestoreUpdates = <String, dynamic>{
                'serviceName': updates['serviceName'],
                'status': updates['status'],
                'date': updates['date'],
                'time': updates['time'],
              };
              await firebaseService.updateBooking(firestoreId, firestoreUpdates);
            }

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking updated successfully')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update booking: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return ListenableBuilder(
      listenable: VehicleInsights.instance,
      builder: (context, child) {
        final bookings = VehicleInsights.instance.bookings;

        if (bookings.isEmpty) {
          return const AppEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No appointments booked',
            message:
                'Browse workshops in the first tab to book services.',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(spacing.lg),
          itemCount: bookings.length,
          separatorBuilder: (_, _) => SizedBox(height: spacing.md),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return BookingConfirmedCard(
              booking: booking,
              onTap: () => _onBookingTap(context, booking),
            );
          },
        );
      },
    );
  }
}
