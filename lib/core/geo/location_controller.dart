import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/profile/data/profile_repository.dart';
import '../errors/app_exception.dart';
import '../localization/area_controller.dart';
import '../persistence/kv_store.dart';
import 'bahrain_areas.dart';
import 'geocoding_resolver.dart';

const _promptedKey = 'settings.location_prompted_v1';
const _latKey = 'settings.last_lat';
const _lngKey = 'settings.last_lng';

class LocationController {
  final Ref _ref;

  const LocationController(this._ref);

  Future<bool> shouldPrompt() async {
    final prompted = await _ref.read(kvStoreProvider).read(_promptedKey);
    if (prompted == '1') return false;
    final profile = await _ref.read(myProfileProvider.future);
    if (profile?.lat != null && profile?.lng != null) return false;
    return true;
  }

  Future<void> markPrompted() async {
    await _ref.read(kvStoreProvider).write(_promptedKey, '1');
  }

  Future<void> requestAndSave() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw const AppException('Location services are disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw const AppException('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final lat = position.latitude;
      final lng = position.longitude;

      await _ref.read(kvStoreProvider).write(_latKey, lat.toString());
      await _ref.read(kvStoreProvider).write(_lngKey, lng.toString());
      String? area;
      String? location;

      try {
        final resolved = await reverseGeocode(lat, lng);
        final country = (resolved?.country ?? '').trim();
        final resolvedArea = (resolved?.area ?? '').trim();
        area = resolvedArea.isEmpty ? null : resolvedArea;
        final parts = <String>[
          if (area != null) area,
          if (country.isNotEmpty) country,
        ];
        location = parts.isEmpty ? null : parts.join(', ');
      } catch (_) {}

      area ??= _ref.read(areaControllerProvider);
      location ??= '$area, Bahrain';

      try {
        await _ref.read(profileRepositoryProvider).upsertMyProfile(
              lat: lat,
              lng: lng,
              area: area,
              location: location,
            );
      } catch (_) {}
      final resolvedArea = (area ?? _ref.read(areaControllerProvider) ?? '').trim();
      if (resolvedArea.isNotEmpty) {
        await _ref.read(areaControllerProvider.notifier).setArea(resolvedArea);
      }
      _ref.invalidate(myProfileProvider);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to get location', cause: e);
    }
  }

  Future<void> saveAreaFallback(String area) async {
    final a = bahrainAreaByName(area);
    if (a == null) return;
    await saveManualLatLng(lat: a.lat, lng: a.lng);
  }

  Future<void> saveManualLatLng({required double lat, required double lng}) async {
    await _ref.read(kvStoreProvider).write(_latKey, lat.toString());
    await _ref.read(kvStoreProvider).write(_lngKey, lng.toString());
  }
}

final locationControllerProvider = Provider<LocationController>((ref) {
  return LocationController(ref);
});

final effectiveLatLngProvider = FutureProvider<({double lat, double lng})?>((ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  final lat = profile?.lat;
  final lng = profile?.lng;
  if (lat != null && lng != null) return (lat: lat, lng: lng);

  final kv = ref.read(kvStoreProvider);
  final latRaw = await kv.read(_latKey);
  final lngRaw = await kv.read(_lngKey);
  final latKv = double.tryParse((latRaw ?? '').trim());
  final lngKv = double.tryParse((lngRaw ?? '').trim());
  if (latKv != null && lngKv != null) return (lat: latKv, lng: lngKv);

  final area = ((profile?.area ?? '').trim().isNotEmpty ? (profile?.area ?? '') : ref.read(areaControllerProvider)).trim();
  final a = bahrainAreaByName(area);
  if (a == null) return null;
  return (lat: a.lat, lng: a.lng);
});
