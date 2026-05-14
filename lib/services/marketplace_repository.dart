import '../models/workshop.dart';

class MarketplaceRepository {
  const MarketplaceRepository._();

  static const workshops = [
    Workshop(
      id: 'autocare-bp',
      name: 'AutoCare Batu Pahat',
      distance: '1.2 km away',
      distanceValue: 1.2,
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
          products: [
            WorkshopProduct(name: 'Helix Ultra 5W-40', brand: 'Shell', price: 180),
            WorkshopProduct(name: 'Syntium 3000 5W-40', brand: 'Petronas', price: 150),
            WorkshopProduct(name: 'Mobil 1 FS 0W-40', brand: 'Mobil', price: 210),
          ],
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
      distanceValue: 2.8,
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
          products: [
            WorkshopProduct(name: 'Standard Ceramic', brand: 'Brembo', price: 220),
            WorkshopProduct(name: 'OEM Replacement', brand: 'Perodua', price: 180),
            WorkshopProduct(name: 'OEM Replacement', brand: 'Proton', price: 190),
            WorkshopProduct(name: 'Performance Pads', brand: 'Endless', price: 350),
          ],
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
      distanceValue: 4.1,
      address: 'Bandar Penggaram, Batu Pahat',
      rating: 4.4,
      reviewCount: 64,
      description: 'Tyre, alignment, and road safety service specialist.',
      services: [
        WorkshopService(name: 'Wheel Alignment', price: 55, duration: '30 min'),
        WorkshopService(
          name: 'Tyre Replacement', 
          price: 160, 
          duration: '40 min',
          products: [
            WorkshopProduct(name: 'Primacy 4', brand: 'Michelin', price: 320),
            WorkshopProduct(name: 'Ecopia EP150', brand: 'Bridgestone', price: 180),
            WorkshopProduct(name: 'CC6', brand: 'Continental', price: 210),
            WorkshopProduct(name: 'SP Sport', brand: 'Dunlop', price: 160),
          ],
        ),
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
    Workshop(
      id: 'national-car-care',
      name: 'Nusantara Auto Specialist',
      distance: '3.5 km away',
      distanceValue: 3.5,
      address: 'Jalan Ibrahim, Batu Pahat',
      rating: 4.7,
      reviewCount: 94,
      description: 'Dedicated service center specializing in Perodua, Proton, and other local models.',
      services: [
        WorkshopService(
          name: 'Proton/Perodua Engine Tuning',
          price: 120,
          duration: '1 hr',
        ),
        WorkshopService(
          name: 'Major Oil Change (Proton/Perodua)',
          price: 240,
          duration: '1 hr 15 min',
          products: [
            WorkshopProduct(name: 'Proton Genuine Oil 10W-30', brand: 'Proton', price: 110),
            WorkshopProduct(name: 'Perodua Genuine Oil 5W-30', brand: 'Perodua', price: 125),
          ],
        ),
      ],
      reviews: [
        WorkshopReview(
          author: 'Zul',
          rating: 5,
          comment: 'Best workshop for Proton X50/Myvi. Very specialized.',
        ),
      ],
    ),
  ];
}
