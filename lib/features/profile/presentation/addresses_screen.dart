import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../data/profile_addresses_repository.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(myAddressesProvider);

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Addresses', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showEditor(context, ref),
                    child: Text('Add', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncValueWidget(
                value: addresses,
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('No addresses yet', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text(
                              'Add your preferred addresses for a faster checkout experience.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 44,
                              child: FilledButton(
                                onPressed: () => _showEditor(context, ref),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.gold,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text('Add Address', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                    itemBuilder: (context, index) {
                      final a = items[index];
                      return _AddressTile(
                        address: a,
                        onEdit: () => _showEditor(context, ref, existing: a),
                        onDelete: () async {
                          try {
                            await ref.read(profileAddressesRepositoryProvider).remove(a.id);
                          } catch (e) {
                            if (context.mounted) showErrorSnackBar(context, e);
                          }
                        },
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: items.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, WidgetRef ref, {ProfileAddress? existing}) async {
    final label = TextEditingController(text: existing?.label ?? '');
    final line1 = TextEditingController(text: existing?.line1 ?? '');
    final line2 = TextEditingController(text: existing?.line2 ?? '');
    final city = TextEditingController(text: existing?.city ?? '');
    final country = TextEditingController(text: existing?.country ?? '');
    bool isDefault = existing?.isDefault ?? false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.softShadow(opacity: 0.12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(existing == null ? 'Add Address' : 'Edit Address', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                            ),
                            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Field(label: 'Label', controller: label),
                        const SizedBox(height: 10),
                        _Field(label: 'Address Line 1', controller: line1),
                        const SizedBox(height: 10),
                        _Field(label: 'Address Line 2', controller: line2),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _Field(label: 'City', controller: city)),
                            const SizedBox(width: 10),
                            Expanded(child: _Field(label: 'Country', controller: country)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setModalState(() => isDefault = !isDefault),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: isDefault ? AppTheme.gold : Colors.white,
                                  border: Border.all(color: isDefault ? AppTheme.gold : AppTheme.border),
                                ),
                                child: isDefault ? const Icon(Icons.check_rounded, size: 16, color: Colors.black) : null,
                              ),
                              const SizedBox(width: 10),
                              Text('Set as default', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: () async {
                              try {
                                await ref.read(profileAddressesRepositoryProvider).upsert(
                                      id: existing?.id,
                                      label: label.text,
                                      line1: line1.text,
                                      line2: line2.text,
                                      city: city.text,
                                      country: country.text,
                                      isDefault: isDefault,
                                    );
                                if (context.mounted) Navigator.of(context).pop();
                              } catch (e) {
                                if (context.mounted) showErrorSnackBar(context, e);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Save', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddressTile extends StatelessWidget {
  final ProfileAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressTile({required this.address, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final lines = [
      address.line1,
      if ((address.line2 ?? '').trim().isNotEmpty) address.line2!.trim(),
      [
        if ((address.city ?? '').trim().isNotEmpty) address.city!.trim(),
        if ((address.country ?? '').trim().isNotEmpty) address.country!.trim(),
      ].join(', ').trim(),
    ].where((e) => e.trim().isNotEmpty).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.08),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on_outlined, color: AppTheme.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(address.label.isEmpty ? 'Address' : address.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
                    if (address.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Default', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.goldDeep, fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  lines.join('\n'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.error)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _Field({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.55))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

