import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Closed set of categories used by the redesigned Workshops Browse tab to
/// filter the list with a single-selection chip row (`All / Repair /
/// Car Wash / Parts`).
///
/// The enum is derived purely from the existing free-form `Workshop.types`
/// list returned by Google Places — no Firestore schema migration is
/// required (Task 9.1 scope: "Map existing workshop docs to the enum
/// without schema migration"). The `category` getter on [Workshop]
/// performs the mapping.
///
/// Members:
///
///   * [all]     — sentinel matching every workshop. Used by the chip row's
///                 default "All" pill; never returned by `Workshop.category`
///                 itself (workshops always classify as one of the three
///                 concrete buckets).
///   * [repair]  — general car-repair shops (`car_repair`, `car_repairer`).
///   * [carWash] — car-wash specialists (`car_wash`).
///   * [parts]   — parts and gas-stop adjacent (`car_dealer`, `gas_station`,
///                 and explicit `parts` annotations from the Places taxonomy).
///
/// See: figma-ui-redesign Requirements 7.2, 14.3, 14.9.
enum WorkshopCategory { all, repair, carWash, parts }

class Workshop {
  const Workshop({
    required this.id,
    required this.name,
    this.distance,
    this.distanceValue = 0.0,
    required this.address,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.description = '',
    this.services = const [],
    this.reviews = const [],
    this.location,
    this.isGooglePlace = false,
    this.openingHours,
    this.photos = const [],
    this.types = const [],
    this.isOpenNow,
  });

  final String id;
  final String name;
  final String? distance;
  final double distanceValue;
  final String address;
  final double rating;
  final int reviewCount;
  final String description;
  final List<WorkshopService> services;
  final List<WorkshopReview> reviews;
  final LatLng? location;
  final bool isGooglePlace;
  final Map<String, dynamic>? openingHours;
  final List<String> photos;
  final List<String> types;
  final bool? isOpenNow;

  bool get isGasStation => types.contains('gas_station');
  bool get isCarWash => types.contains('car_wash');
  bool get isRepairShop => types.contains('car_repair') || types.contains('car_repairer');

  /// Concrete [WorkshopCategory] derived purely from the existing [types]
  /// list (no Firestore migration). The mapping is defined precedence-first
  /// — repair beats car-wash beats parts — so a workshop tagged as both
  /// `car_repair` and `gas_station` (uncommon, but possible from Google
  /// Places) classifies as [WorkshopCategory.repair].
  ///
  /// Workshops with no recognised type fall back to [WorkshopCategory.parts]
  /// because the Browse tab's chip row exposes no "Other" bucket; routing
  /// the long tail to `parts` keeps every workshop reachable when the
  /// "Parts" chip is selected without inventing a new chip the design does
  /// not specify.
  ///
  /// Never returns [WorkshopCategory.all] — that value is reserved for the
  /// chip row's "All" sentinel and represents a *filter*, not a workshop.
  ///
  /// See: figma-ui-redesign Requirement 7.2, Task 9.1.
  WorkshopCategory get category {
    if (isRepairShop) {
      return WorkshopCategory.repair;
    }
    if (isCarWash) {
      return WorkshopCategory.carWash;
    }
    return WorkshopCategory.parts;
  }

  factory Workshop.fromGooglePlace(Map<String, dynamic> json) {
    return Workshop(
      id: json['name'].split('/').last, // "places/PLACE_ID"
      name: json['displayName']['text'],
      address: json['formattedAddress'] ?? 'No address available',
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['userRatingCount'] ?? 0,
      location: json['location'] != null
          ? LatLng(json['location']['latitude'], json['location']['longitude'])
          : null,
      isGooglePlace: true,
      openingHours: json['regularOpeningHours'],
      types: (json['types'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isOpenNow: json['regularOpeningHours'] != null ? json['regularOpeningHours']['openNow'] as bool? : null,
    );
  }
}

class WorkshopService {
  const WorkshopService({
    required this.name,
    required this.price,
    required this.duration,
    this.products,
  });

  final String name;
  final double price;
  final String duration;
  final List<WorkshopProduct>? products;

  String get priceLabel => 'RM ${price.toStringAsFixed(0)}';
}

class WorkshopProduct {
  const WorkshopProduct({
    required this.name,
    required this.brand,
    required this.price,
  });

  final String name;
  final String brand;
  final double price;

  String get priceLabel => 'RM ${price.toStringAsFixed(0)}';
}

class WorkshopReview {
  const WorkshopReview({
    required this.author,
    required this.rating,
    required this.comment,
    this.priceTransparency,
    this.serviceQuality,
    this.timestamp,
  });

  final String author;
  final double rating;
  final String comment;
  final double? priceTransparency;
  final double? serviceQuality;
  final DateTime? timestamp;

  Map<String, dynamic> toMap() {
    return {
      'author': author,
      'rating': rating,
      'comment': comment,
      'priceTransparency': priceTransparency,
      'serviceQuality': serviceQuality,
      'timestamp': timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory WorkshopReview.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    if (map['timestamp'] != null) {
      if (map['timestamp'] is Timestamp) {
        parsedDate = (map['timestamp'] as Timestamp).toDate();
      } else if (map['timestamp'] is String) {
        parsedDate = DateTime.tryParse(map['timestamp']);
      }
    }

    return WorkshopReview(
      author: map['author'] ?? 'Anonymous',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      priceTransparency: (map['priceTransparency'] ?? 0.0).toDouble(),
      serviceQuality: (map['serviceQuality'] ?? 0.0).toDouble(),
      timestamp: parsedDate,
    );
  }
}
