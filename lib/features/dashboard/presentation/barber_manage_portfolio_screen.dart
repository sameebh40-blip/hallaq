import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/models/portfolio_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../portfolio/data/portfolio_repository.dart';
import 'barber_portfolio_controller.dart';

class BarberManagePortfolioScreen extends ConsumerStatefulWidget {
  final bool showBack;

  const BarberManagePortfolioScreen({super.key, this.showBack = true});

  @override
  ConsumerState<BarberManagePortfolioScreen> createState() => _BarberManagePortfolioScreenState();
}

class _BarberManagePortfolioScreenState extends ConsumerState<BarberManagePortfolioScreen> {
  static const _categories = <String>[
    'All',
    'Fades',
    'Beard',
    'Kids',
    'Transformations',
    'VIP Styles',
  ];

  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final barberValue = ref.watch(myBarberProvider);
    final controller = ref.watch(barberPortfolioControllerProvider);

    ref.listen(barberPortfolioControllerProvider, (_, next) {
      next.whenOrNull(error: (e, __) => showErrorSnackBar(context, e));
    });

    Future<void> uploadFlow() async {
      final selected = await showModalBottomSheet<({String category, String caption})>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _PortfolioUploadSheet(),
      );
      if (selected == null || !context.mounted) return;

      final barber = await ref.read(myBarberProvider.future);
      if (barber == null || !context.mounted) return;

      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
      if (file == null || !context.mounted) return;
      final bytes = await file.readAsBytes();
      await ref.read(barberPortfolioControllerProvider.notifier).addImage(
            bytes: bytes,
            caption: selected.caption.trim().isEmpty ? null : selected.caption,
            category: selected.category == 'All' ? null : selected.category,
          );
    }

    return LuxuryScaffold(
      header: widget.showBack
          ? LuxuryTopBar(
              leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
              title: Text('Portfolio', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              trailing: LuxuryIconButton(icon: Icons.add_photo_alternate_outlined, onPressed: controller.isLoading ? null : uploadFlow),
            )
          : null,
      child: AsyncValueWidget(
        value: barberValue,
        data: (barber) {
          if (barber == null) {
            return HallaqEmptyState(
              title: 'No barber profile',
              description: 'This account is not linked to a barber yet.',
              showMascot: true,
            );
          }

          final itemsValue = ref.watch(portfolioForBarberProvider(barber.id));
          return AsyncValueWidget<List<PortfolioItem>>(
            value: itemsValue,
            data: (items) {
              final filtered = _category == 'All' ? items : items.where((e) => (e.category ?? '') == _category).toList(growable: false);
              return Column(
                children: [
                  if (!widget.showBack)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Portfolio', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          ),
                          LuxuryIconButton(icon: Icons.add_photo_alternate_outlined, onPressed: controller.isLoading ? null : uploadFlow),
                        ],
                      ),
                    ),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final c = _categories[index];
                        final selected = c == _category;
                        return InkWell(
                          onTap: () => setState(() => _category = c),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: selected ? AppTheme.gold.withValues(alpha: 0.14) : AppTheme.surface,
                              border: Border.all(color: selected ? AppTheme.gold.withValues(alpha: 0.28) : AppTheme.border),
                              boxShadow: selected ? AppTheme.softShadow(opacity: 0.06) : null,
                            ),
                            child: Text(
                              c,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: selected ? AppTheme.goldDeep : AppTheme.text),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: _categories.length,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: HallaqEmptyState(
                              title: 'No portfolio yet',
                              description: 'Upload your best work. Customers will see it instantly on your profile.',
                              actionLabel: 'Upload photo',
                              onAction: controller.isLoading ? null : uploadFlow,
                              showMascot: true,
                              compact: true,
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _PortfolioTile(
                                item: item,
                                busy: controller.isLoading,
                                onDelete: () => ref.read(barberPortfolioControllerProvider.notifier).deleteItem(itemId: item.id, barberId: barber.id),
                                onEdit: () => _editItem(context, barberId: barber.id, item: item),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editItem(BuildContext context, {required String barberId, required PortfolioItem item}) async {
    final updated = await showModalBottomSheet<({String category, String caption})>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PortfolioEditSheet(
        initialCategory: (item.category ?? '').trim().isEmpty ? 'All' : item.category!,
        initialCaption: item.caption ?? '',
      ),
    );
    if (updated == null || !context.mounted) return;
    try {
      await ref.read(portfolioRepositoryProvider).update(
            id: item.id,
            category: updated.category == 'All' ? '' : updated.category,
            caption: updated.caption,
          );
      ref.invalidate(portfolioForBarberProvider(barberId));
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, e);
    }
  }
}

class _PortfolioTile extends StatelessWidget {
  final PortfolioItem item;
  final bool busy;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PortfolioTile({required this.item, required this.busy, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Stack(
        children: [
          Positioned.fill(
            child: HallaqCard(
              padding: EdgeInsets.zero,
              child: LuxuryNetworkImage(
                imageUrl: (item.thumbnailPath ?? '').trim().isNotEmpty
                    ? item.thumbnailPath
                    : (item.thumbnailUrl ?? '').trim().isNotEmpty
                        ? item.thumbnailUrl
                        : item.mediaPath ?? item.mediaUrl,
                fallbackUrl: '',
                bucket: 'portfolio',
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
          PositionedDirectional(
            top: 6,
            end: 6,
            child: GestureDetector(
              onTap: busy ? null : onDelete,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
              ),
            ),
          ),
          if ((item.category ?? '').trim().isNotEmpty)
            PositionedDirectional(
              start: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Text(
                  item.category!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PortfolioUploadSheet extends StatefulWidget {
  const _PortfolioUploadSheet();

  @override
  State<_PortfolioUploadSheet> createState() => _PortfolioUploadSheetState();
}

class _PortfolioUploadSheetState extends State<_PortfolioUploadSheet> {
  static const _categories = <String>['All', 'Fades', 'Beard', 'Kids', 'Transformations', 'VIP Styles'];
  String _category = 'All';
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: HallaqCard(
          glass: true,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Upload photo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'All'),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caption,
                  decoration: const InputDecoration(labelText: 'Caption (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                HallaqButton(
                  label: 'Pick photo',
                  icon: Icons.photo_library_outlined,
                  onPressed: () => Navigator.of(context).pop((category: _category, caption: _caption.text)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortfolioEditSheet extends StatefulWidget {
  final String initialCategory;
  final String initialCaption;

  const _PortfolioEditSheet({required this.initialCategory, required this.initialCaption});

  @override
  State<_PortfolioEditSheet> createState() => _PortfolioEditSheetState();
}

class _PortfolioEditSheetState extends State<_PortfolioEditSheet> {
  static const _categories = <String>['All', 'Fades', 'Beard', 'Kids', 'Transformations', 'VIP Styles'];
  late String _category;
  late TextEditingController _caption;

  @override
  void initState() {
    super.initState();
    _category = _categories.contains(widget.initialCategory) ? widget.initialCategory : 'All';
    _caption = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: HallaqCard(
          glass: true,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit photo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'All'),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caption,
                  decoration: const InputDecoration(labelText: 'Caption (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                HallaqButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop((category: _category, caption: _caption.text)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
