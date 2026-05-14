import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/car_database.dart';
import '../services/vehicle_insights.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  static const routeName = '/vehicle';

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _carouselScrollController = ScrollController();

  @override
  void dispose() {
    _carouselScrollController.dispose();
    super.dispose();
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F172A), // Deep Slate Dark
                  const Color(0xFF022C22), // Deep Obsidian Dark Green
                ]
              : [
                  const Color(0xFFEFFDF5), // Soft pastel mint
                  const Color(0xFFF9FAFB), // Soft premium grey
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
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
                // Horizontal Vehicles Carousel Section
                _buildVehiclesCarousel(context, insights),
                const SizedBox(height: 16),
  
                // Glowing Component Health Dashboard Gauge Card
                _buildComponentHealthDashboard(context, insights),
                const SizedBox(height: 16),
  
                // Primary Active Vehicle Details Specifications Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                            IconButton.filledTonal(
                              onPressed: _showEditVehicleDialog,
                              icon: const Icon(Icons.edit_note, size: 20),
                              tooltip: 'Edit Specifications',
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
                ),
                const SizedBox(height: 16),
  
                // Original Predictive Maintenance List (Watchlist)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle Health Watchlist',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Predictive maintenance alerts based on your current mileage.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        ...insights.watchlistItems.map((item) {
                          Color statusColor;
                          IconData statusIcon;
                          if (item.status == 'Red') {
                            statusColor = Colors.red;
                            statusIcon = Icons.warning_amber_rounded;
                          } else if (item.status == 'Yellow') {
                            statusColor = Colors.orange;
                            statusIcon = Icons.info_outline_rounded;
                          } else {
                            statusColor = Colors.green;
                            statusIcon = Icons.check_circle_outline_rounded;
                          }
  
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.12),
                              child: Icon(statusIcon, color: statusColor, size: 20),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Due in ${item.remainingKm.toStringAsFixed(0)} km\n(at ${item.nextChangeMileage.toStringAsFixed(0)} km)'),
                            isThreeLine: true,
                          );
                        }),
                      ],
                    ),
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
          height: 100,
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
                      width: 150,
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
                          Icon(Icons.add_circle_outline, color: Colors.grey, size: 28),
                          SizedBox(height: 6),
                          Text(
                            'Add Vehicle',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
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
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? primaryColor.withOpacity(0.1)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? primaryColor : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  color: isActive ? primaryColor : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    vehicle['model'] ?? 'Perodua Axia',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: isActive ? primaryColor : (isDark ? Colors.white : Colors.black87),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vehicle['plate'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive ? primaryColor.withOpacity(0.8) : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${((vehicle['currentMileageKm'] ?? 0) as num).toStringAsFixed(0)} km',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        if (insights.vehicles.length > 1)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 16),
                              onPressed: () {
                                _confirmDeleteVehicle(context, insights, index);
                              },
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

    final engineVal = _getEngineHealth(insights);
    final brakesVal = _getBrakesHealth(insights);
    final tiresVal = _getTiresHealth(insights);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Real-Time Vehicle Component Health',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _circularGauge('Engine Oil', engineVal, const Color(0xFF10B981), primaryColor),
                _circularGauge('Brakes', brakesVal, Colors.orange, primaryColor),
                _circularGauge('Tires', tiresVal, Colors.blue, primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
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
