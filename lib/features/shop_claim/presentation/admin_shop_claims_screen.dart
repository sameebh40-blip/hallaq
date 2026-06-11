import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/shop_claim_repository.dart';

final _pendingClaimsProvider = FutureProvider<List<ShopClaimRequest>>((ref) async {
  return ref.watch(shopClaimRepositoryProvider).listPending();
});

class AdminShopClaimsScreen extends ConsumerWidget {
  const AdminShopClaimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(_pendingClaimsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Shop claims', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget<List<ShopClaimRequest>>(
        value: value,
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No pending requests'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            itemBuilder: (_, i) => _ClaimCard(req: items[i]),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}

class _ClaimCard extends ConsumerStatefulWidget {
  final ShopClaimRequest req;

  const _ClaimCard({required this.req});

  @override
  ConsumerState<_ClaimCard> createState() => _ClaimCardState();
}

class _ClaimCardState extends ConsumerState<_ClaimCard> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await ref.read(shopClaimRepositoryProvider).approve(widget.req.id);
      ref.invalidate(_pendingClaimsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved')));
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: HallaqCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Reject reason', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                    LuxuryIconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(labelText: 'Reason (optional)')),
                const SizedBox(height: 12),
                HallaqButton(
                  label: 'Reject',
                  icon: Icons.block_rounded,
                  onPressed: () => Navigator.of(context).pop(controller.text.trim().isEmpty ? null : controller.text.trim()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    setState(() => _busy = true);
    try {
      await ref.read(shopClaimRepositoryProvider).reject(widget.req.id, reason: reason);
      ref.invalidate(_pendingClaimsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected')));
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.req;
    return HallaqCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if ((r.phone ?? '').isNotEmpty) Text('Phone: ${r.phone}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          if ((r.email ?? '').isNotEmpty) Text('Email: ${r.email}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Text('Shop: ${r.shopId}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          if ((r.proofText ?? '').isNotEmpty) Text(r.proofText!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HallaqButton(
                  label: 'Reject',
                  variant: HallaqButtonVariant.secondary,
                  icon: Icons.block_rounded,
                  onPressed: _busy ? null : _reject,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HallaqButton(
                  label: 'Approve',
                  icon: Icons.check_rounded,
                  onPressed: _busy ? null : _approve,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

