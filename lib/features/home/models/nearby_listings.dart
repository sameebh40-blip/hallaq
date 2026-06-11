import '../../../core/models/barber.dart';
import '../../../core/models/barbershop.dart';

class NearbyShop {
  final Barbershop shop;
  final double distanceKm;
  final double? startingPriceBhd;

  const NearbyShop({
    required this.shop,
    required this.distanceKm,
    required this.startingPriceBhd,
  });

  factory NearbyShop.fromJson(Map<String, dynamic> json) {
    final distanceRaw = (json['distance_km'] as num?)?.toDouble();
    return NearbyShop(
      shop: Barbershop.fromJson(json),
      distanceKm: distanceRaw ?? double.infinity,
      startingPriceBhd: (json['starting_price_bhd'] as num?)?.toDouble(),
    );
  }
}

class NearbyBarber {
  final Barber barber;
  final double distanceKm;
  final double? startingPriceBhd;

  const NearbyBarber({
    required this.barber,
    required this.distanceKm,
    required this.startingPriceBhd,
  });

  factory NearbyBarber.fromJson(Map<String, dynamic> json) {
    final distanceRaw = (json['distance_km'] as num?)?.toDouble();
    return NearbyBarber(
      barber: Barber.fromJson(json),
      distanceKm: distanceRaw ?? double.infinity,
      startingPriceBhd: (json['starting_price_bhd'] as num?)?.toDouble(),
    );
  }
}
