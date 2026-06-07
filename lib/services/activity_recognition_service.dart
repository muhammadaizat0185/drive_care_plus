import 'dart:async';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'journey_database.dart';
import 'location_tracker.dart';

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
    print('Activity Detected: ${event.type} with confidence ${event.confidence}');

    // Trigger only if IN_VEHICLE and confidence is HIGH (> 75%)
    if (event.type == ActivityType.IN_VEHICLE && event.confidence == ActivityConfidence.HIGH) {
      if (!_isTracking) {
        // Check if there's already an active trip (Planned or Passive)
        final journeys = await JourneyDatabase.instance.getJourneys();
        bool hasActive = journeys.any((j) => j['end_time'] == null);

        if (!hasActive) {
          print('Starting passive background journey (PENDING_CONFIRMATION)...');
          _isTracking = true;
          _pendingJourneyId = await JourneyDatabase.instance.startJourney(status: 'PENDING_CONFIRMATION');
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
        _pendingJourneyId = null;
      }
    }
  }
}
