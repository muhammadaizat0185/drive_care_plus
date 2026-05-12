import 'package:flutter/material.dart';

import '../models/workshop.dart';
import '../services/marketplace_repository.dart';
import '../widgets/star_rating.dart';
import 'workshop_detail_screen.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  static const routeName = '/booking';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workshop Marketplace')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final workshop = MarketplaceRepository.workshops[index];
          return _WorkshopCard(workshop: workshop);
        },
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemCount: MarketplaceRepository.workshops.length,
      ),
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({required this.workshop});

  final Workshop workshop;

  @override
  Widget build(BuildContext context) {
    final lowestPrice = workshop.services
        .map((service) => service.price)
        .reduce((value, element) => value < element ? value : element);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workshop.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            StarRating(rating: workshop.rating),
            const SizedBox(height: 6),
            Text('${workshop.distance} • ${workshop.reviewCount} reviews'),
            const SizedBox(height: 4),
            Text('Services from RM ${lowestPrice.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openDetails(context),
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Quote'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openDetails(context),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Book Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkshopDetailScreen(workshop: workshop),
      ),
    );
  }
}
