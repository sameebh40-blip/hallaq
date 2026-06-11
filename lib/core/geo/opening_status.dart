class OpeningStatus {
  final bool isOpen;
  final String primaryLabel;
  final String secondaryLabel;

  const OpeningStatus({
    required this.isOpen,
    required this.primaryLabel,
    required this.secondaryLabel,
  });
}

OpeningStatus openingStatusFromHours(Map<String, dynamic>? openingHours, DateTime now) {
  final hours = openingHours ?? const <String, dynamic>{};
  final todayKey = _weekdayKey(now.weekday);
  final todayRaw = (hours[todayKey] ?? '').toString();
  final today = _parseRange(todayRaw, now);

  if (today != null) {
    if (_isBetween(now, today.start, today.end)) {
      return OpeningStatus(isOpen: true, primaryLabel: 'Open Now', secondaryLabel: 'Closes ${_formatTime(today.end)}');
    }
    if (now.isBefore(today.start)) {
      return OpeningStatus(isOpen: false, primaryLabel: 'Closed', secondaryLabel: 'Opens ${_formatTime(today.start)}');
    }
  }

  for (var i = 0; i < 7; i++) {
    final date = now.add(Duration(days: i));
    final key = _weekdayKey(date.weekday);
    final raw = (hours[key] ?? '').toString();
    final range = _parseRange(raw, date);
    if (range == null) continue;
    if (i == 0 && !now.isBefore(range.start)) continue;
    return OpeningStatus(isOpen: false, primaryLabel: 'Closed', secondaryLabel: 'Opens ${_formatTime(range.start)}');
  }

  return const OpeningStatus(isOpen: false, primaryLabel: 'Closed', secondaryLabel: 'No hours');
}

String _weekdayKey(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'mon',
    DateTime.tuesday => 'tue',
    DateTime.wednesday => 'wed',
    DateTime.thursday => 'thu',
    DateTime.friday => 'fri',
    DateTime.saturday => 'sat',
    _ => 'sun',
  };
}

bool _isBetween(DateTime now, DateTime start, DateTime end) {
  return (now.isAfter(start) || now.isAtSameMomentAs(start)) && now.isBefore(end);
}

({DateTime start, DateTime end})? _parseRange(String raw, DateTime day) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  final parts = v.split('-').map((e) => e.trim()).toList();
  if (parts.length != 2) return null;
  final start = _parseTime(parts[0], day);
  final end = _parseTime(parts[1], day);
  if (start == null || end == null) return null;
  if (!end.isAfter(start)) {
    return (start: start, end: end.add(const Duration(days: 1)));
  }
  return (start: start, end: end);
}

DateTime? _parseTime(String raw, DateTime day) {
  final parts = raw.split(':').map((e) => e.trim()).toList();
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

String _formatTime(DateTime time) {
  var hour = time.hour;
  final minute = time.minute;
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  if (minute == 0) return '$hour $ampm';
  return '$hour:${minute.toString().padLeft(2, '0')} $ampm';
}
