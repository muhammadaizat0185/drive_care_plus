import 'package:flutter/material.dart';

class FuelChart extends StatelessWidget {
  const FuelChart({super.key, required this.dataPoints});

  final List<double> dataPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withAlpha(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fuel Economy Trend (km/L)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              if (dataPoints.length > 1)
                Text(
                  'Avg: ${(dataPoints.reduce((a, b) => a + b) / dataPoints.length).toStringAsFixed(1)} km/L',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: dataPoints.length < 2
                ? const Center(
                    child: Text(
                      'Log at least 2 refuels to generate a trend chart.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: _FuelCurvePainter(
                      dataPoints: dataPoints,
                      lineColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FuelCurvePainter extends CustomPainter {
  _FuelCurvePainter({required this.dataPoints, required this.lineColor});

  final List<double> dataPoints;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Determine scale limits
    double maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    double minVal = dataPoints.reduce((a, b) => a < b ? a : b);

    // Give some breathing room on top and bottom of chart
    maxVal = maxVal + 1.5;
    minVal = minVal - 1.5;
    if (minVal < 0) minVal = 0;

    final double range = maxVal - minVal;
    if (range <= 0) return;

    // 1. Draw Grid Lines & Labels
    final Paint gridPaint = Paint()
      ..color = Colors.grey.withAlpha(30)
      ..strokeWidth = 1.0;

    const int gridSegments = 3;
    for (int i = 0; i <= gridSegments; i++) {
      final double y = height - (i * (height / gridSegments));
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // 2. Map Points to Coordinates
    final List<Offset> points = [];
    final double stepX = width / (dataPoints.length - 1);
    for (int i = 0; i < dataPoints.length; i++) {
      final double x = i * stepX;
      final double y = height - (((dataPoints[i] - minVal) / range) * height);
      points.add(Offset(x, y));
    }

    // 3. Create Curved Path using Bezier Curves
    final Path path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = points[i];
      final Offset p1 = points[i + 1];
      final double controlX = p0.dx + (p1.dx - p0.dx) / 2;

      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // 4. Draw Gradient Area below the curve
    final Path fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, height);
    fillPath.lineTo(points.first.dx, height);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withAlpha(90), // Transparent top
          lineColor.withAlpha(0),  // Faded bottom
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 5. Draw Curve Stroke Line
    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // 6. Draw Glowing Node Points
    final Paint nodePaintOuter = Paint()
      ..color = lineColor.withAlpha(60)
      ..style = PaintingStyle.fill;

    final Paint nodePaintInner = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final Paint nodeBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final point in points) {
      // Glow outer
      canvas.drawCircle(point, 8.0, nodePaintOuter);
      // Solid inner
      canvas.drawCircle(point, 4.0, nodePaintInner);
      // White boundary
      canvas.drawCircle(point, 4.0, nodeBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
