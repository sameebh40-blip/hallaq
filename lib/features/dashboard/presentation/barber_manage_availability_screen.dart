import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../barber/data/barber_schedule_repository.dart';
import '../../../core/supabase/supabase_client_provider.dart';

final _myWorkingHoursProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(barberScheduleRepositoryProvider).listWorkingHours(barber.id);
});

final _myTimeOffProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(barberScheduleRepositoryProvider).listTimeOff(barber.id);
});

final _myBookingsForDayProvider = FutureProvider.family<List<Map<String, dynamic>>, DateTime>((ref, day) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  final startLocal = DateTime(day.year, day.month, day.day);
  final endLocal = startLocal.add(const Duration(days: 1));
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('bookings')
      .select('id, start_at, end_at, status, customer_profile_id, profiles(full_name, avatar_url, avatar_path)')
      .eq('barber_id', barber.id)
      .gte('start_at', startLocal.toUtc().toIso8601String())
      .lt('start_at', endLocal.toUtc().toIso8601String())
      .order('start_at', ascending: true);
  return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
});

class BarberManageAvailabilityScreen extends ConsumerStatefulWidget {
  final bool showBack;

  const BarberManageAvailabilityScreen({super.key, this.showBack = true});

  @override
  ConsumerState<BarberManageAvailabilityScreen> createState() => _BarberManageAvailabilityScreenState();
}

class _BarberManageAvailabilityScreenState extends ConsumerState<BarberManageAvailabilityScreen> {
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final working = ref.watch(_myWorkingHoursProvider);
    final timeOff = ref.watch(_myTimeOffProvider);
    final dayBookings = ref.watch(_myBookingsForDayProvider(_day));

    return LuxuryScaffold(
      header: widget.showBack
          ? LuxuryTopBar(
              leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
              title: Text('Calendar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            )
          : null,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          HallaqCard(
            glass: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Schedule', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                    LuxuryIconButton(
                      icon: Icons.chevron_left_rounded,
                      onPressed: () => setState(() => _day = DateTime(_day.year, _day.month, _day.day).subtract(const Duration(days: 1))),
                    ),
                    LuxuryIconButton(
                      icon: Icons.event_rounded,
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 180)),
                          initialDate: _day,
                        );
                        if (picked == null) return;
                        setState(() => _day = picked);
                      },
                    ),
                    LuxuryIconButton(
                      icon: Icons.chevron_right_rounded,
                      onPressed: () => setState(() => _day = DateTime(_day.year, _day.month, _day.day).add(const Duration(days: 1))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(DateFormat('EEEE, MMM d, yyyy').format(_day), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    if (working.isLoading || timeOff.isLoading || dayBookings.isLoading) {
                      return const Center(child: HallaqLoading());
                    }
                    final err = working.error ?? timeOff.error ?? dayBookings.error;
                    if (err != null) {
                      return Text('Could not load schedule', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted));
                    }
                    final wh = working.valueOrNull ?? const <Map<String, dynamic>>[];
                    final to = timeOff.valueOrNull ?? const <Map<String, dynamic>>[];
                    final bk = dayBookings.valueOrNull ?? const <Map<String, dynamic>>[];
                    final tiles = _buildDayTiles(context, workingHours: wh, timeOff: to, bookings: bk, day: _day);
                    if (tiles.isEmpty) {
                      return Text('No working hours for this day.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted));
                    }
                    return Column(children: tiles);
                  },
                ),
                const SizedBox(height: 12),
                HallaqButton(
                  label: 'Block Time / Add Break',
                  icon: Icons.block_rounded,
                  expanded: true,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AddTimeOffScreen())),
                ),
              ],
            ),
          ),
          Text('Working hours', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          AsyncValueWidget<List<Map<String, dynamic>>>(
            value: working,
            data: (rows) => Column(
              children: List.generate(7, (weekday) {
                final dayRows = rows.where((r) => (r['weekday'] as num).toInt() == weekday).toList();
                final enabled = dayRows.isNotEmpty ? (dayRows.first['enabled'] as bool? ?? true) : false;
                final start = dayRows.isNotEmpty ? (dayRows.first['start_time'] as String? ?? '10:00:00') : '10:00:00';
                final end = dayRows.isNotEmpty ? (dayRows.first['end_time'] as String? ?? '22:00:00') : '22:00:00';
                return _WorkingHourRow(weekday: weekday, enabled: enabled, start: start, end: end);
              }),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('Time off', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              LuxuryIconButton(
                icon: Icons.add_rounded,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AddTimeOffScreen())),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AsyncValueWidget<List<Map<String, dynamic>>>(
            value: timeOff,
            data: (rows) {
              if (rows.isEmpty) return const HallaqCard(glass: true, child: Text('No time off.'));
              return Column(
                children: rows.map((r) => _TimeOffCard(row: r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDayTiles(
    BuildContext context, {
    required List<Map<String, dynamic>> workingHours,
    required List<Map<String, dynamic>> timeOff,
    required List<Map<String, dynamic>> bookings,
    required DateTime day,
  }) {
    final weekday0 = day.weekday % 7;
    final row = workingHours.where((r) => (r['weekday'] as num?)?.toInt() == weekday0).toList(growable: false);
    if (row.isEmpty) return const [];
    final enabled = row.first['enabled'] as bool? ?? true;
    if (!enabled) return const [];

    TimeOfDay? parseTime(String? s) {
      final v = (s ?? '').trim();
      if (v.isEmpty) return null;
      final parts = v.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    final startT = parseTime(row.first['start_time'] as String?) ?? const TimeOfDay(hour: 10, minute: 0);
    final endT = parseTime(row.first['end_time'] as String?) ?? const TimeOfDay(hour: 22, minute: 0);
    var cursor = DateTime(day.year, day.month, day.day, startT.hour, startT.minute);
    final end = DateTime(day.year, day.month, day.day, endT.hour, endT.minute);
    if (!end.isAfter(cursor)) return const [];

    final normalizedTimeOff = timeOff
        .map((r) {
          final s = DateTime.tryParse(r['starts_at'] as String? ?? '')?.toLocal();
          final e = DateTime.tryParse(r['ends_at'] as String? ?? '')?.toLocal();
          if (s == null || e == null) return null;
          return (start: s, end: e, reason: (r['reason'] as String?) ?? '');
        })
        .whereType<({DateTime start, DateTime end, String reason})>()
        .toList(growable: false);

    final normalizedBookings = bookings
        .map((r) {
          final s = DateTime.tryParse(r['start_at'] as String? ?? '')?.toLocal();
          final e = DateTime.tryParse(r['end_at'] as String? ?? '')?.toLocal();
          if (s == null || e == null) return null;
          final status = (r['status'] as String?) ?? 'pending';
          final p = (r['profiles'] is Map) ? Map<String, dynamic>.from(r['profiles'] as Map) : null;
          final name = (p?['full_name'] as String?) ?? 'Customer';
          return (start: s, end: e, status: status, customerName: name);
        })
        .whereType<({DateTime start, DateTime end, String status, String customerName})>()
        .toList(growable: false);

    final tiles = <Widget>[];
    while (cursor.isBefore(end)) {
      final slotStart = cursor;
      final slotEnd = cursor.add(const Duration(minutes: 30));
      if (slotEnd.isAfter(end)) break;

      final off = normalizedTimeOff.where((t) => slotStart.isBefore(t.end) && slotEnd.isAfter(t.start)).toList(growable: false);
      final booking = normalizedBookings.where((b) => slotStart.isBefore(b.end) && slotEnd.isAfter(b.start) && b.status != 'cancelled').toList(growable: false);

      String kind = 'available';
      String? subtitle;
      if (off.isNotEmpty) {
        kind = 'blocked';
        subtitle = off.first.reason.trim().isEmpty ? 'Blocked' : off.first.reason.trim();
      } else if (booking.isNotEmpty) {
        kind = 'booked';
        subtitle = booking.first.customerName;
      }

      tiles.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SlotTile(
            start: slotStart,
            end: slotEnd,
            kind: kind,
            subtitle: subtitle,
          ),
        ),
      );
      cursor = slotEnd;
    }
    return tiles;
  }
}

class _SlotTile extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final String kind;
  final String? subtitle;

  const _SlotTile({required this.start, required this.end, required this.kind, this.subtitle});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badge;
    switch (kind) {
      case 'booked':
        badgeColor = AppTheme.gold.withValues(alpha: 0.14);
        badge = 'Booked';
        break;
      case 'blocked':
        badgeColor = AppTheme.error.withValues(alpha: 0.14);
        badge = 'Blocked';
        break;
      default:
        badgeColor = AppTheme.success.withValues(alpha: 0.14);
        badge = 'Available';
    }

    final time = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';

    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!.trim(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(badge, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _WorkingHourRow extends ConsumerWidget {
  final int weekday;
  final bool enabled;
  final String start;
  final String end;

  const _WorkingHourRow({
    required this.weekday,
    required this.enabled,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String label() {
      return switch (weekday) {
        0 => 'Sunday',
        1 => 'Monday',
        2 => 'Tuesday',
        3 => 'Wednesday',
        4 => 'Thursday',
        5 => 'Friday',
        _ => 'Saturday',
      };
    }

    TimeOfDay parse(String s) {
      final parts = s.split(':');
      final h = int.tryParse(parts.first) ?? 10;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return TimeOfDay(hour: h, minute: m);
    }

    String fmt(TimeOfDay t) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm:00';
    }

    Future<void> save({bool? newEnabled, TimeOfDay? newStart, TimeOfDay? newEnd}) async {
      final barber = await ref.read(myBarberProvider.future);
      if (barber == null) return;
      await ref.read(barberScheduleRepositoryProvider).upsertWorkingHour(
            barberId: barber.id,
            weekday: weekday,
            startTime: fmt(newStart ?? parse(start)),
            endTime: fmt(newEnd ?? parse(end)),
            enabled: newEnabled ?? enabled,
          );
      ref.invalidate(_myWorkingHoursProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label(), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                Switch.adaptive(value: enabled, onChanged: (v) => save(newEnabled: v)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: enabled
                        ? () async {
                            final picked = await showTimePicker(context: context, initialTime: parse(start));
                            if (picked == null) return;
                            await save(newStart: picked);
                          }
                        : null,
                    child: Text(start.substring(0, 5)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: enabled
                        ? () async {
                            final picked = await showTimePicker(context: context, initialTime: parse(end));
                            if (picked == null) return;
                            await save(newEnd: picked);
                          }
                        : null,
                    child: Text(end.substring(0, 5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeOffCard extends ConsumerWidget {
  final Map<String, dynamic> row;

  const _TimeOffCard({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = row['id'] as String;
    final start = DateTime.tryParse(row['starts_at'] as String? ?? '')?.toLocal();
    final end = DateTime.tryParse(row['ends_at'] as String? ?? '')?.toLocal();
    final reason = (row['reason'] as String?) ?? '';

    Future<void> remove() async {
      await ref.read(barberScheduleRepositoryProvider).deleteTimeOff(id);
      ref.invalidate(_myTimeOffProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    start == null || end == null ? 'Time off' : '${start.toString().substring(0, 16)} → ${end.toString().substring(0, 16)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  if (reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(reason, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                  ]
                ],
              ),
            ),
            IconButton(onPressed: remove, icon: const Icon(Icons.delete_outline_rounded), color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AddTimeOffScreen extends ConsumerStatefulWidget {
  const _AddTimeOffScreen();

  @override
  ConsumerState<_AddTimeOffScreen> createState() => _AddTimeOffScreenState();
}

class _AddTimeOffScreenState extends ConsumerState<_AddTimeOffScreen> {
  final _reason = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> pickStart() async {
      final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
      if (date == null) return;
      if (!context.mounted) return;
      final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
      if (time == null) return;
      setState(() => _start = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }

    Future<void> pickEnd() async {
      final base = _start ?? DateTime.now();
      final date = await showDatePicker(context: context, firstDate: base, lastDate: base.add(const Duration(days: 365)));
      if (date == null) return;
      if (!context.mounted) return;
      final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
      if (time == null) return;
      setState(() => _end = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Add time off', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          HallaqCard(
            glass: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(onPressed: pickStart, child: Text(_start == null ? 'Start' : _start.toString().substring(0, 16))),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: pickEnd, child: Text(_end == null ? 'End' : _end.toString().substring(0, 16))),
                const SizedBox(height: 10),
                TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason (optional)')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HallaqButton(
            label: 'Save',
            icon: Icons.check_rounded,
            isLoading: _busy,
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final barber = await ref.read(myBarberProvider.future);
                      if (barber == null) throw const AppException('No barber assigned to this account');
                      final start = _start;
                      final end = _end;
                      if (start == null || end == null) throw const AppException('Select start and end');
                      if (!end.isAfter(start)) throw const AppException('End must be after start');
                      await ref.read(barberScheduleRepositoryProvider).addTimeOff(
                            barberId: barber.id,
                            startsAt: start,
                            endsAt: end,
                            reason: _reason.text,
                          );
                      ref.invalidate(_myTimeOffProvider);
                      if (!context.mounted) return;
                      context.pop();
                    } on AppException catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
