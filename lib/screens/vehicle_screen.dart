import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/color_utils.dart';
import '../services/car_database.dart';
import '../services/profile_service.dart';
import '../services/vehicle_insights.dart';
import '../widgets/car_health_overlay.dart';
import 'home_screen.dart';
import 'vehicle_customizer_screen.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  static const routeName = '/vehicle';

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

 class _VehicleScreenState extends State<VehicleScreen> {
  final _carouselScrollController = ScrollController();
  final Set<String> _selectedMaintenanceItems = {};

  Widget _cardContainer({
    required Widget child,
    required bool isDark,
    Color? backgroundColor,
    BoxBorder? border,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: border ?? Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _carouselScrollController.dispose();
    super.dispose();
  }

  void _showMileageUpdateDialog(VehicleInsights insights) {
    final controller = TextEditingController(text: insights.currentMileageKm.toStringAsFixed(0));
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Update Odometer', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your current vehicle mileage to keep your health tracking accurate.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
                decoration: InputDecoration(
                  labelText: 'Current Mileage (km)',
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final mileage = double.tryParse(controller.text) ?? 0.0;
                if (mileage >= insights.currentMileageKm) {
                  insights.updateCurrentMileage(mileage);
                  Navigator.pop(context);
                  HapticFeedback.mediumImpact();
                } else {
                  setDialogState(() {
                    errorText = 'Mileage cannot be lower than ${insights.currentMileageKm.toStringAsFixed(0)} km';
                  });
                  HapticFeedback.vibrate();
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _logBatchMaintenance(VehicleInsights insights) {
    final mileageController = TextEditingController(text: insights.currentMileageKm.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log Maintenance', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Logging ${_selectedMaintenanceItems.length} items. At what mileage was this performed?', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: mileageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Service Mileage (km)',
                filled: true,
                fillColor: Colors.grey.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final mileage = double.tryParse(mileageController.text) ?? insights.currentMileageKm;
              insights.logMaintenance(_selectedMaintenanceItems.toList(), mileage);
              setState(() => _selectedMaintenanceItems.clear());
              Navigator.pop(context);
              HapticFeedback.heavyImpact();
            },
            child: const Text('Confirm Log'),
          ),
        ],
      ),
    );
  }

  double _getEngineHealth(VehicleInsights insights) {
    try {
      final item = insights.watchlistItems.firstWhere((element) => element.name.toLowerCase().contains('oil'));
      return (item.remainingKm / 10000.0).clamp(0.0, 1.0);
    } catch (_) {
      return 0.85;
    }
  }

  double _getBrakesHealth(VehicleInsights insights) {
    try {
      final item = insights.watchlistItems.firstWhere((element) => element.name.toLowerCase().contains('brake'));
      return (item.remainingKm / 40000.0).clamp(0.0, 1.0);
    } catch (_) {
      return 0.90;
    }
  }

  double _getTiresHealth(VehicleInsights insights) {
    try {
      final item = insights.watchlistItems.firstWhere((element) => element.name.toLowerCase().contains('tyre') || element.name.toLowerCase().contains('tire'));
      return (item.remainingKm / 50000.0).clamp(0.0, 1.0);
    } catch (_) {
      return 0.75;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Vehicle Profile', style: TextStyle(fontWeight: FontWeight.bold))),
        body: ListenableBuilder(
          listenable: VehicleInsights.instance,
          builder: (context, child) {
            final insights = VehicleInsights.instance;
  
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                // Quick Mileage Update Card
                _buildMileageCard(context, insights),
                const SizedBox(height: 16),

                // Horizontal Vehicles Carousel Section
                _buildVehiclesCarousel(context, insights),
                const SizedBox(height: 16),
  
                // Glowing Component Health Dashboard Gauge Card
                _buildComponentHealthDashboard(context, insights),
                const SizedBox(height: 16),
  
                // Primary Active Vehicle Details Specifications Card
                _cardContainer(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Specifications',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const VehicleCustomizerScreen()),
                                  );
                                },
                                icon: const Icon(Icons.palette_outlined, size: 20),
                                tooltip: 'Customize Look',
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: _showEditVehicleDialog,
                                icon: const Icon(Icons.edit_note, size: 20),
                                tooltip: 'Edit Specifications',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _specTile(Icons.directions_car_outlined, 'Model', insights.model),
                      _specTile(Icons.pin_outlined, 'Plate number', insights.plate),
                      _specTile(Icons.speed_outlined, 'Current mileage', '${insights.currentMileageKm.toStringAsFixed(0)} km'),
                      _specTile(Icons.local_gas_station_outlined, 'Fuel type', insights.fuelType),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(),
                      ),
                      
                      Text(
                        'Manufacturer Specifications',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _specTile(Icons.settings_suggest_outlined, 'Engine', insights.engine),
                      _specTile(Icons.settings_input_component_outlined, 'Transmission', insights.transmission),
                      _specTile(Icons.local_gas_station, 'Fuel Tank Capacity', '${insights.fuelCapacityLiters.toStringAsFixed(0)} Liters'),
                      _specTile(Icons.tire_repair_outlined, 'Recommended Tyre Pressure', '${insights.recommendedTyrePressurePsi.toStringAsFixed(0)} PSI'),
                      _specTile(Icons.opacity_outlined, 'Engine Oil Capacity', '${insights.engineOilCapacityLiters.toStringAsFixed(1)} Liters'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
  
                // Predictive Maintenance List (Watchlist)
                _cardContainer(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Service Watchlist',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          if (_selectedMaintenanceItems.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _logBatchMaintenance(insights),
                              icon: const Icon(Icons.fact_check, size: 18),
                              label: Text('Log (${_selectedMaintenanceItems.length})'),
                              style: TextButton.styleFrom(foregroundColor: primaryColor),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...insights.watchlistItems.map((item) {
                        final isSelected = _selectedMaintenanceItems.contains(item.name);
                        Color statusColor;
                        if (item.status == 'Red') {
                          statusColor = Colors.red;
                        } else if (item.status == 'Yellow') {
                          statusColor = Colors.orange;
                        } else {
                          statusColor = Colors.green;
                        }

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedMaintenanceItems.add(item.name);
                              } else {
                                _selectedMaintenanceItems.remove(item.name);
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          activeColor: primaryColor,
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Due in ${item.remainingKm.toStringAsFixed(0)} km', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('Predicted Due: ${item.predictedDateStr}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          secondary: Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2)),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _specTile(IconData icon, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey.shade500),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
      subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      dense: true,
    );
  }

  Widget _buildVehiclesCarousel(BuildContext context, VehicleInsights insights) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            'My Garage',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: Scrollbar(
            controller: _carouselScrollController,
            thumbVisibility: false,
            child: ListView.builder(
              controller: _carouselScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: insights.vehicles.length + 1,
              itemBuilder: (context, index) {
                if (index == insights.vehicles.length) {
                  // Add vehicle Card
                  return GestureDetector(
                    onTap: _showRegisterVehicleDialog,
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.grey, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Add',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final vehicle = insights.vehicles[index];
                final isActive = index == insights.activeVehicleIndex;

                  return GestureDetector(
                  onTap: () => insights.setActiveVehicle(index),
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? primaryColor.withOpacity(0.1)
                          : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? primaryColor : Colors.grey.withOpacity(0.1),
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isActive
                              ? primaryColor.withOpacity(0.1)
                              : Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Left: Car Image (Front View)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              vehicle['carType'] == 'exoraGold'
                                  ? 'assets/images/cars/Premium/exoraGold_front.svg'
                                  : 'assets/images/cars/Car Vector/SVG/${vehicle['carType'] ?? 'sedan'}_front.svg',
                              height: 50,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Right: Info Stack
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle['model'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isActive ? primaryColor : (isDark ? Colors.white : Colors.black87),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vehicle['plate'] ?? '---',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: (isDark ? Colors.white70 : Colors.black54),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.speed, size: 12, color: primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${((vehicle['currentMileageKm'] ?? 0) as num).toStringAsFixed(0)} km',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteVehicle(BuildContext context, VehicleInsights insights, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Remove Vehicle?'),
          content: Text('Are you sure you want to remove ${insights.vehicles[index]['model']} from your garage?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                insights.deleteVehicle(index);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vehicle removed.')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComponentHealthDashboard(BuildContext context, VehicleInsights insights) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final watchlist = insights.watchlistItems;
    
    double getHealth(String pattern) {
      try {
        return (watchlist.firstWhere((e) => e.name.toLowerCase().contains(pattern)).healthPercentage / 100).clamp(0.0, 1.0);
      } catch (_) {
        return 1.0; // Default to healthy if item not found
      }
    }

    final engineVal = getHealth('oil');
    final brakesVal = getHealth('brake');
    final tiresVal = getHealth('tyre');

    return _cardContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Diagnostic Health Profile',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // "Liquid Glass" Car Health Overlay
          Center(
            child: CarHealthOverlay(
              carType: insights.carType,
              watchlist: watchlist,
            ),
          ),
          const SizedBox(height: 32),
          // Squircle Liquid Gauges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              LiquidSquircleGauge(value: engineVal, color: const Color(0xFF10B981), label: 'Engine Oil'),
              LiquidSquircleGauge(value: brakesVal, color: Colors.orange, label: 'Brakes'),
              LiquidSquircleGauge(value: tiresVal, color: Colors.blue, label: 'Tires'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMileageCard(BuildContext context, VehicleInsights insights) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _cardContainer(
      isDark: isDark,
      backgroundColor: primaryColor.withOpacity(0.05),
      border: Border.all(color: primaryColor.withOpacity(0.1)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.speed, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Current Odometer', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text('${insights.currentMileageKm.toStringAsFixed(0)} KM', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showMileageUpdateDialog(insights),
            icon: const Icon(Icons.edit, size: 12),
            label: const Text('Update', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  Widget _circularGauge(String label, double value, Color activeColor, Color primaryColor) {
    final displayPercent = (value * 100).toInt();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                backgroundColor: Colors.grey.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$displayPercent%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    'HEALTH',
                    style: TextStyle(fontSize: 7, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
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

  void _showRegisterVehicleDialog() {
    final bool isPro = ProfileService.instance.isPro;
    final int carCount = VehicleInsights.instance.vehicles.length;
    if (!isPro && carCount >= 2) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const ProSubscriptionSheet(),
      );
      return;
    }

    final plateController = TextEditingController();
    final mileageController = TextEditingController();
    
    String? selectedBrand;
    String? selectedModel;
    String? selectedGen;
    String? selectedVariant;

    final customBrandController = TextEditingController();
    final customModelController = TextEditingController();
    final customGenController = TextEditingController();
    final customVariantController = TextEditingController();

    final engineController = TextEditingController();
    final transController = TextEditingController();
    final fuelCapController = TextEditingController();
    final tyreController = TextEditingController();
    final oilCapController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasSeededBrand = selectedBrand != null && CarDatabase.brandModels.containsKey(selectedBrand);
            final modelList = hasSeededBrand ? CarDatabase.brandModels[selectedBrand!]! : <CarModelData>[];

            CarModelData? modelData;
            if (selectedModel != null && selectedModel != 'Custom / Other') {
              try {
                modelData = modelList.firstWhere((m) => m.name == selectedModel);
              } catch (_) {
                modelData = null;
              }
            }
            final genList = modelData != null ? modelData.generations : <CarGeneration>[];

            CarGeneration? genData;
            if (selectedGen != null && selectedGen != 'Custom / Other') {
              try {
                genData = genList.firstWhere((g) => g.name == selectedGen);
              } catch (_) {
                genData = null;
              }
            }
            final variantList = genData != null ? genData.variants : <CarVariant>[];

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register New Vehicle',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: isDark ? Colors.white : const Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 20),
                        
                        TextField(
                          controller: plateController,
                          decoration: const InputDecoration(labelText: 'License Plate', prefixIcon: Icon(Icons.pin_outlined)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: mileageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Current Mileage (km)', prefixIcon: Icon(Icons.speed_outlined)),
                        ),
                        const SizedBox(height: 16),

                        // Dropdown selection fields
                        DropdownButtonFormField<String>(
                          value: selectedBrand,
                          hint: const Text('Select Vehicle Brand'),
                          items: CarDatabase.brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedBrand = val;
                              selectedModel = null;
                              selectedGen = null;
                              selectedVariant = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        if (selectedBrand != null) ...[
                          DropdownButtonFormField<String>(
                            value: selectedModel,
                            hint: const Text('Select Model'),
                            items: [
                              ...modelList.map((m) => DropdownMenuItem(value: m.name, child: Text(m.name))),
                              const DropdownMenuItem(value: 'Custom / Other', child: Text('Custom / Other')),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                selectedModel = val;
                                selectedGen = null;
                                selectedVariant = null;
                                if (val != 'Custom / Other') {
                                  customModelController.text = val!;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (selectedModel != null && selectedModel != 'Custom / Other') ...[
                          DropdownButtonFormField<String>(
                            value: selectedGen,
                            hint: const Text('Select Generation'),
                            items: [
                              ...genList.map((g) => DropdownMenuItem(value: g.name, child: Text(g.name))),
                              const DropdownMenuItem(value: 'Custom / Other', child: Text('Custom / Other')),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                selectedGen = val;
                                selectedVariant = null;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (selectedGen != null && selectedGen != 'Custom / Other') ...[
                          DropdownButtonFormField<String>(
                            value: selectedVariant,
                            hint: const Text('Select Variant'),
                            items: variantList.map((v) => DropdownMenuItem(value: v.name, child: Text(v.name))).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedVariant = val;
                                // Automatically pre-fill specs from variant database
                                if (val != null) {
                                  final variantObj = variantList.firstWhere((element) => element.name == val);
                                  final spec = variantObj.specification;
                                  engineController.text = spec.engine;
                                  transController.text = spec.transmission;
                                  fuelCapController.text = spec.fuelCapacityLiters.toStringAsFixed(0);
                                  tyreController.text = spec.recommendedTyrePressurePsi.toStringAsFixed(0);
                                  oilCapController.text = spec.engineOilCapacityLiters.toStringAsFixed(1);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (selectedModel == 'Custom / Other') ...[
                          TextField(controller: customModelController, decoration: const InputDecoration(labelText: 'Custom Model Name')),
                          const SizedBox(height: 12),
                        ],

                        const Divider(),
                        const SizedBox(height: 8),
                        const Text('Vehicle Specifications (Auto-filled or Custom)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 12),

                        TextField(controller: engineController, decoration: const InputDecoration(labelText: 'Engine Spec')),
                        const SizedBox(height: 12),
                        TextField(controller: transController, decoration: const InputDecoration(labelText: 'Transmission Spec')),
                        const SizedBox(height: 12),
                        TextField(controller: fuelCapController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fuel Tank Cap (Liters)')),
                        const SizedBox(height: 12),
                        TextField(controller: tyreController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Recommended Tyre Press (PSI)')),
                        const SizedBox(height: 12),
                        TextField(controller: oilCapController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Engine Oil Cap (Liters)')),
                        
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [primaryColor, primaryColor.withBlue(100)]),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                  onPressed: () async {
                                    final plate = plateController.text.trim();
                                    final mileage = double.tryParse(mileageController.text.trim()) ?? 0.0;
                                    final brand = selectedBrand ?? 'Custom';
                                    final modelVal = selectedModel == 'Custom / Other' ? customModelController.text.trim() : (selectedModel ?? 'Other');
                                    final finalModel = '$brand $modelVal';

                                    if (plate.isEmpty || finalModel.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter plate and model.')));
                                      return;
                                    }

                                    final fuelCap = double.tryParse(fuelCapController.text.trim()) ?? 40.0;
                                    final tyrePres = double.tryParse(tyreController.text.trim()) ?? 32.0;
                                    final oilCap = double.tryParse(oilCapController.text.trim()) ?? 4.0;

                                    await VehicleInsights.instance.addVehicle({
                                      'model': finalModel,
                                      'plate': plate,
                                      'fuelType': 'Petrol',
                                      'currentMileageKm': mileage,
                                      'engine': engineController.text.trim(),
                                      'transmission': transController.text.trim(),
                                      'fuelCapacityLiters': fuelCap,
                                      'recommendedTyrePressurePsi': tyrePres,
                                      'engineOilCapacityLiters': oilCap,
                                    });

                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: const Text('Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          },
        );
      },
    );
  }

  void _showEditVehicleDialog() {
    final insights = VehicleInsights.instance;
    final plateController = TextEditingController(text: insights.plate);
    final mileageController = TextEditingController(
      text: insights.currentMileageKm.toStringAsFixed(0),
    );
    final fuelTypeController = TextEditingController(text: insights.fuelType);

    String? selectedBrand;
    String? selectedModel;
    String? selectedGen;
    String? selectedVariant;

    final customBrandController = TextEditingController();
    final customModelController = TextEditingController();
    final customGenController = TextEditingController();
    final customVariantController = TextEditingController();

    final engineController = TextEditingController(text: insights.engine);
    final transController = TextEditingController(text: insights.transmission);
    final fuelCapController = TextEditingController(text: insights.fuelCapacityLiters.toStringAsFixed(0));
    final tyreController = TextEditingController(text: insights.recommendedTyrePressurePsi.toStringAsFixed(0));
    final oilCapController = TextEditingController(text: insights.engineOilCapacityLiters.toStringAsFixed(1));

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasSeededBrand = selectedBrand != null && CarDatabase.brandModels.containsKey(selectedBrand);
            final modelList = hasSeededBrand ? CarDatabase.brandModels[selectedBrand!]! : <CarModelData>[];

            CarModelData? modelData;
            if (selectedModel != null && selectedModel != 'Custom / Other') {
              try {
                modelData = modelList.firstWhere((m) => m.name == selectedModel);
              } catch (_) {
                modelData = null;
              }
            }
            final genList = modelData != null ? modelData.generations : <CarGeneration>[];

            CarGeneration? genData;
            if (selectedGen != null && selectedGen != 'Custom / Other') {
              try {
                genData = genList.firstWhere((g) => g.name == selectedGen);
              } catch (_) {
                genData = null;
              }
            }
            final variantList = genData != null ? genData.variants : <CarVariant>[];

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Vehicle Details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: isDark ? Colors.white : const Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 20),

                        TextField(
                          controller: plateController,
                          decoration: const InputDecoration(labelText: 'License Plate', prefixIcon: Icon(Icons.pin_outlined)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: mileageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Current Mileage (km)', prefixIcon: Icon(Icons.speed_outlined)),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: selectedBrand,
                          hint: const Text('Select Brand to Reset Model'),
                          items: CarDatabase.brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedBrand = val;
                              selectedModel = null;
                              selectedGen = null;
                              selectedVariant = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        if (selectedBrand != null) ...[
                          DropdownButtonFormField<String>(
                            value: selectedModel,
                            hint: const Text('Select Model'),
                            items: [
                              ...modelList.map((m) => DropdownMenuItem(value: m.name, child: Text(m.name))),
                              const DropdownMenuItem(value: 'Custom / Other', child: Text('Custom / Other')),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                selectedModel = val;
                                selectedGen = null;
                                selectedVariant = null;
                                if (val != 'Custom / Other') {
                                  customModelController.text = val!;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        TextField(controller: engineController, decoration: const InputDecoration(labelText: 'Engine Spec')),
                        const SizedBox(height: 12),
                        TextField(controller: transController, decoration: const InputDecoration(labelText: 'Transmission Spec')),
                        const SizedBox(height: 12),
                        TextField(controller: fuelCapController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fuel Tank Cap (Liters)')),
                        const SizedBox(height: 12),
                        TextField(controller: tyreController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Recommended Tyre Press (PSI)')),
                        const SizedBox(height: 12),
                        TextField(controller: oilCapController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Engine Oil Cap (Liters)')),

                        const SizedBox(height: 24),
                        Row(
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [primaryColor, primaryColor.withBlue(100)]),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                  onPressed: () async {
                                    final plate = plateController.text.trim();
                                    final mileage = double.tryParse(mileageController.text.trim()) ?? 0.0;
                                    final brand = selectedBrand ?? insights.model.split(' ').first;
                                    final modelVal = selectedModel == 'Custom / Other' ? customModelController.text.trim() : (selectedModel ?? insights.model.substring(insights.model.indexOf(' ') + 1));
                                    final finalModel = '$brand $modelVal';

                                    if (plate.isEmpty || finalModel.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out plate and model.')));
                                      return;
                                    }

                                    final fuelCap = double.tryParse(fuelCapController.text.trim()) ?? insights.fuelCapacityLiters;
                                    final tyrePres = double.tryParse(tyreController.text.trim()) ?? insights.recommendedTyrePressurePsi;
                                    final oilCap = double.tryParse(oilCapController.text.trim()) ?? insights.engineOilCapacityLiters;

                                    await VehicleInsights.instance.updateVehicle(
                                      model: finalModel,
                                      plate: plate,
                                      fuelType: 'Petrol',
                                      currentMileageKm: mileage,
                                      engine: engineController.text.trim(),
                                      transmission: transController.text.trim(),
                                      fuelCapacityLiters: fuelCap,
                                      recommendedTyrePressurePsi: tyrePres,
                                      engineOilCapacityLiters: oilCap,
                                    );

                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: const Text('Save Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          },
        );
      },
    );
  }
}
