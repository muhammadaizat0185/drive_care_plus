class CarSpecification {
  final String engine;
  final String transmission;
  final double fuelCapacityLiters;
  final double recommendedTyrePressurePsi;
  final double engineOilCapacityLiters;

  const CarSpecification({
    required this.engine,
    required this.transmission,
    required this.fuelCapacityLiters,
    required this.recommendedTyrePressurePsi,
    required this.engineOilCapacityLiters,
  });
}

class CarVariant {
  final String name;
  final CarSpecification specification;

  const CarVariant({
    required this.name,
    required this.specification,
  });
}

class CarGeneration {
  final String name;
  final List<CarVariant> variants;

  const CarGeneration({
    required this.name,
    required this.variants,
  });
}

class CarModelData {
  final String name;
  final List<CarGeneration> generations;

  const CarModelData({
    required this.name,
    required this.generations,
  });
}

class CarDatabase {
  // Brand list for dropdown selection
  static const List<String> brands = [
    'Perodua',
    'Proton',
    'Toyota',
    'Honda',
    'Nissan',
    'Mazda',
    'BMW',
    'Mercedes-Benz',
    'BYD',
    'Chery',
  ];

  // Detailed hierarchical tree for top Malaysian vehicles
  static const Map<String, List<CarModelData>> brandModels = {
    'Perodua': [
      CarModelData(
        name: 'Myvi',
        generations: [
          CarGeneration(
            name: '3rd Gen (2017-Present)',
            variants: [
              CarVariant(
                name: '1.5 AV (D-CVT)',
                specification: CarSpecification(
                  engine: '1.5L Dual VVT-i (2NR-VE)',
                  transmission: 'D-CVT',
                  fuelCapacityLiters: 36.0,
                  recommendedTyrePressurePsi: 32.0,
                  engineOilCapacityLiters: 3.5,
                ),
              ),
              CarVariant(
                name: '1.5 H (D-CVT)',
                specification: CarSpecification(
                  engine: '1.5L Dual VVT-i (2NR-VE)',
                  transmission: 'D-CVT',
                  fuelCapacityLiters: 36.0,
                  recommendedTyrePressurePsi: 32.0,
                  engineOilCapacityLiters: 3.5,
                ),
              ),
              CarVariant(
                name: '1.3 G (D-CVT)',
                specification: CarSpecification(
                  engine: '1.3L Dual VVT-i (1NR-VE)',
                  transmission: 'D-CVT',
                  fuelCapacityLiters: 36.0,
                  recommendedTyrePressurePsi: 32.0,
                  engineOilCapacityLiters: 3.3,
                ),
              ),
            ],
          ),
          CarGeneration(
            name: '2nd Gen (2011-2017)',
            variants: [
              CarVariant(
                name: '1.5 Extreme (4AT)',
                specification: CarSpecification(
                  engine: '1.5L DOHC VVT-i (3SZ-VE)',
                  transmission: '4AT',
                  fuelCapacityLiters: 40.0,
                  recommendedTyrePressurePsi: 29.0,
                  engineOilCapacityLiters: 3.5,
                ),
              ),
              CarVariant(
                name: '1.3 SE (4AT)',
                specification: CarSpecification(
                  engine: '1.3L DOHC VVT-i (K3-VE)',
                  transmission: '4AT',
                  fuelCapacityLiters: 40.0,
                  recommendedTyrePressurePsi: 29.0,
                  engineOilCapacityLiters: 3.3,
                ),
              ),
            ],
          ),
        ],
      ),
      CarModelData(
        name: 'Bezza',
        generations: [
          CarGeneration(
            name: '1st Gen (2016-Present)',
            variants: [
              CarVariant(
                name: '1.3 AV (4AT)',
                specification: CarSpecification(
                  engine: '1.3L Dual VVT-i (1NR-VE)',
                  transmission: '4-Speed Automatic',
                  fuelCapacityLiters: 36.0,
                  recommendedTyrePressurePsi: 36.0,
                  engineOilCapacityLiters: 3.3,
                ),
              ),
              CarVariant(
                name: '1.0 G (5MT)',
                specification: CarSpecification(
                  engine: '1.0L VVT-i (1KR-VE)',
                  transmission: '5-Speed Manual',
                  fuelCapacityLiters: 36.0,
                  recommendedTyrePressurePsi: 36.0,
                  engineOilCapacityLiters: 3.0,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    'Proton': [
      CarModelData(
        name: 'Saga',
        generations: [
          CarGeneration(
            name: '3rd Gen (2016-Present)',
            variants: [
              CarVariant(
                name: '1.3 Premium (4AT)',
                specification: CarSpecification(
                  engine: '1.3L 4-Cylinder VVT',
                  transmission: '4-Speed Automatic',
                  fuelCapacityLiters: 40.0,
                  recommendedTyrePressurePsi: 32.0,
                  engineOilCapacityLiters: 3.0,
                ),
              ),
              CarVariant(
                name: '1.3 Standard (5MT)',
                specification: CarSpecification(
                  engine: '1.3L 4-Cylinder VVT',
                  transmission: '5-Speed Manual',
                  fuelCapacityLiters: 40.0,
                  recommendedTyrePressurePsi: 32.0,
                  engineOilCapacityLiters: 3.0,
                ),
              ),
            ],
          ),
        ],
      ),
      CarModelData(
        name: 'X50',
        generations: [
          CarGeneration(
            name: '1st Gen (2020-Present)',
            variants: [
              CarVariant(
                name: '1.5 TGDi Flagship (7DCT)',
                specification: CarSpecification(
                  engine: '1.5L Direct Injection Turbo 3-cyl',
                  transmission: '7-Speed Dual Clutch (DCT)',
                  fuelCapacityLiters: 45.0,
                  recommendedTyrePressurePsi: 33.0,
                  engineOilCapacityLiters: 5.2,
                ),
              ),
              CarVariant(
                name: '1.5 T Premium (7DCT)',
                specification: CarSpecification(
                  engine: '1.5L Port Injection Turbo 3-cyl',
                  transmission: '7-Speed Dual Clutch (DCT)',
                  fuelCapacityLiters: 45.0,
                  recommendedTyrePressurePsi: 33.0,
                  engineOilCapacityLiters: 5.2,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    'Toyota': [
      CarModelData(
        name: 'Vios',
        generations: [
          CarGeneration(
            name: '4th Gen AC100 (2023-Present)',
            variants: [
              CarVariant(
                name: '1.5 G (D-CVT)',
                specification: CarSpecification(
                  engine: '1.5L Dual VVT-i (2NR-VE)',
                  transmission: 'D-CVT',
                  fuelCapacityLiters: 40.0,
                  recommendedTyrePressurePsi: 33.0,
                  engineOilCapacityLiters: 3.5,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    'Honda': [
      CarModelData(
        name: 'City',
        generations: [
          CarGeneration(
            name: '5th Gen GN (2020-Present)',
            variants: [
              CarVariant(
                name: '1.5 RS e:HEV Hybrid',
                specification: CarSpecification(
                  engine: '1.5L i-VTEC Atkinson Cycle Hybrid',
                  transmission: 'e-CVT',
                  fuelCapacityLiters: 40.0,
                  recommendedTyrePressurePsi: 33.0,
                  engineOilCapacityLiters: 3.6,
                ),
              ),
              CarVariant(
                name: '1.5 V (CVT)',
                specification: CarSpecification(
                  engine: '1.5L DOHC i-VTEC',
                  transmission: 'CVT',
                  fuelCapacityLiters: 40.0,
                  recommendedTyrePressurePsi: 32.0,
                  engineOilCapacityLiters: 3.6,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  };

  // Full flat fallback list of models for other brands or basic lookup
  static const List<String> fallbackCars = [
    'Perodua Axia', 'Perodua Bezza', 'Perodua Myvi', 'Perodua Alza', 'Perodua Ativa', 'Perodua Aruz', 'Perodua Viva',
    'Proton Saga', 'Proton S70', 'Proton X50', 'Proton X70', 'Proton X90', 'Proton Persona', 'Proton Iriz', 'Proton Exora',
    'Toyota Vios', 'Toyota Yaris', 'Toyota Veloz', 'Toyota Avanza', 'Toyota Hilux', 'Toyota Corolla Cross', 'Toyota Camry',
    'Honda City', 'Honda City Hatchback', 'Honda Civic', 'Honda Civic Type R', 'Honda HR-V', 'Honda CR-V', 'Honda WR-V',
    'Nissan Almera', 'Nissan Serena S-Hybrid', 'Nissan X-Trail', 'Nissan Navara',
    'Mazda 2', 'Mazda 3', 'Mazda CX-3', 'Mazda CX-5', 'Mazda CX-30',
    'BMW 3 Series', 'BMW 5 Series', 'BMW X1', 'BMW X3', 'BMW X5',
    'Mercedes-Benz C-Class', 'Mercedes-Benz E-Class', 'Mercedes-Benz GLA', 'Mercedes-Benz GLC',
    'BYD Dolphin', 'BYD Atto 3', 'BYD Seal',
    'Chery Omoda 5', 'Chery Tiggo 7 Pro', 'Chery Tiggo 8 Pro'
  ];
}
