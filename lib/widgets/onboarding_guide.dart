import 'package:flutter/material.dart';

class OnboardingGuide extends StatefulWidget {
  const OnboardingGuide({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingGuide> createState() => _OnboardingGuideState();
}

class _OnboardingGuideState extends State<OnboardingGuide> {
  final _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Welcome to DriveCare+',
      'subtitle': 'SMART COCKPIT & TRIP MONITOR',
      'desc': 'Discover real-time trip trajectory details, visual engine diagnostics, and an intelligent visual dashboard crafted for modern vehicle management.',
      'icon': Icons.rocket_launch_outlined,
      'color': Color(0xFF3B82F6),
    },
    {
      'title': 'Advanced Cost Calculator',
      'subtitle': 'TRANSPARENT REPAIR ESTIMATES',
      'desc': 'Batch-calculate workshop rates, select fully customized synthetic oils, append individual damages, and read multidimensional rating breakdowns.',
      'icon': Icons.calculate_outlined,
      'color': Color(0xFF10B981),
    },
    {
      'title': 'Predictive Maintenance',
      'subtitle': 'VEHICLE COMPONENT HEALTH',
      'desc': 'Monitor critical Engine Oil, Brakes, and Tyre condition percentage gauges. Keep logs of registered vehicles and update digital records instantly.',
      'icon': Icons.health_and_safety_outlined,
      'color': Color(0xFFF59E0B),
    }
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            // Swipeable Page Contents
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  final Color accentColor = slide['color'];

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Neon Ring Icon Circle
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: accentColor.withOpacity(0.25), width: 1.5),
                          ),
                          child: Icon(slide['icon'], size: 44, color: accentColor),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          slide['subtitle'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          slide['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['desc'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator Dots Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (index) {
                final isSelected = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _slides[_currentPage]['color']
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            // Navigation Button segment
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onFinished,
                    child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  Container(
                    height: 48,
                    width: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _slides[_currentPage]['color'],
                          (_slides[_currentPage]['color'] as Color).withBlue(130),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_slides[_currentPage]['color'] as Color).withOpacity(0.3),
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
                        if (_currentPage < _slides.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          widget.onFinished();
                        }
                      },
                      child: Text(
                        _currentPage == _slides.length - 1 ? 'Get Started' : 'Continue',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
