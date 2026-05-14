import 'dart:async';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'journey_database.dart';
import 'location_tracker.dart';
import 'google_maps_service.dart';

class ActivityRecognitionService {
  static final ActivityRecognitionService instance = ActivityRecognitionService._init();
  StreamSubscription<Activity>? _activitySubscription;
  bool _isTracking = false;
  int? _pendingJourneyId;

  ActivityRecognitionService._init();

  Future<void> startListening() async {
    final activityRecognition = FlutterActivityRecognition.instance;
    var permission = await activityRecognition.checkPermission();

    if (permission == ActivityPermission.DENIED) {
      permission = await activityRecognition.requestPermission();
    }

    if (permission == ActivityPermission.GRANTED) {
      _activitySubscription = activityRecognition.activityStream.listen(_onActivityEvent);
    } else {
      print("Activity Recognition Permission Denied");
    }
  }

  void stopListening() {
    _activitySubscription?.cancel();
  }

  Future<void> _onActivityEvent(Activity event) async {
    print('Activity Detected: \${event.type} with confidence \${event.confidence}');

    if (event.type == ActivityType.IN_VEHICLE && 
        (event.confidence == ActivityConfidence.HIGH || event.confidence == ActivityConfidence.MEDIUM)) {
      if (!_isTracking) {
        // Check if there's already an active trip (Planned or Passive)
        final journeys = await JourneyDatabase.instance.getJourneys();
        bool hasActive = journeys.any((j) => j['end_time'] == null);

        if (!hasActive) {
          print('Starting passive background journey...');
          _isTracking = true;
          _pendingJourneyId = await JourneyDatabase.instance.startJourney(status: 'pending');
          await LocationTracker.startTracking();
        } else {
          print('Active journey exists, yielding passive tracking.');
        }
      }
    } else if ((event.type == ActivityType.STILL || event.type == ActivityType.WALKING) && 
               (event.confidence == ActivityConfidence.HIGH || event.confidence == ActivityConfidence.MEDIUM)) {
      if (_isTracking && _pendingJourneyId != null) {
        print('Ending passive background journey...');
        _isTracking = false;
        await LocationTracker.stopTracking();
        
        // Finalize the pending journey
        // Total distance and Snap to roads will be handled inside stopTracking or we can do it here.
        // It's cleaner to handle DB updates inside location_tracker.dart when it stops, 
        // because location_tracker has the stream and total distance.
      }
    }
  }
}
