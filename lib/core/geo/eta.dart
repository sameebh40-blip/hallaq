int etaMinutesFromKm(double km, {double averageSpeedKmPerHour = 28}) {
  if (km <= 0) return 1;
  final kmPerMinute = averageSpeedKmPerHour / 60.0;
  final minutes = (km / kmPerMinute).round();
  return minutes.clamp(1, 240);
}

String etaLabelFromMinutes(int minutes) {
  if (minutes < 60) return '$minutes min away';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h away';
  return '${h}h ${m}m away';
}
