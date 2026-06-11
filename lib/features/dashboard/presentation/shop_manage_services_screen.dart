import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../services/data/services_management_repository.dart';
import '../../shop/data/shop_repository.dart';

final _myShopServicesManageProvider = FutureProvider<List<Service>>((ref) async {
  final shop = await ref.watch(myShopProvider.future);
  if (shop == null) return const <Service>[];
  return ref.watch(servicesManagementRepositoryProvider).listForShop(shop.id);
});

class ShopManageServicesScreen extends ConsumerWidget {
  const ShopManageServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesValue = ref.watch(_myShopServicesManageProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Services', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(
          icon: Icons.add_rounded,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ServiceEditor())),
        ),
      ),
      child: AsyncValueWidget<List<Service>>(
        value: servicesValue,
        onRetry: () => ref.invalidate(_myShopServicesManageProvider),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No services yet.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: items.map((s) => _ServiceCard(service: s)).toList(),
          );
        },
      ),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  final Service service;

  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(servicesManagementRepositoryProvider);

    Future<void> remove() async {
      await repo.delete(service.id);
      ref.invalidate(_myShopServicesManageProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ServiceEditor(service: service))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.nameEn, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    '${service.priceBhd.toStringAsFixed(3)} BHD • ${service.durationMinutes} min',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(onPressed: remove, icon: const Icon(Icons.delete_outline_rounded), color: AppTheme.textMuted),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ServiceEditor extends ConsumerStatefulWidget {
  final Service? service;

  const _ServiceEditor({this.service});

  @override
  ConsumerState<_ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends ConsumerState<_ServiceEditor> {
  final _nameEn = TextEditingController();
  final _nameAr = TextEditingController();
  final _descEn = TextEditingController();
  final _descAr = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController();

  bool _popular = false;
  bool _active = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameEn.dispose();
    _nameAr.dispose();
    _descEn.dispose();
    _descAr.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.service;
    if (existing != null && _nameEn.text.isEmpty) {
      _nameEn.text = existing.nameEn;
      _nameAr.text = existing.nameAr;
      _descEn.text = existing.descriptionEn;
      _descAr.text = existing.descriptionAr;
      _price.text = existing.priceBhd.toStringAsFixed(3);
      _duration.text = existing.durationMinutes.toString();
      _popular = existing.isPopular;
      _active = existing.isActive;
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(existing == null ? 'New service' : 'Edit service', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          HallaqCard(
            glass: true,
            child: Column(
              children: [
                TextField(controller: _nameEn, decoration: const InputDecoration(labelText: 'Name (EN)')),
                const SizedBox(height: 10),
                TextField(controller: _nameAr, decoration: const InputDecoration(labelText: 'Name (AR)')),
                const SizedBox(height: 10),
                TextField(controller: _descEn, decoration: const InputDecoration(labelText: 'Description (EN)')),
                const SizedBox(height: 10),
                TextField(controller: _descAr, decoration: const InputDecoration(labelText: 'Description (AR)')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _price,
                        decoration: const InputDecoration(labelText: 'Price (BHD)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _duration,
                        decoration: const InputDecoration(labelText: 'Duration (min)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  value: _popular,
                  onChanged: _busy ? null : (v) => setState(() => _popular = v),
                  title: const Text('Popular'),
                ),
                SwitchListTile.adaptive(
                  value: _active,
                  onChanged: _busy ? null : (v) => setState(() => _active = v),
                  title: const Text('Active'),
                ),
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
                      final shop = await ref.read(myShopProvider.future);
                      if (shop == null) throw const AppException('No shop assigned to this account');

                      final payload = <String, dynamic>{
                        if (existing != null) 'id': existing.id,
                        'shop_id': shop.id,
                        'barber_id': null,
                        'name_en': _nameEn.text.trim(),
                        'name_ar': _nameAr.text.trim(),
                        'description_en': _descEn.text.trim(),
                        'description_ar': _descAr.text.trim(),
                        'price_bhd': double.tryParse(_price.text.trim()) ?? 0,
                        'duration_minutes': int.tryParse(_duration.text.trim()) ?? 30,
                        'status': 'approved',
                        'is_popular': _popular,
                        'is_active': _active,
                        'deleted_at': null,
                      };

                      await ref.read(servicesManagementRepositoryProvider).upsert(payload: payload);
                      ref.invalidate(_myShopServicesManageProvider);
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
