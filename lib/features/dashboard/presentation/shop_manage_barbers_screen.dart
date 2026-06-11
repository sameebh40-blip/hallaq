import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/barber.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../shop/data/shop_repository.dart';

final _shopBarbersProvider = FutureProvider<List<Barber>>((ref) async {
  final shop = await ref.watch(myShopProvider.future);
  if (shop == null) return const <Barber>[];
  return ref.watch(barberRepositoryProvider).listForShopManage(shop.id);
});

final _unassignedBarbersProvider = FutureProvider<List<Barber>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final data = await client
        .from('barbers')
        .select()
        .isFilter('shop_id', null)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(100);
    return (data as List).map((e) => Barber.fromJson(Map<String, dynamic>.from(e))).toList();
  } catch (_) {
    return const <Barber>[];
  }
});

final _barberAccountRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final shop = await ref.watch(myShopProvider.future);
  if (shop == null) return const <Map<String, dynamic>>[];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('barber_account_requests')
      .select('id, full_name, email, phone, notes, status, created_at, decided_at')
      .eq('shop_id', shop.id)
      .order('created_at', ascending: false)
      .limit(100);
  return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class ShopManageBarbersScreen extends ConsumerWidget {
  const ShopManageBarbersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopValue = ref.watch(myShopProvider);
    final barbersValue = ref.watch(_shopBarbersProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Barbers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LuxuryIconButton(
              icon: Icons.person_add_alt_1_rounded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AddBarberScreen())),
            ),
            const SizedBox(width: 6),
            LuxuryIconButton(
              icon: Icons.mail_outline_rounded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _RequestBarberAccountScreen())),
            ),
          ],
        ),
      ),
      child: AsyncValueWidget(
        value: shopValue,
        onRetry: () {
          ref.invalidate(myShopProvider);
          ref.invalidate(_shopBarbersProvider);
        },
        data: (shop) {
          if (shop == null) return const Center(child: Text('No shop assigned to this account.'));
          return AsyncValueWidget<List<Barber>>(
            value: barbersValue,
            onRetry: () => ref.invalidate(_shopBarbersProvider),
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('No barbers in this shop yet.'));
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: items.map((b) => _BarberRow(shopId: shop.id, barber: b)).toList(),
              );
            },
          );
        },
      ),
    );
  }
}

class _BarberRow extends ConsumerWidget {
  final String shopId;
  final Barber barber;

  const _BarberRow({required this.shopId, required this.barber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    Future<void> remove() async {
      try {
        await client.from('barbers').update({'shop_id': null, 'branch_id': null, 'is_independent': true}).eq('id', barber.id);
        ref.invalidate(_shopBarbersProvider);
      } on Exception catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is AppException ? e.message : 'Failed')));
      }
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
                  Text(barber.displayName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(barber.area ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            ),
            IconButton(onPressed: remove, icon: const Icon(Icons.person_remove_alt_1_rounded), color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AddBarberScreen extends ConsumerWidget {
  const _AddBarberScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopValue = ref.watch(myShopProvider);
    final candidates = ref.watch(_unassignedBarbersProvider);
    final client = ref.watch(supabaseClientProvider);

    Future<void> add(String shopId, String barberId) async {
      final branchId = await client.rpc('ensure_shop_default_branch', params: {'p_shop_id': shopId}) as String?;
      if (branchId == null || branchId.isEmpty) {
        throw const AppException('Failed to resolve a branch for this shop');
      }
      await client.from('barbers').update({
        'shop_id': shopId,
        'branch_id': branchId,
        'is_independent': false,
        'status': 'approved',
        'is_active': true,
      }).eq('id', barberId);
      ref.invalidate(_shopBarbersProvider);
      ref.invalidate(_unassignedBarbersProvider);
      if (!context.mounted) return;
      context.pop();
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Add barber', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget(
        value: shopValue,
        data: (shop) {
          if (shop == null) return const Center(child: Text('No shop assigned to this account.'));
          return AsyncValueWidget<List<Barber>>(
            value: candidates,
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('No available barbers.'));
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: items
                    .map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: HallaqCard(
                          glass: true,
                          onTap: () => add(shop.id, b.id),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.displayName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 6),
                                    Text(b.area ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.add_circle_outline_rounded, color: AppTheme.gold),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestBarberAccountScreen extends ConsumerStatefulWidget {
  const _RequestBarberAccountScreen();

  @override
  ConsumerState<_RequestBarberAccountScreen> createState() => _RequestBarberAccountScreenState();
}

class _RequestBarberAccountScreenState extends ConsumerState<_RequestBarberAccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopValue = ref.watch(myShopProvider);
    final requestsValue = ref.watch(_barberAccountRequestsProvider);
    final client = ref.watch(supabaseClientProvider);

    Future<void> submit(String shopId) async {
      final fullName = _name.text.trim();
      final email = _email.text.trim().toLowerCase();
      final phone = _phone.text.trim();
      final notes = _notes.text.trim();
      if (fullName.isEmpty || (email.isEmpty && phone.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and email or phone required')));
        return;
      }
      try {
        final user = client.auth.currentUser;
        if (user == null) throw const AppException('Not signed in');
        await client.from('barber_account_requests').insert({
          'shop_id': shopId,
          'requested_by_profile_id': user.id,
          'full_name': fullName,
          'email': email.isEmpty ? null : email,
          'phone': phone.isEmpty ? null : phone,
          'notes': notes.isEmpty ? null : notes,
          'status': 'pending',
        });
        _name.clear();
        _email.clear();
        _phone.clear();
        _notes.clear();
        ref.invalidate(_barberAccountRequestsProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted')));
      } on Exception catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is AppException ? e.message : 'Failed')));
      }
    }

    Future<void> cancel(String requestId) async {
      try {
        await client.from('barber_account_requests').update({'status': 'cancelled'}).eq('id', requestId);
        ref.invalidate(_barberAccountRequestsProvider);
      } on Exception catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is AppException ? e.message : 'Failed')));
      }
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Request barber account', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget(
        value: shopValue,
        data: (shop) {
          if (shop == null) return const Center(child: Text('No shop assigned to this account.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New request', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
                    const SizedBox(height: 10),
                    TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email (optional)')),
                    const SizedBox(height: 10),
                    TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
                    const SizedBox(height: 10),
                    TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => submit(shop.id),
                        child: const Text('Submit request'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Requests', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              AsyncValueWidget<List<Map<String, dynamic>>>(
                value: requestsValue,
                data: (items) {
                  if (items.isEmpty) return const Padding(padding: EdgeInsets.only(top: 8), child: Text('No requests yet.'));
                  return Column(
                    children: items.map((r) {
                      final id = (r['id'] as String?) ?? '';
                      final name = (r['full_name'] as String?) ?? '';
                      final email = (r['email'] as String?) ?? '';
                      final phone = (r['phone'] as String?) ?? '';
                      final status = (r['status'] as String?) ?? 'pending';
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
                                    Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 6),
                                    Text('$email $phone', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                                    const SizedBox(height: 6),
                                    Text('Status: $status', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              if (status == 'pending')
                                IconButton(
                                  onPressed: () => cancel(id),
                                  icon: const Icon(Icons.cancel_outlined),
                                  color: AppTheme.textMuted,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
