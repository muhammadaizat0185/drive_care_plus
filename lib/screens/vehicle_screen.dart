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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Vehicle Profile')),
      body: ListenableBuilder(
        listenable: VehicleInsights.instance,
        builder: (context, child) {
          final insights = VehicleInsights.instance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
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
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

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

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
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
                        Text(
                          'Edit Vehicle Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 1. License Plate & Mileage
                        TextField(
                          controller: plateController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'License Plate',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            prefixIcon: const Icon(Icons.pin_outlined, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: mileageController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Current Mileage (km)',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            prefixIcon: const Icon(Icons.speed_outlined, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: fuelTypeController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Fuel Type',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            prefixIcon: const Icon(Icons.local_gas_station_outlined, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Select Local Catalog (CarBase)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.grey),
                        ),
                        const SizedBox(height: 12),

                        // 2. Brand Dropdown
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Car Brand',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedBrand,
                              hint: const Text('Select Brand'),
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
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
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Enter Custom Brand',
                              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],

                        // 3. Model Dropdown
                        if (selectedBrand != null && selectedBrand != 'Custom / Other') ...[
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Model',
                              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedModel,
                                hint: const Text('Select Model'),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
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
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Enter Custom Model',
                              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],

                        // 4. Generation Dropdown
                        if (selectedModel != null && selectedModel != 'Custom / Other' && genList.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Generation',
                              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedGen,
                                hint: const Text('Select Generation'),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
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
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Enter Custom Generation',
                              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],

                        // 5. Variant Dropdown
                        if (selectedGen != null && selectedGen != 'Custom / Other' && variantList.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Variant',
                              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedVariant,
                                hint: const Text('Select Variant'),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                isExpanded: true,
                                items: [
                                  ...variantList.map((v) => DropdownMenuItem(value: v.name, child: Text(v.name))),
                                  const DropdownMenuItem(value: 'Custom / Other', child: Text('Custom / Other')),
                                ],
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedVariant = val;
                                    if (val != 'Custom / Other' && val != null) {
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
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Enter Custom Variant',
                              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Specs Autofill & Custom Tuning',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.grey),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: engineController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Engine Specs',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: transController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Transmission Specs',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: fuelCapController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Fuel Capacity (Liters)',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: tyreController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Tyre Pressure (PSI)',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: oilCapController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Engine Oil Capacity (Liters)',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
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
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? Colors.white60 : Colors.black54,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryColor, primaryColor.withBlue(120)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.3),
                                      blurRadius: 10,
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
                                  onPressed: () async {
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
                                  child: const Text(
                                    'Save',
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
          },
        );
      },
    );
  }
}
