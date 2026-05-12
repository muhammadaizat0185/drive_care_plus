class VehicleInsights {
  const VehicleInsights._();

  static String model = 'Perodua Axia';
  static String plate = 'ABC 1234';
  static String fuelType = 'Petrol';

  static double currentMileageKm = 38200;
  static double nextServiceMileageKm = 40000;
  static double averageDailyDistanceKm = 50;
  static double recentTripDistanceKm = 24.6;
  static double recentTripFuelCostRm = 5.40;

  static double get kmUntilService {
    final difference = nextServiceMileageKm - currentMileageKm;
    return difference < 0 ? 0 : difference;
  }

  static int get predictedServiceDueDays {
    if (averageDailyDistanceKm <= 0) return 0;
    return (kmUntilService / averageDailyDistanceKm).ceil();
  }

  static double get recentTripCostPerKm {
    if (recentTripDistanceKm <= 0) return 0;
    return recentTripFuelCostRm / recentTripDistanceKm;
  }

  static double kmPerLiter({
    required double distanceKm,
    required double liters,
  }) {
    if (liters <= 0) {
      return 0;
    }
    return distanceKm / liters;
  }

  static double litersPer100Km({
    required double distanceKm,
    required double liters,
  }) {
    if (distanceKm <= 0) {
      return 0;
    }
    return (liters / distanceKm) * 100;
  }

  static double refuelCost({
    required double liters,
    required double pricePerLiter,
  }) {
    return liters * pricePerLiter;
  }
}

