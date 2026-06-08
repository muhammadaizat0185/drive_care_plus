// Phase 3 — Trip Heuristics Service.
//
// Stateless analyser that takes a list of GPS points for a completed journey
// and returns a [TransportModeSuggestion] indicating the most likely
// transport mode (car vs public bus vs unknown).
//
// Algorithm (no ML required):
//   1. Compute speeds between consecutive GPS points.
//   2. Count "stops" — segments where speed < 5 km/h for 20–120 seconds.
//   3. Measure stop spacing regularity (standard deviation of inter-stop distances).
//   4. Classify using heuristic thresholds.
//
// Accuracy expectations:
//   • Car vs bus: ~80% — sufficient to pre-fill and reduce user taps.
//   • Always surfaced as a *suggestion*, never auto-confirmed (user can override).

import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

enum TransportMode {
  /// Almost certainly the user's car or a private vehicle.
  driving,

  /// Motion pattern matches a scheduled bus route.
  publicTransportBus,

  /// Not enough data or pattern is ambiguous.
  unknown,
}

class TransportModeSuggestion {
  final TransportMode mode;

  /// Human-readable explanation, shown in the confirmation sheet as a hint.
  final String reason;

  /// 0.0–1.0 confidence. Only suggestions above 0.6 are shown in the UI.
  final double confidence;

  const TransportModeSuggestion({
    required this.mode,
    required this.reason,
    required this.confidence,
  });

  bool get isHighConfidence => confidence >= 0.60;

  String get transportModeString {
    switch (mode) {
      case TransportMode.driving:
        return 'driving';
      case TransportMode.publicTransportBus:
        return 'bus';
      case TransportMode.unknown:
        return 'other';
    }
  }
}

// ---------------------------------------------------------------------------
// Point model (mirrors JourneyDatabase row)
// ---------------------------------------------------------------------------

class _GpsPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;

  _GpsPoint(this.lat, this.lng, this.timestamp);
}

// ---------------------------------------------------------------------------
// TripHeuristicsService
// ---------------------------------------------------------------------------

class TripHeuristicsService {
  TripHeuristicsService._();

  /// Analyse [rawPoints] (from JourneyDatabase.getPoints()) and return a
  /// transport-mode suggestion.
  ///
  /// [rawPoints] format: `[{'latitude': ..., 'longitude': ..., 'timestamp': ...}, ...]`
  static TransportModeSuggestion analyse(List<Map<String, dynamic>> rawPoints) {
    if (rawPoints.length < 4) {
      return const TransportModeSuggestion(
        mode: TransportMode.unknown,
        reason: 'Not enough GPS points to analyse.',
        confidence: 0.0,
      );
    }

    // Parse points
    final List<_GpsPoint> points = rawPoints.map((p) {
      return _GpsPoint(
        (p['latitude'] as num).toDouble(),
        (p['longitude'] as num).toDouble(),
        DateTime.parse(p['timestamp'] as String),
      );
    }).toList();

    // ── Compute segment speeds (km/h) ────────────────────────────────────────
    final List<double> speeds = [];
    for (int i = 0; i < points.length - 1; i++) {
      final double distM = Geolocator.distanceBetween(
        points[i].lat, points[i].lng,
        points[i + 1].lat, points[i + 1].lng,
      );
      final double secs = points[i + 1].timestamp
          .difference(points[i].timestamp)
          .inSeconds
          .toDouble();
      if (secs <= 0) continue;
      speeds.add((distM / secs) * 3.6); // m/s → km/h
    }

    if (speeds.isEmpty) {
      return const TransportModeSuggestion(
        mode: TransportMode.unknown,
        reason: 'Could not compute speeds.',
        confidence: 0.0,
      );
    }

    final double medianSpeed = _median(speeds);
    final double maxSpeed = speeds.reduce(math.max);

    // ── Detect "stops": consecutive low-speed segments ───────────────────────
    // A stop = at least 2 consecutive points with speed < 5 km/h and the
    // stop duration between 20–180 seconds.
    final List<double> stopDistancesFromPrev = [];
    double? lastStopEndDistM;
    double cumulativeDistM = 0.0;
    int stopCount = 0;

    for (int i = 0; i < speeds.length - 1; i++) {
      final double distM = Geolocator.distanceBetween(
        points[i].lat, points[i].lng,
        points[i + 1].lat, points[i + 1].lng,
      );
      cumulativeDistM += distM;

      if (speeds[i] < 5.0 && speeds[i + 1] < 5.0) {
        final int stopDurS = points[i + 2 <= points.length - 1 ? i + 2 : i + 1]
            .timestamp
            .difference(points[i].timestamp)
            .inSeconds;

        if (stopDurS >= 20 && stopDurS <= 180) {
          stopCount++;
          if (lastStopEndDistM != null) {
            stopDistancesFromPrev
                .add(cumulativeDistM - lastStopEndDistM);
          }
          lastStopEndDistM = cumulativeDistM;
        }
      }
    }

    // ── Stop-spacing regularity ───────────────────────────────────────────────
    // Bus stops are spaced 300–900m apart with low variance.
    double stopSpacingStdDev = double.infinity;
    double meanStopSpacing = 0;
    if (stopDistancesFromPrev.length >= 2) {
      meanStopSpacing =
          stopDistancesFromPrev.reduce((a, b) => a + b) /
              stopDistancesFromPrev.length;
      final double variance = stopDistancesFromPrev
          .map((d) => math.pow(d - meanStopSpacing, 2).toDouble())
          .reduce((a, b) => a + b) /
          stopDistancesFromPrev.length;
      stopSpacingStdDev = math.sqrt(variance);
    }

    // ── Scoring ───────────────────────────────────────────────────────────────
    // Evidence for "this is a bus":
    //   S1: ≥3 stops detected
    //   S2: stop spacing 300–900m
    //   S3: stop spacing std-dev < 300m (regular)
    //   S4: median speed 10–50 km/h (bus speed range)
    //   S5: max speed < 90 km/h (buses don't go highway speeds)
    //
    // Score is a simple sum; ≥3 → bus suggestion.

    int busScore = 0;
    if (stopCount >= 3) busScore++;
    if (meanStopSpacing >= 300 && meanStopSpacing <= 900) busScore++;
    if (stopSpacingStdDev < 300) busScore++;
    if (medianSpeed >= 10 && medianSpeed <= 50) busScore++;
    if (maxSpeed < 90) busScore++;

    if (busScore >= 3) {
      final double confidence = (busScore / 5.0).clamp(0.6, 0.95);
      return TransportModeSuggestion(
        mode: TransportMode.publicTransportBus,
        reason: 'Detected $stopCount regular stops — looks like a bus route.',
        confidence: confidence,
      );
    }

    // Evidence for "this is driving":
    //   D1: max speed > 60 km/h
    //   D2: median speed > 30 km/h
    //   D3: fewer than 2 regular stops
    int drivingScore = 0;
    if (maxSpeed > 60) drivingScore++;
    if (medianSpeed > 30) drivingScore++;
    if (stopCount < 2) drivingScore++;

    if (drivingScore >= 2) {
      final double confidence = (drivingScore / 3.0).clamp(0.6, 0.90);
      return TransportModeSuggestion(
        mode: TransportMode.driving,
        reason: 'Speed profile matches private vehicle driving.',
        confidence: confidence,
      );
    }

    return const TransportModeSuggestion(
      mode: TransportMode.unknown,
      reason: 'Pattern is ambiguous — please confirm manually.',
      confidence: 0.0,
    );
  }

  // ── Utility ─────────────────────────────────────────────────────────────────

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2.0;
  }
}
