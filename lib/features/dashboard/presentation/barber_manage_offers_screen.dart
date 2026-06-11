import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/offer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../offers/data/offers_management_repository.dart';

final _myBarberOffersProvider = FutureProvider.autoDispose<List<Offer>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const <Offer>[];
  return ref.watch(offersManagementRepositoryProvider).listForBarber(barber.id);
});

class BarberManageOffersScreen extends ConsumerWidget {
  const BarberManageOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(_myBarberOffersProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Offers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(
          icon: Icons.add_rounded,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OfferEditor())),
        ),
      ),
      child: AsyncValueWidget<List<Offer>>(
        value: value,
        onRetry: () => ref.invalidate(_myBarberOffersProvider),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: HallaqEmptyState(
                title: 'No offers yet',
                description: 'Create a premium offer to bring clients back.',
                compact: true,
                showMascot: true,
                actionLabel: 'Create Offer',
                onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OfferEditor())),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: items.map((o) => _OfferRow(offer: o)).toList(),
          );
        },
      ),
    );
  }
}

class _OfferRow extends ConsumerWidget {
  final Offer offer;

  const _OfferRow({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(offersManagementRepositoryProvider);

    Future<void> remove() async {
      await repo.delete(offer.id);
      ref.invalidate(_myBarberOffersProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _OfferEditor(offer: offer))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    offer.active ? 'Active' : 'Inactive',
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

class _OfferEditor extends ConsumerStatefulWidget {
  final Offer? offer;

  const _OfferEditor({this.offer});

  @override
  ConsumerState<_OfferEditor> createState() => _OfferEditorState();
}

class _OfferEditorState extends ConsumerState<_OfferEditor> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _discount = TextEditingController();
  final _discountAmount = TextEditingController();
  String _type = 'percentage';
  DateTime? _start;
  DateTime? _end;
  XFile? _banner;
  bool _active = true;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _discount.dispose();
    _discountAmount.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _banner = file);
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2), initialDate: _start ?? now);
    if (picked == null) return;
    setState(() => _start = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2), initialDate: _end ?? (_start ?? now));
    if (picked == null) return;
    setState(() => _end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final barber = await ref.read(myBarberProvider.future);
      if (barber == null) throw const AppException('No barber assigned to this account');

      String? bannerPath;
      String? bannerUrl;
      if (_banner != null) {
        final bytes = await _banner!.readAsBytes();
        final media = ref.read(mediaServiceProvider);
        final uploaded = await media.uploadImage(bucket: 'offer-images', pathPrefix: 'barbers/${barber.id}', bytes: bytes, maxBytes: 5 * 1024 * 1024);
        bannerPath = uploaded.path;
        bannerUrl = media.publicUrlFor(bucket: 'offer-images', path: uploaded.path);
      }

      final payload = <String, dynamic>{
        if (widget.offer != null) 'id': widget.offer!.id,
        'barber_id': barber.id,
        if ((barber.shopId ?? '').trim().isNotEmpty) 'shop_id': barber.shopId,
        'title': _title.text.trim(),
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'offer_type': _type,
        'discount_percent': _type == 'percentage' ? double.tryParse(_discount.text.trim()) : null,
        'discount_amount': _type == 'fixed' ? double.tryParse(_discountAmount.text.trim()) : null,
        'package_details': _type == 'package' ? {'details': _discount.text.trim()} : const <String, dynamic>{},
        'valid_from': _start?.toUtc().toIso8601String(),
        'valid_to': _end?.toUtc().toIso8601String(),
        'active': _active,
        if (bannerPath != null) 'banner_path': bannerPath,
        if (bannerUrl != null) 'banner_url': bannerUrl,
        'is_active': true,
        'status': 'approved',
      };

      if (payload['title'] == null || (payload['title'] as String).trim().isEmpty) {
        throw const AppException('Title is required');
      }

      await ref.read(offersManagementRepositoryProvider).upsert(payload);
      ref.invalidate(_myBarberOffersProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is AppException ? e.message : 'Failed to save offer')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.offer;
    if (existing != null && _title.text.isEmpty) {
      _title.text = existing.title;
      _desc.text = existing.description ?? '';
      _discount.text = existing.offerType == 'package' ? ((existing.packageDetails['details'] as String?) ?? '') : (existing.discountPercent?.toStringAsFixed(2) ?? '');
      _discountAmount.text = existing.discountAmount?.toStringAsFixed(3) ?? '';
      _type = existing.offerType;
      _start = existing.validFrom;
      _end = existing.validTo;
      _active = existing.active;
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(existing == null ? 'New offer' : 'Edit offer', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          HallaqCard(
            glass: true,
            child: Column(
              children: [
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed discount')),
                    DropdownMenuItem(value: 'package', child: Text('Package offer')),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _type = v ?? 'percentage'),
                  decoration: const InputDecoration(labelText: 'Offer type'),
                ),
                const SizedBox(height: 10),
                if (_type == 'percentage')
                  TextField(controller: _discount, decoration: const InputDecoration(labelText: 'Discount %'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                if (_type == 'fixed')
                  TextField(
                    controller: _discountAmount,
                    decoration: const InputDecoration(labelText: 'Discount amount (BHD)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                if (_type == 'package')
                  TextField(
                    controller: _discount,
                    decoration: const InputDecoration(labelText: 'Package details'),
                    maxLines: 3,
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: HallaqButton(
                        label: _start == null ? 'Start date' : 'Start: ${_start!.toIso8601String().substring(0, 10)}',
                        variant: HallaqButtonVariant.secondary,
                        icon: Icons.date_range_rounded,
                        onPressed: _busy ? null : _pickStart,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: HallaqButton(
                        label: _end == null ? 'End date' : 'End: ${_end!.toIso8601String().substring(0, 10)}',
                        variant: HallaqButtonVariant.secondary,
                        icon: Icons.event_available_rounded,
                        onPressed: _busy ? null : _pickEnd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                HallaqButton(
                  label: _banner == null ? 'Pick banner' : 'Change banner',
                  variant: HallaqButtonVariant.secondary,
                  icon: Icons.image_outlined,
                  onPressed: _busy ? null : _pickBanner,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _active,
                  onChanged: _busy ? null : (v) => setState(() => _active = v),
                  title: const Text('Active'),
                ),
                const SizedBox(height: 10),
                HallaqButton(label: _busy ? 'Saving...' : 'Save Offer', onPressed: _busy ? null : _save, icon: Icons.check_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
