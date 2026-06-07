import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'google_maps_service.dart';
import 'journey_database.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStream;
  int? _journeyId;
  DateTime? _lastRecordedTime;
  Timer? _gpsSignalCheckTimer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Attempt to find the currently active journey to attach points to
    final journeys = await JourneyDatabase.instance.getJourneys();
    if (journeys.isNotEmpty) {
      final latest = journeys.first;
      if (latest['end_time'] == null) {
        _journeyId = latest['id'];
      }
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, // Set to High accuracy
        distanceFilter: 0, // Set to 0 for testing and responsiveness
      ),
    ).listen((Position position) async {
      final now = DateTime.now();

      // Enforce minimum interval of 10 seconds during an active journey
      if (_lastRecordedTime == null || now.difference(_lastRecordedTime!).inSeconds >= 10) {
        _lastRecordedTime = now;

        FlutterForegroundTask.updateService(
          notificationTitle: 'DriveCare+',
          notificationText: 'Recording trip... (Lat: ${position.latitude.toStringAsFixed(4)})',
        );

        if (_journeyId != null) {
          await JourneyDatabase.instance.insertPoint(_journeyId!, position.latitude, position.longitude);
          FlutterForegroundTask.sendDataToMain({'lat': position.latitude, 'lng': position.longitude}); // Send point to UI
        }
      }
    });

    // Detect GPS Signal loss and timestamp gaps
    _gpsSignalCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final now = DateTime.now();
      final referenceTime = _lastRecordedTime ?? timestamp;
      final gap = now.difference(referenceTime).inSeconds;

      if (gap >= 30) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'DriveCare+ (GPS Lost)',
          notificationText: 'Searching for GPS signal... (${gap}s gap)',
        );
      }
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This is fired repeatedly based on the interval.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _gpsSignalCheckTimer?.cancel();
    await _positionStream?.cancel();

    if (_journeyId != null) {
      // Fetch all recorded points for this journey
      final pointsData = await JourneyDatabase.instance.getPoints(_journeyId!);
      if (pointsData.length > 1) {
        // Calculate total raw distance
        double totalDistanceMeters = 0.0;
        for (int i = 0; i < pointsData.length - 1; i++) {
          totalDistanceMeters += Geolocator.distanceBetween(
            pointsData[i]['latitude'],
            pointsData[i]['longitude'],
            pointsData[i + 1]['latitude'],
            pointsData[i + 1]['longitude'],
          );
        }

        // Snap to roads in the background (if we want the route clean for Journey Log)
        // Note: We might just do this on-demand in the UI if we want to save API calls, 
        // but since we want the actual route distance, it's fine.
        final rawLatLng = pointsData.map((p) => LatLng(p['latitude'], p['longitude'])).toList();
        await GoogleMapsService.snapToRoads(rawLatLng);
        
        // Reverse Geocode the final coordinate to update the destination address
        String? finalDestAddress;
        try {
          final lastPoint = pointsData.last;
          List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
              lastPoint['latitude'], lastPoint['longitude']);
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            finalDestAddress = "${place.name}, ${place.locality}";
          }
        } catch (e) {
          debugPrint("Geocoding failed: $e");
        }

        // Finalize the journey in the database (this will only overwrite if it was a passive journey,
        // or it will just update the missing fields for a planned journey if it ended early)
        final journeys = await JourneyDatabase.instance.getJourneys();
        final journey = journeys.firstWhere((j) => j['id'] == _journeyId, orElse: () => {});
        if (journey.isNotEmpty && journey['end_time'] == null) {
            await JourneyDatabase.instance.endJourney(_journeyId!, totalDistanceMeters / 1000.0, journey['start_address'], finalDestAddress);
        } else if (journey.isNotEmpty) {
           // If already ended (e.g. by trip planner), just update the destination if it was null
           if (journey['destination_address'] == null || journey['destination_address'] == 'No destination set') {
             await JourneyDatabase.instance.updateJourneyDestination(_journeyId!, finalDestAddress);
           }
        }
      } else if (pointsData.isNotEmpty) {
        // Only 1 point, finalize with 0 distance
        final journeys = await JourneyDatabase.instance.getJourneys();
        final journey = journeys.firstWhere((j) => j['id'] == _journeyId, orElse: () => {});
        if (journey.isNotEmpty && journey['end_time'] == null) {
            await JourneyDatabase.instance.endJourney(_journeyId!, 0.0, journey['start_address'], null);
        }
      }
    }
  }
}

class LocationTracker {
  // Configures the foreground service parameters
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_tracker',
        channelName: 'Journey Recording',
        channelDescription: 'Records your journey in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  // Starts the service. If the user disabled the background notification preference,
  // we could bypass this and just run a standard stream, but Android will kill it quickly.
  static Future<void> startTracking() async {
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'DriveCare+',
        notificationText: 'Starting journey recording...',
        callback: startCallback,
      );
    }
  }

  static Future<void> stopTracking() async {
    await FlutterForegroundTask.stopService();
  }
}
