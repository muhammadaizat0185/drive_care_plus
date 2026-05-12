import 'package:flutter/material.dart';

import '../services/marketplace_repository.dart';
import 'workshop_detail_screen.dart';

class WorkshopMapScreen extends StatelessWidget {
  const WorkshopMapScreen({super.key});

  static const routeName = '/workshop-map';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workshop Map')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nearby Workshops',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dummy map view. Later this becomes Google Maps with live location and markers.',
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 1.25,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _MapGridPainter(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const Align(
                            alignment: Alignment(0.05, 0.25),
                            child: _UserDot(),
                          ),
                          _WorkshopMarker(
                            alignment: const Alignment(-0.55, -0.35),
                            index: 0,
                            onTap: () => _openWorkshop(context, 0),
                          ),
                          _WorkshopMarker(
                            alignment: const Alignment(0.52, -0.2),
                            index: 1,
                            onTap: () => _openWorkshop(context, 1),
                          ),
                          _WorkshopMarker(
                            alignment: const Alignment(0.25, 0.68),
                            index: 2,
                            onTap: () => _openWorkshop(context, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (
            var index = 0;
            index < MarketplaceRepository.workshops.length;
            index++
          )
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(MarketplaceRepository.workshops[index].name),
                subtitle: Text(MarketplaceRepository.workshops[index].distance),
                trailing: TextButton(
                  onPressed: () => _showDirections(context, index),
                  child: const Text('Directions'),
                ),
                onTap: () => _openWorkshop(context, index),
              ),
            ),
        ],
      ),
    );
  }

  void _openWorkshop(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkshopDetailScreen(
          workshop: MarketplaceRepository.workshops[index],
        ),
      ),
    );
  }

  void _showDirections(BuildContext context, int index) {
    final workshop = MarketplaceRepository.workshops[index];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Directions placeholder: launch Google Maps/Waze to ${workshop.name}.',
        ),
      ),
    );
  }
}

class _WorkshopMarker extends StatelessWidget {
  const _WorkshopMarker({
    required this.alignment,
    required this.index,
    required this.onTap,
  });

  final Alignment alignment;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IconButton.filled(
        onPressed: onTap,
        icon: const Icon(Icons.build_outlined),
        tooltip: MarketplaceRepository.workshops[index].name,
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = color.withValues(alpha: 0.24)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final minorRoadPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.2),
      Offset(size.width * 0.9, size.height * 0.74),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.82),
      Offset(size.width * 0.82, size.height * 0.16),
      minorRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.52),
      Offset(size.width * 0.92, size.height * 0.48),
      minorRoadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
