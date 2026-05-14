import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class GoogleMapsService {
  static const String _apiKey = 'AIzaSyCbAOi4YqBze7HcVNXHuqVUDp9B9HHNRWE';

  // Autocomplete (Places API New)
  static Future<List<dynamic>> getPlacePredictions(String query) async {
    if (query.isEmpty) return [];
    
    final url = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
    final response = await http.post(
      url,
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'input': query}),
    );
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['suggestions'] != null) {
        return (json['suggestions'] as List).map((s) {
          final prediction = s['placePrediction'];
          return {
            'place_id': prediction['placeId'],
            'description': prediction['text']['text'],
          };
        }).toList();
      }
    } else {
      print('Places API (New) Error: ${response.statusCode} - ${response.body}');
    }
    return [];
  }

  // Get Place Details (Lat/Lng) (Places API New)
  static Future<LatLng?> getPlaceCoordinates(String placeId) async {
    final url = Uri.parse('https://places.googleapis.com/v1/places/$placeId');
    final response = await http.get(
      url,
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'location',
      },
    );
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['location'] != null) {
        return LatLng(json['location']['latitude'], json['location']['longitude']);
      }
    } else {
      print('Places Details API (New) Error: ${response.statusCode} - ${response.body}');
    }
    return null;
  }

  // Get Directions Polyline (Routes API)
  static Future<Map<String, dynamic>?> getDirections(LatLng origin, LatLng destination) async {
    final url = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
    final response = await http.post(
      url,
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "origin": {
          "location": {
            "latLng": {
              "latitude": origin.latitude,
              "longitude": origin.longitude
            }
          }
        },
        "destination": {
          "location": {
            "latLng": {
              "latitude": destination.latitude,
              "longitude": destination.longitude
            }
          }
        },
        "travelMode": "DRIVE"
      }),
    );
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['routes'] != null && (json['routes'] as List).isNotEmpty) {
        final route = json['routes'][0];
        final encodedPolyline = route['polyline']['encodedPolyline'];
        
        // Return in legacy format so trip_planner_screen.dart parsing doesn't break
        return {
          'overview_polyline': {
            'points': encodedPolyline,
          },
          'distance_meters': route['distanceMeters'],
          'duration': route['duration'], // e.g., "100s"
        };
      }
    } else {
      print('Routes API Error: ${response.statusCode} - ${response.body}');
    }
    return null;
  }

  // Snap to Roads
  static Future<List<LatLng>> snapToRoads(List<LatLng> path) async {
    if (path.isEmpty) return [];
    
    // The Roads API accepts up to 100 points per request.
    List<LatLng> pointsToSnap = path;
    if (pointsToSnap.length > 100) {
      // Very basic decimation to fit 100 points
      int step = (pointsToSnap.length / 100).ceil();
      pointsToSnap = [for (var i = 0; i < path.length; i += step) path[i]];
    }

    final pathString = pointsToSnap.map((p) => '${p.latitude},${p.longitude}').join('|');
    final url = Uri.https('roads.googleapis.com', '/v1/snapToRoads', {
      'path': pathString,
      'interpolate': 'true',
      'key': _apiKey,
    });
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['snappedPoints'] != null) {
        return (json['snappedPoints'] as List).map((p) {
          final loc = p['location'];
          return LatLng(loc['latitude'], loc['longitude']);
        }).toList();
      }
    }
    return pointsToSnap; // fallback to original
  }

  // Workshop Discovery (Places API New) - Tier 1: Summary List
  static Future<List<dynamic>> searchNearbyWorkshops(LatLng location, double radiusKm, {List<String>? includedTypes}) async {
    final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
    final response = await http.post(
      url,
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'places.id,places.name,places.displayName,places.formattedAddress,places.rating,places.userRatingCount,places.location,places.regularOpeningHours,places.types',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "includedTypes": includedTypes ?? ["car_repair", "car_wash", "gas_station"],
        "maxResultCount": 20,
        "locationRestriction": {
          "circle": {
            "center": {
              "latitude": location.latitude,
              "longitude": location.longitude
            },
            "radius": radiusKm * 1000 // meters
          }
        }
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['places'] ?? [];
    } else {
      print('Search Nearby Error: ${response.statusCode} - ${response.body}');
      return [];
    }
  }

  // Workshop Details (Places API New) - Tier 2: Deep Detail
  static Future<Map<String, dynamic>?> getWorkshopDetails(String placeId) async {
    final url = Uri.parse('https://places.googleapis.com/v1/places/$placeId');
    final response = await http.get(
      url,
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'reviews,photos,regularOpeningHours,editorialSummary',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Get Workshop Details Error: ${response.statusCode} - ${response.body}');
      return null;
    }
  }
}
