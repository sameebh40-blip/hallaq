import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shop/data/shop_repository.dart';
import '../geo/geo_distance.dart';
import 'location_controller.dart';

final distanceToShopKmProvider = FutureProvider.family<double?, String>((ref, shopId) async {
  final loc = await ref.watch(effectiveLatLngProvider.future);
  if (loc == null) return null;
  final lat = loc.lat;
  final lng = loc.lng;

  final shop = await ref.watch(shopRepositoryProvider).getById(shopId);
  final toLat = shop.lat;
  final toLng = shop.lng;
  if (toLat == null || toLng == null) return null;

  return haversineKm(fromLat: lat, fromLng: lng, toLat: toLat, toLng: toLng);
});
