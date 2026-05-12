class Workshop {
  const Workshop({
    required this.id,
    required this.name,
    required this.distance,
    required this.address,
    required this.rating,
    required this.reviewCount,
    required this.description,
    required this.services,
    required this.reviews,
  });

  final String id;
  final String name;
  final String distance;
  final String address;
  final double rating;
  final int reviewCount;
  final String description;
  final List<WorkshopService> services;
  final List<WorkshopReview> reviews;
}

class WorkshopService {
  const WorkshopService({
    required this.name,
    required this.price,
    required this.duration,
  });

  final String name;
  final double price;
  final String duration;

  String get priceLabel => 'RM ${price.toStringAsFixed(0)}';
}

class WorkshopReview {
  const WorkshopReview({
    required this.author,
    required this.rating,
    required this.comment,
  });

  final String author;
  final int rating;
  final String comment;
}
