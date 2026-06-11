import 'dart:math' as math;

double haversineKm({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  const r = 6371.0;
  final dLat = _toRad(toLat - fromLat);
  final dLng = _toRad(toLng - fromLng);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(fromLat)) * math.cos(_toRad(toLat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _toRad(double deg) => deg * (math.pi / 180.0);

