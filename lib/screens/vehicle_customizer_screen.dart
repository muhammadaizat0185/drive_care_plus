import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/vehicle_insights.dart';

class VehicleCustomizerScreen extends StatefulWidget {
  const VehicleCustomizerScreen({super.key});

  @override
  State<VehicleCustomizerScreen> createState() => _VehicleCustomizerScreenState();
}

class _VehicleCustomizerScreenState extends State<VehicleCustomizerScreen> {
  final List<String> _carTypes = [
    'sedan', 'suv', 'sport', 'pickup', 'jeep', 'coupe', 'compact', 'cabriolet'
  ];

  final List<Map<String, dynamic>> _presetColors = [
    {'name': 'Royal Blue', 'color': const Color(0xFF3B82F6)},
    {'name': 'Flame Red', 'color': const Color(0xFFEF4444)},
    {'name': 'Emerald', 'color': const Color(0xFF10B981)},
    {'name': 'Onyx Black', 'color': const Color(0xFF1F2937)},
    {'name': 'Pearl White', 'color': const Color(0xFFF9FAFB)},
    {'name': 'Amber Gold', 'color': const Color(0xFFF59E0B)},
    {'name': 'Midnight Purple', 'color': const Color(0xFF8B5CF6)},
    {'name': 'Graphite Grey', 'color': const Color(0xFF6B7280)},
  ];

  late String _selectedType;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    final insights = VehicleInsights.instance;
    _selectedType = insights.carType;
    _selectedColor = _parseColor(insights.carColor);
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Select Vehicle Style', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Preview Section
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 40,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/cars/Car Vector/SVG/${_selectedType}_front.svg',
                            height: 220,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _selectedType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Customization Controls
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose Body Style',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select the model that best represents your vehicle.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 50,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _carTypes.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final type = _carTypes[index];
                            final isSelected = _selectedType == type;
                            return ChoiceChip(
                              label: Text(type[0].toUpperCase() + type.substring(1)),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) setState(() => _selectedType = type);
                              },
                              selectedColor: primaryColor,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          },
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () async {
                            await VehicleInsights.instance.updateVehicle(
                              model: VehicleInsights.instance.model,
                              plate: VehicleInsights.instance.plate,
                              fuelType: VehicleInsights.instance.fuelType,
                              currentMileageKm: VehicleInsights.instance.currentMileageKm,
                              carType: _selectedType,
                            );
                            if (mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            shadowColor: primaryColor.withOpacity(0.5),
                          ),
                          child: const Text(
                            'Update Vehicle Style',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
