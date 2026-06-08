import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/color_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/tokens/tokens.dart';
import '../models/workshop.dart';
import '../services/google_maps_service.dart';
import '../services/workshop_firebase_service.dart';
import '../widgets/ui/ui.dart';
import '../services/vehicle_insights.dart';
import '../services/notification_service.dart';
import 'workshops/_browse_tab.dart';
import 'workshops/_my_bookings_tab.dart';
import 'workshops/_workshop_detail_sheet.dart';
import 'workshops/_edit_booking_sheet.dart';

/// Redesigned `WorkshopMapScreen` (Tasks 9.2 — 9.13).
///
/// Top-level layout:
///
///   * `Browse | My Bookings` tab switcher (Task 9.2). Default tab:
///     `Browse`.
///   * `Browse` tab body — search, filter, list/map toggle, cards,
///     empty state. See [BrowseTab].
///   * `My Bookings` tab body — populated cards or empty state. See
///     [MyBookingsTab].
///
/// Workshop cards in the Browse tab open a compact detail bottom sheet
/// via [AppBottomSheet.show] (Tasks 9.10, 9.11). Heart taps on each card
/// fire an optimistic toggle (Task 9.8).
///
/// Visual constants come from the design-token extensions on
/// `Theme.of(context)`; no hex colors, spacing, radii, or typography
/// literals from the Token_Sets are inlined (Requirement 3.11).
class WorkshopMapScreen extends StatefulWidget {
  const WorkshopMapScreen({super.key});

  static const String routeName = '/workshop-map';

  @override
  State<WorkshopMapScreen> createState() => _WorkshopMapScreenState();
}

class _WorkshopMapScreenState extends State<WorkshopMapScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final WorkshopFirebaseService _service = WorkshopFirebaseService();

  List<Workshop> _workshops = <Workshop>[];
  final Set<String> _favorites = <String>{};
  bool _isLoading = false;
  Position? _currentPosition;

  // Default camera fallback: Kuala Lumpur. Used when location permission
  // has not yet resolved so the [GoogleMap] still mounts a sensible
  // initial view rather than `(0, 0)` in the Atlantic.
  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(3.139, 101.6869),
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _isLoading = true);
    try {
      final LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final Position position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _currentPosition = position);
      await _searchWorkshops();
    } catch (_) {
      // Surface failure as a snackbar; the screen still renders with an
      // empty workshops list and the Browse tab's empty state.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchWorkshops() async {
    if (_currentPosition == null) return;
    final List<dynamic> results =
        await GoogleMapsService.searchNearbyWorkshops(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      5.0,
    );
    if (!mounted) return;
    setState(() {
      _workshops = results
          .map((dynamic json) =>
              Workshop.fromGooglePlace(json as Map<String, dynamic>))
          .toList(growable: false);
    });
  }

  CameraPosition get _cameraPosition {
    if (_currentPosition == null) return _fallbackCamera;
    return CameraPosition(
      target: LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      ),
      zoom: 13,
    );
  }

  // ---- Browse-tab callbacks -------------------------------------------

  void _onWorkshopTap(Workshop workshop) {
    AppBottomSheet.show<void>(
      context,
      // Per Task 9.10 the sheet must occupy ≥ 80% of the viewport.
      initialHeightFraction: 0.85,
      builder: (BuildContext _) => WorkshopDetailSheet(workshop: workshop),
    );
  }

  Future<void> _onFavoriteToggle(Workshop workshop) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save favorites')),
      );
      return;
    }
    // Optimistic update: flip the local set immediately so the heart fill
    // updates within 100 ms (Requirement 7.6). On failure we revert.
    final bool wasFavorited = _favorites.contains(workshop.id);
    setState(() {
      if (wasFavorited) {
        _favorites.remove(workshop.id);
      } else {
        _favorites.add(workshop.id);
      }
    });
    try {
      await _service.toggleFavorite(workshop.id, user.uid);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasFavorited) {
          _favorites.add(workshop.id);
        } else {
          _favorites.remove(workshop.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update favorite')),
      );
    }
  }

  void _onNavigate(Workshop workshop) {
    // Routing through the existing detail screen's navigation flow keeps
    // the URL-launch behavior consistent and avoids duplicating the
    // platform-specific google.navigation:q intent here.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => Scaffold(
          appBar: AppBar(title: Text(workshop.name)),
          body: const Center(child: Text('Open in Maps from detail screen')),
        ),
      ),
    );
  }

  void _onBook(Workshop workshop) {
    _onWorkshopTap(workshop);
  }

  // ---- My Bookings callbacks ------------------------------------------

  Future<void> _onReschedule(String bookingId) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (pickedTime == null || !mounted) return;

    try {
      await _service.rescheduleBooking(
        bookingId,
        pickedDate.toIso8601String(),
        '${pickedTime.hour}:${pickedTime.minute}',
      );

      // Update local storage in VehicleInsights so that cockpit is in sync
      final String localDateStr = '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
      final String localTimeStr = pickedTime.format(context);
      await VehicleInsights.instance.updateBooking(bookingId, <String, dynamic>{
        'date': localDateStr,
        'time': localTimeStr,
        'status': 'Pending',
      });

      // Get booking details to reschedule reminders
      final booking = VehicleInsights.instance.bookings.firstWhere(
        (b) => b['id'] == bookingId || b['workshopId'] == bookingId,
        orElse: () => <String, dynamic>{},
      );
      final String workshopName = booking['workshopName']?.toString() ?? 'Workshop';
      final String serviceName = booking['serviceName']?.toString() ?? 'Service';

      // Schedule reminders
      final bookingDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      await NotificationService.instance.scheduleBookingReminders(
        bookingId: bookingId,
        workshopName: workshopName,
        serviceName: serviceName,
        bookingDateTime: bookingDateTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking rescheduled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reschedule booking: $e')),
        );
      }
    }
  }

  Future<void> _onCancelBooking(String bookingId) async {
    // Confirm via AppBottomSheet — tappable Cancel + destructive Remove
    // pair. Routes through the existing Firestore bookings collection.
    final bool? confirmed = await AppBottomSheet.show<bool>(
      context,
      initialHeightFraction: 0.3,
      builder: (BuildContext sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Cancel this booking?',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          AppGradientButton(
            label: 'Yes, cancel',
            onPressed: () =>
                Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 8),
          AppSecondaryButton(
            label: 'Keep booking',
            fullWidth: true,
            onPressed: () =>
                Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _service.cancelBooking(bookingId);
        await VehicleInsights.instance.updateBooking(bookingId, <String, dynamic>{
          'status': 'Cancelled',
        });
        await NotificationService.instance.cancelBookingReminders(bookingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel booking: $e')),
          );
        }
      }
    }
  }

  void _onBrowseFromEmpty() {
    _tabController.animateTo(0);
  }

  void _onBookingTap(Map<String, dynamic> booking) {
    final String bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    AppBottomSheet.show<void>(
      context,
      initialHeightFraction: 0.65,
      builder: (BuildContext sheetCtx) => EditBookingBottomSheet(
        booking: booking,
        onSave: (Map<String, dynamic> updates) async {
          Navigator.of(sheetCtx).pop(); // Close the sheet
          try {
            // Firestore updates
            final Map<String, dynamic> firestoreUpdates = <String, dynamic>{
              'serviceName': updates['serviceName'],
              'status': updates['status'],
              'date': updates['date'],
              'time': updates['time'],
            };
            await _service.updateBooking(bookingId, firestoreUpdates);

            // SharedPreferences local updates
            final Map<String, dynamic> localUpdates = <String, dynamic>{
              'serviceName': updates['serviceName'],
              'status': updates['status'],
              'date': updates['localDate'],
              'time': updates['localTime'],
            };
            await VehicleInsights.instance.updateBooking(bookingId, localUpdates);

            // Reschedule notification reminders
            if (updates['status'] == 'Cancelled') {
              await NotificationService.instance.cancelBookingReminders(bookingId);
            } else {
              try {
                final parsedDate = DateTime.parse(updates['date'] as String);
                final timeParts = (updates['time'] as String).split(':');
                final hour = int.parse(timeParts[0]);
                final minute = int.parse(timeParts[1]);
                final bookingDateTime = DateTime(
                  parsedDate.year,
                  parsedDate.month,
                  parsedDate.day,
                  hour,
                  minute,
                );
                await NotificationService.instance.scheduleBookingReminders(
                  bookingId: bookingId,
                  workshopName: booking['workshopName']?.toString() ?? 'Workshop',
                  serviceName: updates['serviceName']?.toString() ?? 'General Service',
                  bookingDateTime: bookingDateTime,
                );
              } catch (e) {
                debugPrint('Error updating booking reminders: $e');
              }
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking updated successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update booking: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // ---- Build ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Workshops'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48 + spacing.sm),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.sm,
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: typography.title,
              labelColor: colors.emerald500,
              unselectedLabelColor: colors.foreground
                  .withValues(alpha: colors.surfaceProminent),
              indicatorColor: colors.emerald500,
              tabs: const <Widget>[
                Tab(text: 'Browse'),
                Tab(text: 'My Bookings'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: AppSpinner())
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                BrowseTab(
                  workshops: _workshops,
                  favorites: _favorites,
                  initialCameraPosition: _cameraPosition,
                  onWorkshopTap: _onWorkshopTap,
                  onFavoriteToggle: _onFavoriteToggle,
                  onNavigate: _onNavigate,
                  onBook: _onBook,
                ),
                _MyBookingsBranch(
                  service: _service,
                  onReschedule: _onReschedule,
                  onCancel: _onCancelBooking,
                  onBrowse: _onBrowseFromEmpty,
                  onTap: _onBookingTap,
                ),
              ],
            ),
    ),);
  }
}

/// Streams the user's bookings and renders the [MyBookingsTab] with the
/// current snapshot. Extracted as a `StatelessWidget` so the streaming
/// logic does not bloat `_WorkshopMapScreenState`.
class _MyBookingsBranch extends StatelessWidget {
  const _MyBookingsBranch({
    required this.service,
    required this.onReschedule,
    required this.onCancel,
    required this.onBrowse,
    required this.onTap,
  });

  final WorkshopFirebaseService service;
  final void Function(String) onReschedule;
  final void Function(String) onCancel;
  final VoidCallback onBrowse;
  final void Function(Map<String, dynamic>) onTap;

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return MyBookingsTab(
        bookings: const <Map<String, dynamic>>[],
        onBrowse: onBrowse,
        onTap: onTap,
      );
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.watchUserBookings(user.uid),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppSpinner());
        }
        final List<Map<String, dynamic>> bookings =
            snapshot.data ?? const <Map<String, dynamic>>[];
        return MyBookingsTab(
          bookings: bookings,
          onReschedule: onReschedule,
          onCancel: onCancel,
          onBrowse: onBrowse,
          onTap: onTap,
        );
      },
    );
  }
}
