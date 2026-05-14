import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/vehicle_insights.dart';

class CarHealthOverlay extends StatelessWidget {
  final String carType;
  final List<MaintenanceItem> watchlist;

  const CarHealthOverlay({
    super.key,
    required this.carType,
    required this.watchlist,
  });

  @override
  Widget build(BuildContext context) {
    // Find health of specific components
    double tireHealth = 100.0;
    double oilHealth = 100.0;
    
    for (var item in watchlist) {
      if (item.name.toLowerCase().contains('tyre') || item.name.toLowerCase().contains('tire')) {
        tireHealth = min(tireHealth, item.healthPercentage);
      }
      if (item.name.toLowerCase().contains('oil')) {
        oilHealth = min(oilHealth, item.healthPercentage);
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // The Side View Car SVG
        SvgPicture.asset(
          'assets/images/cars/Car Vector/SVG/${carType}_left_side.svg',
          height: 140,
        ),
        
        // Dynamic Glow Overlays
        // Tire Glows (Front and Back)
        Positioned(
          left: 45,
          bottom: 10,
          child: _ComponentGlow(health: tireHealth, size: 40),
        ),
        Positioned(
          right: 45,
          bottom: 10,
          child: _ComponentGlow(health: tireHealth, size: 40),
        ),
        
        // Engine Glow (Front area)
        Positioned(
          left: 30,
          top: 40,
          child: _ComponentGlow(health: oilHealth, size: 60),
        ),
      ],
    );
  }
}

class _ComponentGlow extends StatelessWidget {
  final double health;
  final double size;

  const _ComponentGlow({required this.health, required this.size});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (health <= 20) {
      color = Colors.red;
    } else if (health <= 50) {
      color = Colors.orange;
    } else {
      return const SizedBox.shrink(); // No glow for healthy parts
    }

    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }
}

class LiquidSquircleGauge extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color color;
  final String label;

  const LiquidSquircleGauge({
    super.key,
    required this.value,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: SquircleProgressPainter(
              progress: value,
              color: color,
              backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const Text(
                    'LIFE',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class SquircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  SquircleProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.3));
    
    // Background Squircle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // Liquid Progress Fill (clipping to squircle)
    canvas.save();
    canvas.clipRRect(rrect);
    
    final fillValue = progress.isNaN || progress.isInfinite ? 0.0 : progress;
    final fillHeight = size.height * fillValue;
    final fillRect = Rect.fromLTRB(0, size.height - fillHeight, size.width, size.height);
    
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.8), color],
      ).createShader(fillRect);
      
    canvas.drawRect(fillRect, fillPaint);
    
    // Subtle wave or shine effect
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(0, size.height - fillHeight, size.width, size.height - fillHeight + 10), shinePaint);
    
    canvas.restore();
    
    // Outline
    final borderPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
