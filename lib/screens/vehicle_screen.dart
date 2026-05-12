import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/car_database.dart';
import '../services/vehicle_insights.dart';
import '../widgets/cloud_sync_quota_card.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  static const routeName = '/vehicle';

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Profile')),
      body: ListenableBuilder(
        listenable: VehicleInsights.instance,
        builder: (context, child) {
          final insights = VehicleInsights.instance;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Primary Vehicle',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.directions_car_outlined),
                        title: const Text('Model'),
                        subtitle: Text(insights.model),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.pin_outlined),
                        title: const Text('Plate number'),
                        subtitle: Text(insights.plate),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.speed_outlined),
                        title: const Text('Current mileage'),
                        subtitle: Text('${insights.currentMileageKm.toStringAsFixed(0)} km'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.local_gas_station_outlined),
                        title: const Text('Fuel type'),
                        subtitle: Text(insights.fuelType),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(),
                      ),
                      Text(
                        'Manufacturer Specifications',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.settings_suggest_outlined),
                        title: const Text('Engine'),
                        subtitle: Text(insights.engine),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.settings_input_component_outlined),
                        title: const Text('Transmission'),
                        subtitle: Text(insights.transmission),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.local_gas_station),
                        title: const Text('Fuel Tank Capacity'),
                        subtitle: Text('${insights.fuelCapacityLiters.toStringAsFixed(0)} Liters'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tire_repair_outlined),
                        title: const Text('Recommended Tyre Pressure'),
                        subtitle: Text('${insights.recommendedTyrePressurePsi.toStringAsFixed(0)} PSI'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.opacity_outlined),
                        title: const Text('Engine Oil Capacity'),
                        subtitle: Text('${insights.engineOilCapacityLiters.toStringAsFixed(1)} Liters'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showEditVehicleDialog,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Vehicle & Specs'),
              ),
              const SizedBox(height: 16),
              const CloudSyncQuotaCard(),
            ],
          );
        },
      ),
    );
  }

  void _showEditVehicleDialog() {
    final insights = VehicleInsights.instance;
    final plateController = TextEditingController(text: insights.plate);
    final mileageController = TextEditingController(
      text: insights.currentMileageKm.toStringAsFixed(0),
    );
    final fuelTypeController = TextEditingController(text: insights.fuelType);

    // Brand and model selection states
    String? selectedBrand;
    String? selectedModel;
    String? selectedGen;
    String? selectedVariant;

    // Custom input controllers
    final customBrandController = TextEditingController();
    final customModelController = TextEditingController();
    final customGenController = TextEditingController();
    final customVariantController = TextEditingController();

    // Specification controllers
    final engineController = TextEditingController(text: insights.engine);
    final transController = TextEditingController(text: insights.transmission);
    final fuelCapController = TextEditingController(text: insights.fuelCapacityLiters.toStringAsFixed(0));
    final tyreController = TextEditingController(text: insights.recommendedTyrePressurePsi.toStringAsFixed(0));
    final oilCapController = TextEditingController(text: insights.engineOilCapacityLiters.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Get models for selected brand
            final hasSeededBrand = selectedBrand != null && CarDatabase.brandModels.containsKey(selectedBrand);
            final modelList = hasSeededBrand ? CarDatabase.brandModels[selectedBrand!]! : <CarModelData>[];

            // Get generations for selected model
            CarModelData? modelData;
            if (selectedModel != null && selectedModel != 'Custom / Other') {
              try {
                modelData = modelList.firstWhere((m) => m.name == selectedModel);
              } catch (_) {
                modelData = null;
              }
            }
            final genList = modelData != null ? modelData.generations : <CarGeneration>[];

            // Get variants for selected generation
            CarGeneration? genData;
            if (selectedGen != null && selectedGen != 'Custom / Other') {
              try {
                genData = genList.firstWhere((g) => g.name == selectedGen);
              } catch (_) {
                genData = null;
              }
            }
            final variantList = genData != null ? genData.variants : <CarVariant>[];

            return AlertDialog(
              title: const Text('Edit Vehicle Details'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. License Plate & Mileage (Standard)
                      TextField(
                        controller: plateController,
                        decoration: const InputDecoration(
                          labelText: 'License Plate',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: mileageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Current Mileage (km)',
                          prefixIcon: Icon(Icons.speed_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: fuelTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Type',
                          prefixIcon: Icon(Icons.local_gas_station_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select Local Catalog (CarBase)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Brand Dropdown
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'Car Brand'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedBrand,
                            hint: const Text('Select Brand'),
                            isExpanded: true,
                            items: [
                              ...CarDatabase.brands.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                              const DropdownMenuItem(value: 'Custom / Other', child: Text('Custom / Other')),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                selectedBrand = val;
                                selectedModel = null;
                                selectedGen = null;
                                selectedVariant = null;
                              });
                            },
                          ),
                        ),
                      ),
                      if (selectedBrand == 'Custom / Other') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customBrandController,
                          decoration: const InputDecoration(labelText: 'Enter Custom Brand'),
                        ),
                      ],

                      // 3. Model Dropdown (if Brand selected)
                      if (selectedBrand != null && selectedBrand != 'Custom / Other') ...[
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(labelText: 'Model'),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedModel,
                              hint: const Text('Select Model'),
                              isExpanded: true,
                              items: [
                                ...modelList.map((m) => DropdownMenuItem(value: m.name, child: Text(m.name))),
                                const DropdownMenuItem(value: 'Custom / Other', child: Text('Custom / Other')),
                              ],
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedModel = val;
                                  selectedGen = null;
                                  selectedVariant = null;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                      if (selectedModel == 'Custom / Other' || (selectedBrand == 'Custom / Other' && selectedBrand != null)) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customModelController,
                          decoration: const InputDecoration(labelText: 'Enter Custom Model'),
                        ),
                      ],

                      // 4. Generation Dropdown (if Model selected)
                      if (selectedModel != null && selectedModel != 'Custom / Other' && genList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(labelText: 'Generation'),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedGen,
                              hint: const Text('Select Generation'),
                              isExpanded: true,
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
                          ),
                        ),
                      ],
                      if (selectedGen == 'Custom / Other') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customGenController,
                          decoration: const InputDecoration(labelText: 'Enter Custom Generation'),
                        ),
                      ],

                      // 5. Variant Dropdown (if Generation selected)
                      if (selectedGen != null && selectedGen != 'Custom / Other' && variantList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(labelText: 'Variant'),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedVariant,
                              hint: const Text('Select Variant'),
                              isExpanded: true,
                              items: [
                                ...variantList.map((v) => DropdownMenuItem(value: v.name, child: Text(v.name))),
                                const DropdownMenuItem(value: 'Custom / Other', child: Text('Custom / Other')),
                              ],
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedVariant = val;
                                  if (val != 'Custom / Other' && val != null) {
                                    // AUTOMATICALLY autofill specifications!
                                    final match = variantList.firstWhere((v) => v.name == val);
                                    engineController.text = match.specification.engine;
                                    transController.text = match.specification.transmission;
                                    fuelCapController.text = match.specification.fuelCapacityLiters.toStringAsFixed(0);
                                    tyreController.text = match.specification.recommendedTyrePressurePsi.toStringAsFixed(0);
                                    oilCapController.text = match.specification.engineOilCapacityLiters.toStringAsFixed(1);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                      if (selectedVariant == 'Custom / Other') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customVariantController,
                          decoration: const InputDecoration(labelText: 'Enter Custom Variant'),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Specs Autofill & Custom Tuning',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: engineController,
                        decoration: const InputDecoration(labelText: 'Engine Specs'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: transController,
                        decoration: const InputDecoration(labelText: 'Transmission Specs'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fuelCapController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fuel Capacity (Liters)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tyreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Tyre Pressure (PSI)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: oilCapController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Engine Oil Capacity (Liters)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Compute model name
                    String brandName = (selectedBrand == 'Custom / Other' || selectedBrand == null)
                        ? customBrandController.text.trim()
                        : selectedBrand!;
                    String rawModel = (selectedModel == 'Custom / Other' || selectedModel == null)
                        ? customModelController.text.trim()
                        : selectedModel!;

                    if (brandName.isEmpty) brandName = 'Custom';
                    if (rawModel.isEmpty) rawModel = 'Car';

                    final finalModel = '$brandName $rawModel';
                    final plate = plateController.text.trim();
                    final mileage = double.tryParse(mileageController.text) ?? insights.currentMileageKm;
                    final fuel = fuelTypeController.text.trim();

                    final fuelCap = double.tryParse(fuelCapController.text) ?? insights.fuelCapacityLiters;
                    final tyrePres = double.tryParse(tyreController.text) ?? insights.recommendedTyrePressurePsi;
                    final oilCap = double.tryParse(oilCapController.text) ?? insights.engineOilCapacityLiters;

                    if (finalModel.isEmpty || plate.isEmpty || fuel.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Model, plate and fuel are required.')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);

                    // Update local singleton state, cache to SharedPreferences and notify listeners!
                    await VehicleInsights.instance.updateVehicle(
                      model: finalModel,
                      plate: plate,
                      fuelType: fuel,
                      currentMileageKm: mileage,
                      engine: engineController.text.trim(),
                      transmission: transController.text.trim(),
                      fuelCapacityLiters: fuelCap,
                      recommendedTyrePressurePsi: tyrePres,
                      engineOilCapacityLiters: oilCap,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                    }

                    // Save to Firestore under user/vehicle collection
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('vehicle')
                            .doc('primary')
                            .set({
                          'model': finalModel,
                          'plate': plate,
                          'currentMileageKm': mileage,
                          'fuelType': fuel,
                          'engine': engineController.text.trim(),
                          'transmission': transController.text.trim(),
                          'fuelCapacityLiters': fuelCap,
                          'recommendedTyrePressurePsi': tyrePres,
                          'engineOilCapacityLiters': oilCap,
                          'lastUpdated': FieldValue.serverTimestamp(),
                        });
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Vehicle profile & specs saved to Cloud!')),
                        );
                      } catch (e) {
                        debugPrint('Firestore spec save fallback: $e');
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Saved locally (Offline mode).')),
                        );
                      }
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Saved locally (Offline/Guest mode).')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
