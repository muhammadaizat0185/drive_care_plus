import 'package:flutter/material.dart';

class CarHealthDiagram extends StatelessWidget {
  const CarHealthDiagram({super.key, required this.onPartSelected});

  final ValueChanged<String> onPartSelected;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CarDiagramPainter(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              _PartButton(
                label: 'Engine',
                alignment: const Alignment(0, -0.35),
                onTap: () => onPartSelected('Engine health is good.'),
              ),
              _PartButton(
                label: 'Tyres',
                alignment: const Alignment(-0.72, 0.46),
                onTap: () => onPartSelected('Tyre rotation is recommended.'),
              ),
              _PartButton(
                label: 'Brakes',
                alignment: const Alignment(0.72, 0.46),
                onTap: () => onPartSelected('Brake check is due soon.'),
              ),
              _PartButton(
                label: 'Battery',
                alignment: const Alignment(0.6, -0.22),
                onTap: () => onPartSelected('Battery status is normal.'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PartButton extends StatelessWidget {
  const _PartButton({
    required this.label,
    required this.alignment,
    required this.onTap,
  });

  final String label;
  final Alignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Material(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarDiagramPainter extends CustomPainter {
  const _CarDiagramPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final tyrePaint = Paint()
      ..color = const Color(0xFF14211D)
      ..style = PaintingStyle.fill;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.16,
        size.height * 0.3,
        size.width * 0.68,
        size.height * 0.42,
      ),
      const Radius.circular(28),
    );
    canvas.drawRRect(body, bodyPaint);
    canvas.drawRRect(body, outlinePaint);

    final cabin = Path()
      ..moveTo(size.width * 0.34, size.height * 0.3)
      ..lineTo(size.width * 0.43, size.height * 0.13)
      ..lineTo(size.width * 0.58, size.height * 0.13)
      ..lineTo(size.width * 0.68, size.height * 0.3)
      ..close();
    canvas.drawPath(cabin, bodyPaint);
    canvas.drawPath(cabin, outlinePaint);

    canvas.drawCircle(
      Offset(size.width * 0.26, size.height * 0.76),
      size.width * 0.075,
      tyrePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.76),
      size.width * 0.075,
      tyrePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CarDiagramPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
