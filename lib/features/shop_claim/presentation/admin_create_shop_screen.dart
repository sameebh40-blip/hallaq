import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/shop_claim_repository.dart';

class AdminCreateShopScreen extends ConsumerStatefulWidget {
  const AdminCreateShopScreen({super.key});

  @override
  ConsumerState<AdminCreateShopScreen> createState() => _AdminCreateShopScreenState();
}

class _AdminCreateShopScreenState extends ConsumerState<AdminCreateShopScreen> {
  final _ownerProfileId = TextEditingController();
  final _name = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ownerProfileId.dispose();
    _name.dispose();
    _area.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_ownerProfileId.text.trim().isEmpty) {
      showErrorSnackBar(context, const AppException('Owner profile id is required'));
      return;
    }
    if (_name.text.trim().isEmpty) {
      showErrorSnackBar(context, const AppException('Name is required'));
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref.read(shopClaimRepositoryProvider).createShopAsAdmin(
            name: _name.text.trim(),
            ownerProfileId: _ownerProfileId.text.trim(),
            area: _area.text.trim().isEmpty ? null : _area.text.trim(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop created')));
      if (id != null) context.pop(id);
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
        title: Text('Create shop', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          HallaqCard(
            glass: true,
            child: Column(
              children: [
                TextField(controller: _ownerProfileId, decoration: const InputDecoration(labelText: 'Owner profile id')),
                const SizedBox(height: 10),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Shop name')),
                const SizedBox(height: 10),
                TextField(controller: _area, decoration: const InputDecoration(labelText: 'Area')),
                const SizedBox(height: 10),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 10),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HallaqButton(
            label: 'Create',
            icon: Icons.add_rounded,
            isLoading: _busy,
            onPressed: _busy ? null : _create,
          ),
        ],
      ),
    );
  }
}
