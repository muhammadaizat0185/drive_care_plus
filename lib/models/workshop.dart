import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    return WorkshopReview(
      author: map['author'] ?? 'Anonymous',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      priceTransparency: (map['priceTransparency'] ?? 0.0).toDouble(),
      serviceQuality: (map['serviceQuality'] ?? 0.0).toDouble(),
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : null,
    );
  }
}
