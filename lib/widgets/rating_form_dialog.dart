import 'package:flutter/material.dart';
import '../models/workshop.dart';

class RatingFormDialog extends StatefulWidget {
  const RatingFormDialog({
    super.key,
    required this.onSubmitted,
  });

  final Function(WorkshopReview review) onSubmitted;

  @override
  State<RatingFormDialog> createState() => _RatingFormDialogState();
}

class _RatingFormDialogState extends State<RatingFormDialog> {
  final _authorController = TextEditingController();
  final _commentController = TextEditingController();
  
  double _priceTransparencyRating = 5.0;
  double _serviceQualityRating = 5.0;
  double _overallRating = 5.0;

  @override
  void dispose() {
    _authorController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Widget _buildStarSelector({
    required String label,
    required double rating,
    required ValueChanged<double> onChanged,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color.withOpacity(0.8),
            inactiveTrackColor: color.withOpacity(0.15),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            valueIndicatorColor: color,
          ),
          child: Slider(
            value: rating,
            min: 1.0,
            max: 5.0,
            divisions: 4,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rate Workshop',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _authorController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStarSelector(
                  label: 'Price Transparency',
                  rating: _priceTransparencyRating,
                  color: const Color(0xFF10B981),
                  onChanged: (val) => setState(() => _priceTransparencyRating = val),
                ),
                const SizedBox(height: 8),
                _buildStarSelector(
                  label: 'Service Quality',
                  rating: _serviceQualityRating,
                  color: Colors.orange,
                  onChanged: (val) => setState(() => _serviceQualityRating = val),
                ),
                const SizedBox(height: 8),
                _buildStarSelector(
                  label: 'Overall Satisfaction',
                  rating: _overallRating,
                  color: primaryColor,
                  onChanged: (val) => setState(() => _overallRating = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Write a Review...',
                    labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                    prefixIcon: const Icon(Icons.rate_review_outlined, size: 20),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, primaryColor.withBlue(100)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            final name = _authorController.text.trim();
                            final comment = _commentController.text.trim();

                            if (name.isEmpty || comment.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill out all fields first.')),
                              );
                              return;
                            }

                            final newReview = WorkshopReview(
                              author: name,
                              rating: _overallRating,
                              comment: comment,
                              priceTransparency: _priceTransparencyRating,
                              serviceQuality: _serviceQualityRating,
                            );

                            widget.onSubmitted(newReview);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Submit Review',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
