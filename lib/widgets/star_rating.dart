import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 18,
    this.showValue = true,
  });

  final double rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    // Safety check for non-finite ratings
    final displayRating = rating.isFinite ? rating : 0.0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 1; index <= 5; index++)
          Icon(
            index <= displayRating.round() ? Icons.star : Icons.star_border,
            size: size,
            color: Theme.of(context).colorScheme.secondary,
          ),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            displayRating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ],
    );
  }
}
