import 'package:flutter/material.dart';

class EcoInsightsCard extends StatelessWidget {
  final double kmPerLiter;

  const EcoInsightsCard({
    super.key,
    required this.kmPerLiter,
  });

  @override
  Widget build(BuildContext context) {
    if (kmPerLiter <= 0) return const SizedBox.shrink();

    final isExcellent = kmPerLiter >= 16.0;
    final isModerate = kmPerLiter >= 12.0 && kmPerLiter < 16.0;

    // Premium Color Gradients based on efficiency
    final gradientColors = isExcellent
        ? [const Color(0xFF11998e), const Color(0xFF38ef7d)] // Greenish
        : isModerate
            ? [const Color(0xFFf39c12), const Color(0xFFf1c40f)] // Amberish
            : [const Color(0xFFcb2d3e), const Color(0xFFef473a)]; // Reddish

    final title = isExcellent
        ? 'Excellent Efficiency! 🎉'
        : isModerate
            ? 'Moderate Efficiency'
            : 'Low Efficiency Alert ⚠️';

    final advice = isExcellent
        ? 'Your vehicle is operating at peak performance! Keep up the smooth braking and steady highway speeds.'
        : isModerate
            ? 'Good, but there is room to improve. Consider inflating your tyres to the recommended PSI and clearing any heavy boot luggage.'
            : 'Your efficiency is below average. We recommend performing a spark plug inspection, checking your air filter, or cleaning the fuel injectors.';

    final icon = isExcellent
        ? Icons.eco_outlined
        : isModerate
            ? Icons.info_outline
            : Icons.warning_amber_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advice,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Current Log Rate: ${kmPerLiter.toStringAsFixed(1)} km/L',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
