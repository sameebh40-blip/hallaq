import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/models/barber.dart';
import '../../../core/models/before_after_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../before_after/data/before_after_repository.dart';

class BarberManageBeforeAfterScreen extends ConsumerWidget {
  const BarberManageBeforeAfterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberValue = ref.watch(myBarberProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Before & After', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(
          icon: Icons.add_rounded,
          onPressed: () async {
            final barber = barberValue.valueOrNull;
            if (barber == null) return;
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _BeforeAfterUploader(barber: barber)));
            ref.invalidate(beforeAfterForBarberProvider(barber.id));
          },
        ),
      ),
      child: AsyncValueWidget<Barber?>(
        value: barberValue,
        data: (barber) {
          if (barber == null) return const Center(child: Text('No barber profile'));
          final itemsValue = ref.watch(beforeAfterForBarberProvider(barber.id));
          return AsyncValueWidget<List<BeforeAfterItem>>(
            value: itemsValue,
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: HallaqEmptyState(
                    title: 'Before & After',
                    description: 'Upload your first transformation',
                    showMascot: true,
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                itemBuilder: (_, i) => _Row(item: items[i]),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: items.length,
              );
            },
          );
        },
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  final BeforeAfterItem item;

  const _Row({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HallaqCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LuxuryNetworkImage(
                    imageUrl: item.beforeImageUrl,
                    fallbackUrl: HallaqImages.blackGoldBackground(),
                    height: 140,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LuxuryNetworkImage(
                    imageUrl: item.afterImageUrl,
                    fallbackUrl: HallaqImages.blackGoldBackground(),
                    height: 140,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          if ((item.caption ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item.caption!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                try {
                  await ref.read(beforeAfterRepositoryProvider).delete(id: item.id);
                } catch (e) {
                  if (context.mounted) showErrorSnackBar(context, e);
                }
              },
              child: const Text('Delete', style: TextStyle(color: AppTheme.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeforeAfterUploader extends ConsumerStatefulWidget {
  final Barber barber;

  const _BeforeAfterUploader({required this.barber});

  @override
  ConsumerState<_BeforeAfterUploader> createState() => _BeforeAfterUploaderState();
}

class _BeforeAfterUploaderState extends ConsumerState<_BeforeAfterUploader> {
  XFile? _before;
  XFile? _after;
  final _caption = TextEditingController();
  final _category = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _pickBefore() async {
    final picker = ImagePicker();
    final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f == null) return;
    setState(() => _before = f);
  }

  Future<void> _pickAfter() async {
    final picker = ImagePicker();
    final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f == null) return;
    setState(() => _after = f);
  }

  Future<void> _submit() async {
    if (_before == null || _after == null) {
      showErrorSnackBar(context, const AppException('Select both before and after images'));
      return;
    }
    setState(() => _busy = true);
    try {
      final beforeBytes = await _before!.readAsBytes();
      final afterBytes = await _after!.readAsBytes();
      await ref.read(beforeAfterRepositoryProvider).create(
            barberId: widget.barber.id,
            shopId: widget.barber.shopId,
            beforeBytes: beforeBytes,
            afterBytes: afterBytes,
            caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
            category: _category.text.trim().isEmpty ? null : _category.text.trim(),
          );
      if (!mounted) return;
      context.pop();
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Upload', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: HallaqButton(
                  label: _before == null ? 'Select before' : 'Change before',
                  variant: HallaqButtonVariant.secondary,
                  icon: Icons.photo_outlined,
                  onPressed: _busy ? null : _pickBefore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HallaqButton(
                  label: _after == null ? 'Select after' : 'Change after',
                  variant: HallaqButtonVariant.secondary,
                  icon: Icons.photo_outlined,
                  onPressed: _busy ? null : _pickAfter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HallaqCard(
            glass: true,
            child: Column(
              children: [
                TextField(controller: _caption, decoration: const InputDecoration(labelText: 'Caption')),
                const SizedBox(height: 10),
                TextField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HallaqButton(
            label: 'Upload',
            icon: Icons.cloud_upload_rounded,
            isLoading: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
