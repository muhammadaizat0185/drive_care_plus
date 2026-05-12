// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'glass_container.dart';
import '../services/vehicle_insights.dart';
import '../screens/booking_screen.dart';

class VehicleHealthGauge extends StatelessWidget {
  const VehicleHealthGauge({super.key});

  @override
  Widget build(BuildContext context) {
    final insights = VehicleInsights.instance;
    final kmLeft = insights.kmUntilServiceInstance;
    final totalInterval = 10000.0; // Standard service interval 10,000 km
    final rawPercentage = (kmLeft / totalInterval).clamp(0.0, 1.0);
    final displayPercentage = (rawPercentage * 100).toInt();

    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final isCritical = kmLeft <= 500;

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      opacity: 0.1,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Car Health',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937), // Point 3: Charcoal soft contrast
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'MAINTENANCE STATUS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0, // Point 3: Kerning/letter-spacing increase
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isCritical ? Colors.red : primaryColor).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCritical ? 'Service Due!' : 'Healthy',
                  style: TextStyle(
                    color: isCritical ? Colors.red : primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Point 4: Glowing Custom Circular Gauge Painter
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
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
                            fontSize: 20,
                            color: isCritical ? Colors.red : const Color(0xFF1F2937),
                          ),
                        ),
                        const Text(
                          'STATUS',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              // Textual Breakdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${kmLeft.toStringAsFixed(0)} km',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937), // Point 3: Charcoal soft contrast
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Remaining until next service',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          '~${insights.predictedServiceDueDaysInstance} Days left',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Point 2 & 6: Micro-interactive Animated Tactile Gradient Button
          _AnimatedGradientButton(
            isCritical: isCritical,
            primaryColor: primaryColor,
            onTap: () {
              Navigator.pushNamed(context, BookingScreen.routeName);
            },
          ),
        ],
      ),
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
