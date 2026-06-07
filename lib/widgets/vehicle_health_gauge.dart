// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'glass_container.dart';
import '../services/vehicle_insights.dart';

class VehicleHealthGauge extends StatelessWidget {
  const VehicleHealthGauge({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final insights = VehicleInsights.instance;

    return ListenableBuilder(
      listenable: insights,
      builder: (context, child) {
        // Get the most urgent health percentage from all watchlist items
        final watchlist = insights.watchlistItems;
        double rawPercentage = 1.0;
        if (watchlist.isNotEmpty) {
          final minHealth = watchlist.map((e) => e.healthPercentage).reduce((a, b) => a < b ? a : b);
          rawPercentage = (minHealth / 100.0).clamp(0.0, 1.0);
        }

        final kmLeft = insights.kmUntilServiceInstance;
        final displayPercentage = (rawPercentage * 100).toInt();

        final Color primaryColor = Theme.of(context).colorScheme.primary;
        final isCritical = kmLeft <= 500;

        // Determine asset path based on carType
        String assetName;
        switch (insights.carType.toLowerCase()) {
          case 'sedan': assetName = 'Sedan Front.png'; break;
          case 'suv': assetName = 'SUV Front.png'; break;
          case 'jeep': assetName = 'Jeep Front.png'; break;
          case 'pickup': assetName = 'Pickup Front.png'; break;
          case 'sport': assetName = 'Sport Front.png'; break;
          case 'coupe': assetName = 'Coupe Front.png'; break;
          case 'cabriolet': assetName = 'Cabriolet Front.png'; break;
          case 'compact':
          default: assetName = 'Compact Front.png'; break;
        }
        final assetPath = 'assets/images/cars/Car Vector/PNG/$assetName';

        return GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          opacity: 0.1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Car Health',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        insights.model.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isCritical ? Colors.red : primaryColor).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isCritical ? 'Service Due!' : 'Healthy',
                      style: TextStyle(
                        color: isCritical ? Colors.red : primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Car Illustration Center with Toggle Buttons
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Image.asset(
                      assetPath,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (insights.vehicles.length > 1)
                    Positioned(
                      right: -10,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right, size: 32, color: Colors.grey),
                        onPressed: () {
                          final nextIndex = (insights.activeVehicleIndex + 1) % insights.vehicles.length;
                          insights.setActiveVehicle(nextIndex);
                        },
                      ),
                    ),
                  if (insights.vehicles.length > 1)
                    Positioned(
                      left: -10,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left, size: 32, color: Colors.grey),
                        onPressed: () {
                          final prevIndex = (insights.activeVehicleIndex - 1 + insights.vehicles.length) % insights.vehicles.length;
                          insights.setActiveVehicle(prevIndex);
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Bottom Row with Gauge and Info
              Row(
                children: [
                  // Circular Gauge
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(80, 80),
                          painter: _HealthGaugePainter(
                            percentage: rawPercentage,
                            activeColor: isCritical ? Colors.red : primaryColor,
                            trackColor: Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$displayPercentage%',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: isCritical
                                    ? Colors.red
                                    : (isDark ? Colors.white : const Color(0xFF1F2937)),
                              ),
                            ),
                            const Text(
                              'STATUS',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Mileage Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${kmLeft.toStringAsFixed(0)} km',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                        const Text(
                          'Remaining until next service',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Text(
                              '~${insights.predictedServiceDueDaysInstance} Days left',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Points 2 & 6: Tactile, animated linear gradient button class
class _AnimatedGradientButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isCritical;
  final Color primaryColor;

  const _AnimatedGradientButton({
    required this.onTap,
    required this.isCritical,
    required this.primaryColor,
  });

  @override
  State<_AnimatedGradientButton> createState() => _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<_AnimatedGradientButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    // Point 2: Tactical vibrant-to-deep gradients
    final gradientColors = widget.isCritical
        ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
        : [const Color(0xFF10B981), const Color(0xFF047857)];

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 0.96; // Point 6: tactile shrink feedback
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
        widget.onTap();
      },
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.calendar_month, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Book Service Visit',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5, // Point 3: subheader kerning
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Point 4: Glowing circular dial progress painter
class _HealthGaugePainter extends CustomPainter {
  final double percentage;
  final Color activeColor;
  final Color trackColor;

  _HealthGaugePainter({
    required this.percentage,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 6;

    // Track path
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Point 4: Neon Light emission glow shadow path underlay
    final glowPaint = Paint()
      ..color = activeColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Active path
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final startAngle = -pi / 2;
    final sweepAngle = 2 * pi * percentage;

    // Draw glowing underlay
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Draw crisp foreground active arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
