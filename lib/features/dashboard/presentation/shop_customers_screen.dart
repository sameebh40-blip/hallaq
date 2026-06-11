import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../data/shop_dashboard_repository.dart';

class _CustomerRow {
  final String profileId;
  final String name;
  final String phone;
  final DateTime? lastBookingAt;
  final int totalBookings;
  final double totalSpentBhd;
  final String favoriteService;
  final String note;

  const _CustomerRow({
    required this.profileId,
    required this.name,
    required this.phone,
    required this.lastBookingAt,
    required this.totalBookings,
    required this.totalSpentBhd,
    required this.favoriteService,
    required this.note,
  });
}

final _shopCustomersBookingsLimitProvider = StateProvider<int>((ref) => 500);

final _shopCustomersProvider = FutureProvider<List<_CustomerRow>>((ref) async {
  final shopId = await ref.watch(shopDashboardRepositoryProvider).getMyShopId();
  if (shopId == null) return const [];

  final bookingsLimit = ref.watch(_shopCustomersBookingsLimitProvider);
  final client = ref.watch(supabaseClientProvider);
  final bookingsData = await client
      .from('bookings')
      .select('customer_profile_id, start_at, price_bhd, services(name_en), profiles(full_name, phone)')
      .eq('shop_id', shopId)
      .order('start_at', ascending: false)
      .limit(bookingsLimit);

  final map = <String, Map<String, dynamic>>{};
  final serviceCounts = <String, Map<String, int>>{};
  final customerIds = <String>{};
  for (final b in (bookingsData as List)) {
    final m = Map<String, dynamic>.from(b as Map);
    final id = m['customer_profile_id'] as String?;
    if (id == null) continue;
    customerIds.add(id);

    final profiles = m['profiles'] as Map?;
    final name = (profiles?['full_name'] as String?) ?? 'Customer';
    final phone = (profiles?['phone'] as String?) ?? '';

    final startRaw = m['start_at'] as String?;
    final startAt = startRaw == null ? null : DateTime.tryParse(startRaw)?.toLocal();
    final price = (m['price_bhd'] as num?)?.toDouble() ?? 0;

    final service = m['services'] as Map?;
    final serviceName = (service?['name_en'] as String?) ?? '';

    final agg = map[id] ?? {
      'profileId': id,
      'name': name,
      'phone': phone,
      'lastBookingAt': startAt,
      'totalBookings': 0,
      'totalSpentBhd': 0.0,
    };
    agg['totalBookings'] = (agg['totalBookings'] as int) + 1;
    agg['totalSpentBhd'] = (agg['totalSpentBhd'] as double) + price;
    if (agg['lastBookingAt'] == null && startAt != null) {
      agg['lastBookingAt'] = startAt;
    }
    map[id] = agg;

    if (serviceName.isNotEmpty) {
      final counts = serviceCounts[id] ?? <String, int>{};
      counts[serviceName] = (counts[serviceName] ?? 0) + 1;
      serviceCounts[id] = counts;
    }
  }

  final noteByCustomer = <String, String>{};
  if (customerIds.isNotEmpty) {
    final notesData = await client
        .from('customer_notes')
        .select('customer_profile_id, note')
        .eq('shop_id', shopId)
        .inFilter('customer_profile_id', customerIds.toList())
        .limit(5000);
    for (final n in (notesData as List)) {
      final m = Map<String, dynamic>.from(n as Map);
      final id = m['customer_profile_id'] as String?;
      if (id == null) continue;
      noteByCustomer[id] = (m['note'] as String?) ?? '';
    }
  }

  final rows = <_CustomerRow>[];
  for (final e in map.entries) {
    final counts = serviceCounts[e.key] ?? const <String, int>{};
    var topService = '';
    var topCount = 0;
    for (final c in counts.entries) {
      if (c.value > topCount) {
        topCount = c.value;
        topService = c.key;
      }
    }
    rows.add(
      _CustomerRow(
        profileId: e.key,
        name: e.value['name'] as String,
        phone: e.value['phone'] as String,
        lastBookingAt: e.value['lastBookingAt'] as DateTime?,
        totalBookings: e.value['totalBookings'] as int,
        totalSpentBhd: e.value['totalSpentBhd'] as double,
        favoriteService: topService,
        note: noteByCustomer[e.key] ?? '',
      ),
    );
  }
  rows.sort((a, b) => (b.lastBookingAt ?? DateTime(1970)).compareTo(a.lastBookingAt ?? DateTime(1970)));
  return rows;
});

class ShopCustomersScreen extends ConsumerWidget {
  final bool showAppBar;

  const ShopCustomersScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(_shopCustomersProvider);
    final limit = ref.watch(_shopCustomersBookingsLimitProvider);
    final bottomPad = 110.0 + MediaQuery.of(context).padding.bottom;

    final body = AsyncValueWidget<List<_CustomerRow>>(
      value: value,
      onRetry: () => ref.invalidate(_shopCustomersProvider),
      data: (rows) {
        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: HallaqCard(glass: true, child: Text('No customers yet.')),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(child: Text('Scanning last $limit bookings', style: Theme.of(context).textTheme.bodySmall)),
                  if (limit < 5000)
                    TextButton(
                      onPressed: () {
                        ref.read(_shopCustomersBookingsLimitProvider.notifier).state = (limit + 500).clamp(0, 5000);
                        ref.invalidate(_shopCustomersProvider);
                      },
                      child: const Text('Load more'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPad),
                children: rows.map((r) => _CustomerCard(row: r)).toList(),
              ),
            ),
          ],
        );
      },
    );

    if (!showAppBar) return body;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Customers')),
      body: body,
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  final _CustomerRow row;

  const _CustomerCard({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final repo = ref.watch(shopDashboardRepositoryProvider);

    Future<void> addNote() async {
      final controller = TextEditingController(text: row.note);
      final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Note'),
              content: TextField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(hintText: 'Add a note about this customer'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
      final shopId = await repo.getMyShopId();
      if (shopId == null) return;
      await client.from('customer_notes').upsert({
        'shop_id': shopId,
        'customer_profile_id': row.profileId,
        'note': controller.text.trim(),
      });
      ref.invalidate(_shopCustomersProvider);
    }

    final last = row.lastBookingAt;
    final lastLabel = last == null
        ? '—'
        : '${last.year}-${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const HallaqAvatar(imageUrl: null, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(row.phone.isEmpty ? '—' : row.phone, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                TextButton(onPressed: addNote, child: const Text('Note')),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Last booking: $lastLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              'Total bookings: ${row.totalBookings} • Total spent: ${row.totalSpentBhd.toStringAsFixed(3)} BHD',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            if (row.favoriteService.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Favorite: ${row.favoriteService}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
            ],
            if (row.note.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(row.note, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
