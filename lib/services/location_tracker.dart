import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
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
