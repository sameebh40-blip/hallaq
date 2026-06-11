import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../barber/data/barber_schedule_repository.dart';

final _workingHoursProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, barberId) async {
  return ref.watch(barberScheduleRepositoryProvider).listWorkingHours(barberId);
});

final _timeOffProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, barberId) async {
  return ref.watch(barberScheduleRepositoryProvider).listTimeOff(barberId);
});

class ShopManageBarberAvailabilityScreen extends ConsumerWidget {
  final String barberId;
  final String? title;

  const ShopManageBarberAvailabilityScreen({super.key, required this.barberId, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final working = ref.watch(_workingHoursProvider(barberId));
    final timeOff = ref.watch(_timeOffProvider(barberId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title?.trim().isNotEmpty == true ? title!.trim() : 'Availability')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Working hours', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          AsyncValueWidget<List<Map<String, dynamic>>>(
            value: working,
            onRetry: () => ref.invalidate(_workingHoursProvider(barberId)),
            data: (rows) => Column(
              children: List.generate(7, (weekday) {
                final dayRows = rows.where((r) => (r['weekday'] as num).toInt() == weekday).toList();
                final enabled = dayRows.isNotEmpty ? (dayRows.first['enabled'] as bool? ?? true) : false;
                final start = dayRows.isNotEmpty ? (dayRows.first['start_time'] as String? ?? '10:00:00') : '10:00:00';
                final end = dayRows.isNotEmpty ? (dayRows.first['end_time'] as String? ?? '22:00:00') : '22:00:00';
                return _WorkingHoursRow(barberId: barberId, weekday: weekday, enabled: enabled, start: start, end: end);
              }),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('Time off', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              IconButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
                    lastDate: DateTime(now.year + 1),
                    initialDate: now,
                  );
                  if (date == null || !context.mounted) return;
                  final startTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
                  if (startTime == null || !context.mounted) return;
                  final endTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
                  if (endTime == null) return;
                  final startsAt = DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute);
                  final endsAt = DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);
                  await ref.read(barberScheduleRepositoryProvider).addTimeOff(barberId: barberId, startsAt: startsAt, endsAt: endsAt);
                  ref.invalidate(_timeOffProvider(barberId));
                },
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AsyncValueWidget<List<Map<String, dynamic>>>(
            value: timeOff,
            onRetry: () => ref.invalidate(_timeOffProvider(barberId)),
            data: (rows) {
              if (rows.isEmpty) return const HallaqCard(glass: true, child: Text('No time off.'));
              return Column(
                children: rows.map((r) => _TimeOffCard(barberId: barberId, row: r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkingHoursRow extends ConsumerStatefulWidget {
  final String barberId;
  final int weekday;
  final bool enabled;
  final String start;
  final String end;

  const _WorkingHoursRow({
    required this.barberId,
    required this.weekday,
    required this.enabled,
    required this.start,
    required this.end,
  });

  @override
  ConsumerState<_WorkingHoursRow> createState() => _WorkingHoursRowState();
}

class _WorkingHoursRowState extends ConsumerState<_WorkingHoursRow> {
  late bool _enabled = widget.enabled;
  late String _start = widget.start;
  late String _end = widget.end;
  var _busy = false;

  String _weekdayLabel(int w) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return names[w.clamp(0, 6)];
  }

  TimeOfDay _parse(String s, TimeOfDay fallback) {
    final v = s.trim();
    final parts = v.split(':');
    if (parts.length < 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }

  String _format(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _persist() async {
    setState(() => _busy = true);
    try {
      await ref.read(barberScheduleRepositoryProvider).upsertWorkingHour(
            barberId: widget.barberId,
            weekday: widget.weekday,
            startTime: _start,
            endTime: _end,
            enabled: _enabled,
          );
      ref.invalidate(_workingHoursProvider(widget.barberId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startLabel = _start.substring(0, 5);
    final endLabel = _end.substring(0, 5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(width: 42, child: Text(_weekdayLabel(widget.weekday), style: Theme.of(context).textTheme.bodyMedium)),
            Switch(
              value: _enabled,
              onChanged: _busy
                  ? null
                  : (v) async {
                      setState(() => _enabled = v);
                      await _persist();
                    },
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _parse(_start, const TimeOfDay(hour: 10, minute: 0)),
                              );
                              if (picked == null) return;
                              setState(() => _start = _format(picked));
                              await _persist();
                            },
                      child: Text(startLabel),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('—', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _parse(_end, const TimeOfDay(hour: 22, minute: 0)),
                              );
                              if (picked == null) return;
                              setState(() => _end = _format(picked));
                              await _persist();
                            },
                      child: Text(endLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeOffCard extends ConsumerWidget {
  final String barberId;
  final Map<String, dynamic> row;

  const _TimeOffCard({required this.barberId, required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (row['id'] as String?) ?? '';
    final startsAt = DateTime.tryParse(row['starts_at'] as String? ?? '')?.toLocal();
    final endsAt = DateTime.tryParse(row['ends_at'] as String? ?? '')?.toLocal();
    final label = (startsAt == null || endsAt == null)
        ? '—'
        : '${DateFormat('MMM d, HH:mm').format(startsAt)} → ${DateFormat('MMM d, HH:mm').format(endsAt)}';
    final reason = (row['reason'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                  if (reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(reason, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: id.isEmpty
                  ? null
                  : () async {
                      await ref.read(barberScheduleRepositoryProvider).deleteTimeOff(id);
                      ref.invalidate(_timeOffProvider(barberId));
                    },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

