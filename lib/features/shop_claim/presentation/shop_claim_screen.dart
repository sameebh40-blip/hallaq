import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../shop/data/shop_repository.dart';
import '../data/shop_claim_repository.dart';

class ShopClaimScreen extends ConsumerStatefulWidget {
  final String shopId;

  const ShopClaimScreen({super.key, required this.shopId});

  @override
  ConsumerState<ShopClaimScreen> createState() => _ShopClaimScreenState();
}

class _ShopClaimScreenState extends ConsumerState<ShopClaimScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _proof = TextEditingController();
  XFile? _proofImage;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _proof.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _proofImage = file);
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      showErrorSnackBar(context, const AppException('Name is required'));
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _proofImage?.readAsBytes();
      await ref.read(shopClaimRepositoryProvider).submit(
            shopId: widget.shopId,
            name: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            proofText: _proof.text.trim().isEmpty ? null : _proof.text.trim(),
            proofImageBytes: bytes is Uint8List ? bytes : null,
          );
      ref.invalidate(myShopClaimForShopProvider(widget.shopId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim submitted')));
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
    final shopValue = ref.watch(_shopProvider(widget.shopId));
    final myClaimValue = ref.watch(myShopClaimForShopProvider(widget.shopId));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Claim this shop', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          AsyncValueWidget(
            value: shopValue,
            data: (shop) => HallaqCard(
              glass: true,
              child: Row(
                children: [
                  Expanded(child: Text(shop.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                  Text(shop.area ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AsyncValueWidget(
            value: myClaimValue,
            data: (req) {
              if (req == null) return const SizedBox.shrink();
              final label = switch (req.status) {
                'approved' => 'Approved',
                'rejected' => 'Rejected',
                _ => 'Pending',
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HallaqCard(
                  glass: true,
                  child: Row(
                    children: [
                      Expanded(child: Text('Your request', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                      Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              );
            },
          ),
          HallaqCard(
            glass: true,
            child: Column(
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 10),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                TextField(controller: _proof, decoration: const InputDecoration(labelText: 'Proof of ownership'), maxLines: 4),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HallaqButton(
            label: _proofImage == null ? 'Upload proof image' : 'Change proof image',
            variant: HallaqButtonVariant.secondary,
            icon: Icons.upload_file_rounded,
            onPressed: _busy ? null : _pickProof,
          ),
          const SizedBox(height: 12),
          HallaqButton(
            label: 'Submit claim',
            icon: Icons.check_rounded,
            isLoading: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

final _shopProvider = FutureProvider.family((ref, String id) async {
  return ref.watch(shopRepositoryProvider).getById(id);
});

