import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../booking/data/booking_repository.dart';

class BarberCalendarScreen extends ConsumerStatefulWidget {
  const BarberCalendarScreen({super.key});

  @override
  ConsumerState<BarberCalendarScreen> createState() => _BarberCalendarScreenState();
}

class _BarberCalendarScreenState extends ConsumerState<BarberCalendarScreen> {
  bool _weekly = false;
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(myBarberUpcomingBookingsDetailedProvider);
    final selectedDay = DateTime(_selected.year, _selected.month, _selected.day);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: const SizedBox.shrink(),
        title: Text('Calendar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: IconButton(
          onPressed: () => context.push(Routes.barberManageAvailability),
          icon: const Icon(Icons.tune_rounded),
          color: AppTheme.text,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Day')),
                      ButtonSegment(value: true, label: Text('Week')),
                    ],
                    selected: {_weekly},
                    onSelectionChanged: (s) => setState(() => _weekly = s.first),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 90)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _selected,
                    );
                    if (picked == null) return;
                    setState(() => _selected = picked);
                  },
                  icon: const Icon(Icons.calendar_month_rounded),
                  color: AppTheme.gold,
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueWidget<List<Map<String, dynamic>>>(
              value: upcoming,
              onRetry: () => ref.invalidate(myBarberUpcomingBookingsDetailedProvider),
              data: (items) {
                final byDay = <DateTime, List<Map<String, dynamic>>>{};
                for (final row in items) {
                  final dt = DateTime.parse(row['start_at'] as String).toLocal();
                  final day = DateTime(dt.year, dt.month, dt.day);
                  byDay.putIfAbsent(day, () => []).add(row);
                }
                for (final list in byDay.values) {
                  list.sort((a, b) => (a['start_at'] as String).compareTo(b['start_at'] as String));
                }

                if (_weekly) {
                  final startOfWeek = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
                  final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    children: [
                      _WeekStrip(
                        days: days,
                        selected: selectedDay,
                        onTap: (d) => setState(() => _selected = d),
                      ),
                      const SizedBox(height: 12),
                      ...days.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DayAgendaCard(day: d, rows: byDay[d] ?? const []),
                        ),
                      ),
                    ],
                  );
                }

                final rows = byDay[selectedDay] ?? const [];
                if (rows.isEmpty) {
                  return Center(
                    child: HallaqEmptyState(
                      title: 'No bookings today',
                      description: 'Upcoming bookings for this day will appear here.',
                      compact: true,
                      showMascot: true,
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        DateFormat('EEE, MMM d').format(selectedDay),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    ...rows.map((row) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _AgendaRow(row: row))),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  const _WeekStrip({required this.days, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: days.map((d) {
        final isSelected = d.year == selected.year && d.month == selected.month && d.day == selected.day;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(d),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.gold.withValues(alpha: 0.18) : AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: isSelected ? AppTheme.gold.withValues(alpha: 0.55) : AppTheme.border),
              ),
              child: Column(
                children: [
                  Text(DateFormat('EEE').format(d), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${d.day}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DayAgendaCard extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>> rows;

  const _DayAgendaCard({required this.day, required this.rows});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('EEE, MMM d').format(day), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text('No bookings', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted))
          else
            Column(children: rows.take(4).map((r) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _AgendaRow(row: r, compact: true))).toList()),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool compact;

  const _AgendaRow({required this.row, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(row['start_at'] as String).toLocal();
    final end = DateTime.parse(row['end_at'] as String).toLocal();
    final service = (row['services'] as Map?) == null ? null : Map<String, dynamic>.from(row['services'] as Map);
    final serviceName = (service?['name_en'] as String?) ?? (service?['name'] as String?) ?? 'Service';
    final customer = (row['profiles'] as Map?) == null ? null : Map<String, dynamic>.from(row['profiles'] as Map);
    final customerName = (customer?['full_name'] as String?) ?? 'Customer';

    return Row(
      children: [
        Container(
          width: 6,
          height: compact ? 34 : 42,
          decoration: BoxDecoration(
            color: AppTheme.gold,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(serviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text('${DateFormat('h:mm').format(start)}-${DateFormat('h:mm a').format(end)}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

