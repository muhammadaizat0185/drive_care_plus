import '../models/workshop.dart';

class MarketplaceRepository {
  const MarketplaceRepository._();

  static const workshops = [
    Workshop(
      id: 'autocare-bp',
      name: 'AutoCare Batu Pahat',
      distance: '1.2 km away',
      address: 'Jalan Kluang, Batu Pahat',
      rating: 4.8,
      reviewCount: 126,
      description:
          'Fast daily maintenance, oil service, and vehicle inspection.',
      services: [
        WorkshopService(
          name: 'Synthetic Oil Change',
          price: 150,
          duration: '45 min',
        ),
        WorkshopService(
          name: 'Brake Inspection',
          price: 60,
          duration: '30 min',
        ),
        WorkshopService(name: 'Tyre Rotation', price: 40, duration: '25 min'),
      ],
      reviews: [
        WorkshopReview(
          author: 'Aiman',
          rating: 5,
          comment: 'Quick service and clear pricing.',
        ),
        WorkshopReview(
          author: 'Nurul',
          rating: 5,
          comment: 'Good explanation before repair.',
        ),
      ],
    ),
    Workshop(
      id: 'speedfix',
      name: 'SpeedFix Workshop',
      distance: '2.8 km away',
      address: 'Taman Universiti, Parit Raja',
      rating: 4.6,
      reviewCount: 88,
      description: 'Reliable workshop for brakes, battery, and minor repairs.',
      services: [
        WorkshopService(
          name: 'Battery Health Check',
          price: 25,
          duration: '15 min',
        ),
        WorkshopService(
          name: 'Brake Pad Replacement',
          price: 180,
          duration: '1 hr 15 min',
        ),
        WorkshopService(
          name: 'General Diagnostic',
          price: 70,
          duration: '35 min',
        ),
      ],
      reviews: [
        WorkshopReview(
          author: 'Syafiq',
          rating: 4,
          comment: 'Helpful staff and affordable inspection.',
        ),
        WorkshopReview(
          author: 'Hafiz',
          rating: 5,
          comment: 'Booking was smooth.',
        ),
      ],
    ),
    Workshop(
      id: 'roadready',
      name: 'RoadReady Garage',
      distance: '4.1 km away',
      address: 'Bandar Penggaram, Batu Pahat',
      rating: 4.4,
      reviewCount: 64,
      description: 'Tyre, alignment, and road safety service specialist.',
      services: [
        WorkshopService(name: 'Wheel Alignment', price: 55, duration: '30 min'),
        WorkshopService(name: 'Tyre Balancing', price: 45, duration: '30 min'),
        WorkshopService(
          name: 'Full Safety Check',
          price: 95,
          duration: '50 min',
        ),
      ],
      reviews: [
        WorkshopReview(
          author: 'Danish',
          rating: 4,
          comment: 'Good for tyre and alignment service.',
        ),
        WorkshopReview(
          author: 'Mira',
          rating: 5,
          comment: 'Clean workshop and friendly mechanic.',
        ),
      ],
    ),
  ];
}
