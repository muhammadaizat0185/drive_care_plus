// Phase 3 — ActivityRecognitionService (updated).
//
// Changes from original:
//   • After a passive journey ends (STILL/WALKING detected), runs
//     [TripHeuristicsService.analyse()] on the recorded GPS points.
//   • If the heuristic returns a high-confidence suggestion, pre-fills
//     the journey's [transport_mode] field and [attribution_source] = 'heuristic'.
//     The confirmation sheet still shows it as PENDING — user must confirm.
//   • Calls [NotificationService.checkAndSendTripReviewIfNeeded()] after
//     journey end so an immediate notification fires if ≥1 trip is pending.
//
// PRESERVED:
//   • Permission check and ActivityType.IN_VEHICLE trigger logic unchanged.
//   • LocationTracker.startTracking() / stopTracking() calls unchanged.
//   • JourneyDatabase.instance.startJourney(status:'PENDING_CONFIRMATION') unchanged.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'bluetooth_vehicle_service.dart';
import 'journey_database.dart';
import 'location_tracker.dart';
import 'notification_service.dart';
import 'trip_heuristics_service.dart';
import 'vehicle_insights.dart';

class ActivityRecognitionService {
  static final ActivityRecognitionService instance =
      ActivityRecognitionService._init();

  StreamSubscription<Activity>? _activitySubscription;
  bool _isTracking = false;
  int? _pendingJourneyId;

  /// Set when BT auto-confirm fires at journey start; cleared at journey end.
  /// Non-null means the journey should be auto-confirmed to this vehicle.
  String? _btConfirmedVehicleId;

  ActivityRecognitionService._init();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> startListening() async {
    final activityRecognition = FlutterActivityRecognition.instance;
    var permission = await activityRecognition.checkPermission();

    if (permission == ActivityPermission.DENIED) {
      permission = await activityRecognition.requestPermission();
    }

    if (permission == ActivityPermission.GRANTED) {
      _activitySubscription =
          activityRecognition.activityStream.listen(_onActivityEvent);
      debugPrint('ActivityRecognitionService: listening');
    } else {
      debugPrint('ActivityRecognitionService: permission denied');
    }
  }

  void stopListening() {
    _activitySubscription?.cancel();
    _activitySubscription = null;
  }

  // ---------------------------------------------------------------------------
  // Event handler
  // ---------------------------------------------------------------------------

  Future<void> _onActivityEvent(Activity event) async {
    debugPrint(
        'ActivityRecognitionService: ${event.type} confidence=${event.confidence}');

    // ── Journey START ─────────────────────────────────────────────────────────
    if (event.type == ActivityType.IN_VEHICLE &&
        event.confidence == ActivityConfidence.HIGH) {
      if (!_isTracking) {
        // Yield if there is already an active trip (planned or passive).
        final journeys = await JourneyDatabase.instance.getJourneys();
        final bool hasActive = journeys.any((j) => j['end_time'] == null);

        if (!hasActive) {
          // ── Phase 4: BT pre-check ─────────────────────────────────────────
          final insights = VehicleInsights.instance;
          final String activeVehicleId = insights.vehicles.isNotEmpty
              ? (insights.vehicles[insights.activeVehicleIndex]['id']
                      as String? ??
                  '')
              : '';

          bool btConfirmed = false;
          if (activeVehicleId.isNotEmpty) {
            btConfirmed = await BluetoothVehicleService.instance
                .isCarBluetoothConnected(activeVehicleId);
          }

          if (btConfirmed) {
            // BT device matched — start as confirmed for this vehicle.
            debugPrint(
                'ActivityRecognitionService: BT match → auto-confirming journey');
            _isTracking = true;
            _pendingJourneyId =
                await JourneyDatabase.instance.startJourney(
              status: 'PENDING_CONFIRMATION',
            );
            await LocationTracker.startTracking();
            // Mark attribution immediately after tracking starts.
            _btConfirmedVehicleId = activeVehicleId;
          } else {
            // No BT match — fall back to PENDING_CONFIRMATION.
            debugPrint(
                'ActivityRecognitionService: no BT match → PENDING_CONFIRMATION');
            _isTracking = true;
            _pendingJourneyId = await JourneyDatabase.instance
                .startJourney(status: 'PENDING_CONFIRMATION');
            _btConfirmedVehicleId = null;
            await LocationTracker.startTracking();
          }
        } else {
          debugPrint(
              'ActivityRecognitionService: active journey exists — yielding.');
        }
      }
      return;
    }

    // ── Journey END ───────────────────────────────────────────────────────────
    if ((event.type == ActivityType.STILL ||
            event.type == ActivityType.WALKING) &&
        (event.confidence == ActivityConfidence.HIGH ||
            event.confidence == ActivityConfidence.MEDIUM)) {
      if (_isTracking && _pendingJourneyId != null) {
        debugPrint(
            'ActivityRecognitionService: ending passive journey id=$_pendingJourneyId');

        _isTracking = false;
        await LocationTracker.stopTracking();

        // ── Phase 3: heuristic transport-mode pre-fill ────────────────────────
        final int journeyId = _pendingJourneyId!;
        _pendingJourneyId = null;

        // Run heuristic in background — don't await UI-blocking work.
        _runHeuristicAndNotify(journeyId);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Runs the GPS-point heuristic for [journeyId], pre-fills the
  /// transport_mode hint if confidence is high, then triggers the
  /// trip-review notification check.
  Future<void> _runHeuristicAndNotify(int journeyId) async {
    try {
      // Give LocationTaskHandler.onDestroy() a moment to write final points.
      await Future.delayed(const Duration(seconds: 3));

      // ── Phase 4: If BT confirmed, skip heuristic and auto-confirm ───────────
      final String? btVehicleId = _btConfirmedVehicleId;
      _btConfirmedVehicleId = null;

      if (btVehicleId != null && btVehicleId.isNotEmpty) {
        debugPrint(
            'ActivityRecognitionService: BT auto-confirm for journey $journeyId '
            'vehicle=$btVehicleId');
        await JourneyDatabase.instance.updateJourneyAttribution(
          journeyId,
          vehicleId: btVehicleId,
          vehicleType: 'my_car',
          transportMode: 'driving',
          source: 'bluetooth_auto',
        );
        // Odometer update is handled by LocationTracker.onDestroy() which
        // reads the status after endJourney() writes it.
        // Still run the review check so any other pending trips are surfaced.
        await NotificationService.instance.checkAndSendTripReviewIfNeeded();
        return;
      }

      // ── Phase 3: Heuristic fallback ─────────────────────────────────────────
      final List<Map<String, dynamic>> points =
          await JourneyDatabase.instance.getPoints(journeyId);

      final TransportModeSuggestion suggestion =
          TripHeuristicsService.analyse(points);

      debugPrint(
          'ActivityRecognitionService: heuristic for journey $journeyId → '
          '${suggestion.mode} (confidence=${suggestion.confidence.toStringAsFixed(2)})');

      if (suggestion.isHighConfidence) {
        final db = JourneyDatabase.instance;

        if (suggestion.mode == TransportMode.publicTransportBus) {
          await db.updateJourneyAttribution(
            journeyId,
            vehicleType: 'public_transport',
            transportMode: 'bus',
            source: 'heuristic',
          );
          await _reopenAsPending(journeyId);
        }
      }
    } catch (e) {
      debugPrint('ActivityRecognitionService._runHeuristicAndNotify: $e');
    }

    // Always trigger the review notification check after a journey ends.
    try {
      await NotificationService.instance.checkAndSendTripReviewIfNeeded();
    } catch (e) {
      debugPrint('ActivityRecognitionService: notification check failed: $e');
    }
  }

  /// Reopens a journey that was tentatively set to 'confirmed' by the
  /// heuristic back to 'PENDING_CONFIRMATION' so the user still sees the
  /// confirmation prompt — the heuristic is a *hint*, not an auto-confirm.
  Future<void> _reopenAsPending(int journeyId) async {
    try {
      final db = await JourneyDatabase.instance.database;
      await db.update(
        'journeys',
        {'status': 'PENDING_CONFIRMATION'},
        where: 'id = ?',
        whereArgs: [journeyId],
      );
    } catch (e) {
      debugPrint('ActivityRecognitionService._reopenAsPending: $e');
    }
  }
}
