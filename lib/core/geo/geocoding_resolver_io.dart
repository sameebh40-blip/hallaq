import 'package:geocoding/geocoding.dart';

Future<({String? area, String? country})?> reverseGeocode(double lat, double lng) async {
  final placemarks = await placemarkFromCoordinates(lat, lng);
  final p = placemarks.isNotEmpty ? placemarks.first : null;
  final locality = (p?.locality ?? '').trim();
  final adminArea = (p?.administrativeArea ?? '').trim();
  final country = (p?.country ?? '').trim();

  final rawArea = locality.isNotEmpty ? locality : adminArea;
  final area = rawArea.isNotEmpty ? rawArea : null;
  final c = country.isNotEmpty ? country : null;
  return (area: area, country: c);
}

