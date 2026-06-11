import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/system_logs_repository.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/product.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../../core/widgets/luxury_text_field.dart';
import '../../dashboard/data/shop_dashboard_repository.dart';
import '../data/products_repository.dart';

class ShopProductEditorScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ShopProductEditorScreen({super.key, this.productId});

  @override
  ConsumerState<ShopProductEditorScreen> createState() => _ShopProductEditorScreenState();
}

class _ShopProductEditorScreenState extends ConsumerState<ShopProductEditorScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();

  bool _active = true;
  bool _busy = false;
  List<_PickedMedia> _picked = const [];
  Product? _loaded;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _fill(Product p) {
    _loaded = p;
    _name.text = p.name;
    _desc.text = p.description ?? '';
    _price.text = p.price.toStringAsFixed(3);
    _stock.text = p.stock.toString();
    _active = p.active;
  }

  @override
  Widget build(BuildContext context) {
    final shopIdValue = ref.watch(_editorShopIdProvider);
    final productValue = widget.productId == null ? const AsyncValue<Product?>.data(null) : ref.watch(productByIdProvider(widget.productId!));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text(widget.productId == null ? 'New product' : 'Edit product', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget<String?>(
        value: shopIdValue,
        data: (shopId) {
          if (shopId == null) return const Center(child: Text('No shop assigned to this account.'));

          return AsyncValueWidget<Product?>(
            value: productValue,
            data: (product) {
              if (widget.productId != null && product == null) return const Center(child: Text('Product not found.'));
              if (product != null && _loaded?.id != product.id) {
                _fill(product);
              }

              final existingImage = (_loaded?.images ?? const <String>[]);
              final imageUrl = _loaded?.imageUrl ?? (existingImage.isEmpty ? null : existingImage.first);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                children: [
                  HallaqCard(
                    glass: true,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Image', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          child: SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: _picked.isNotEmpty
                                ? Image.memory(_picked.first.bytes, fit: BoxFit.cover)
                                : _ResolvedProductImage(primary: imageUrl),
                          ),
                        ),
                        const SizedBox(height: 10),
                        HallaqButton(
                          label: 'Upload images',
                          expanded: true,
                          variant: HallaqButtonVariant.secondary,
                          icon: Icons.photo_library_rounded,
                          onPressed: _busy
                              ? null
                              : () async {
                                  final picker = ImagePicker();
                                  final files = await picker.pickMultiImage(imageQuality: 88);
                                  if (files.isEmpty) return;
                                  final picked = <_PickedMedia>[];
                                  for (final f in files.take(6)) {
                                    final name = (f.name).toLowerCase();
                                    final okExt = name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp');
                                    if (!okExt) continue;
                                    final bytes = await f.readAsBytes();
                                    if (bytes.lengthInBytes <= 0) continue;
                                    picked.add(_PickedMedia(name: f.name, bytes: bytes));
                                  }
                                  if (picked.isEmpty) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid images selected.')));
                                    return;
                                  }
                                  setState(() => _picked = picked);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${picked.length} images selected. Tap Save.')));
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  HallaqCard(
                    glass: true,
                    child: Column(
                      children: [
                        LuxuryTextField(controller: _name, label: 'Name'),
                        const SizedBox(height: 10),
                        LuxuryTextField(controller: _desc, label: 'Description', textInputAction: TextInputAction.next),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: LuxuryTextField(
                                controller: _price,
                                label: 'Price (BHD)',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: LuxuryTextField(
                                controller: _stock,
                                label: 'Stock',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
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
                              final productsRepo = ref.read(productsRepositoryProvider);
                              final media = ref.read(mediaServiceProvider);

                              final name = _name.text.trim();
                              if (name.isEmpty) throw const AppException('Name is required');

                              final price = double.tryParse(_price.text.trim()) ?? 0;
                              final stock = int.tryParse(_stock.text.trim()) ?? 0;

                              Product saved;
                              if (widget.productId == null) {
                                saved = await productsRepo.create(
                                  shopId: shopId,
                                  name: name,
                                  description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                                  price: price,
                                  stock: stock,
                                  active: _active,
                                );
                              } else {
                                saved = await productsRepo.update(
                                  id: widget.productId!,
                                  name: name,
                                  description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                                  price: price,
                                  stock: stock,
                                  active: _active,
                                );
                              }

                              if (_picked.isNotEmpty) {
                                final paths = <String>[];
                                for (final f in _picked.take(6)) {
                                  final stored = await media.uploadImage(
                                    bucket: 'product-images',
                                    pathPrefix: 'shops/$shopId/${saved.id}',
                                    bytes: f.bytes,
                                    uploadThumbnail: false,
                                  );
                                  paths.add(stored.path);
                                }
                                saved = await productsRepo.update(id: saved.id, images: paths, imageUrl: paths.isEmpty ? null : paths.first);
                              }

                              ref.invalidate(shopProductsManagementProvider(shopId));
                              ref.invalidate(productsForShopProvider(shopId));
                              ref.invalidate(productByIdProvider(saved.id));
                              if (!context.mounted) return;
                              context.go(Routes.shopManageProducts);
                            } on AppException catch (e) {
                              ref.read(systemLogsRepositoryProvider).logErrorUnawaited(
                                    page: 'shop_product_editor',
                                    action: 'save_product',
                                    error: e,
                                    meta: {'shop_id': shopId, 'product_id': widget.productId},
                                  );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

final _editorShopIdProvider = FutureProvider<String?>((ref) async {
  return ref.watch(shopDashboardRepositoryProvider).getMyShopId();
});

class _PickedMedia {
  final String name;
  final Uint8List bytes;

  const _PickedMedia({required this.name, required this.bytes});
}

class _ResolvedProductImage extends ConsumerWidget {
  final String? primary;

  const _ResolvedProductImage({required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = (primary ?? '').trim();
    if (v.isEmpty) {
      return const LuxuryNetworkImage(imageUrl: '', fallbackUrl: '', borderRadius: BorderRadius.zero);
    }
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return LuxuryNetworkImage(imageUrl: v, fallbackUrl: '', borderRadius: BorderRadius.zero, fit: BoxFit.cover);
    }
    final media = ref.read(mediaServiceProvider);
    return FutureBuilder<String?>(
      future: media.resolveMediaUrlMulti(buckets: const ['product-images', 'products'], path: v, legacyUrlOrPath: null),
      builder: (context, snap) {
        final resolved = (snap.data ?? '').trim();
        return LuxuryNetworkImage(imageUrl: resolved.isNotEmpty ? resolved : '', fallbackUrl: '', borderRadius: BorderRadius.zero, fit: BoxFit.cover);
      },
    );
  }
}
