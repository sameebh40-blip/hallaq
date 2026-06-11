import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/last_error.dart';
import '../../../core/models/role.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../profile/data/profile_repository.dart';
import '../../barber/data/barber_repository.dart';
import '../../shop/data/shop_repository.dart';

class DebugPanelScreen extends ConsumerWidget {
  const DebugPanelScreen({super.key});

  Future<void> _copy(BuildContext context, String value) async {
    final v = value.trim();
    if (v.isEmpty || v == '—') return;
    await Clipboard.setData(ClipboardData(text: v));
    if (context.mounted) showSuccessSnackBar(context, 'Copied');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final session = client.auth.currentSession;

    final profileValue = ref.watch(myProfileProvider);
    final shopValue = ref.watch(myShopProvider);
    final barberValue = ref.watch(myBarberProvider);
    final lastError = ref.watch(lastErrorProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => Navigator.of(context).pop()),
        title: Text('Debug Panel', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          HallaqCard(
            glass: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Row(label: 'UID', value: session?.user.id ?? '—', onCopy: (v) => _copy(context, v)),
                const SizedBox(height: 10),
                _Row(label: 'Email', value: session?.user.email ?? '—', onCopy: (v) => _copy(context, v)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AsyncValueWidget(
            value: profileValue,
            data: (p) {
              final role = p?.role ?? AppUserRole.customer;
              return HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Row(label: 'Role', value: role.toDb(), onCopy: (v) => _copy(context, v)),
                    const SizedBox(height: 10),
                    _Row(label: 'Verified', value: '${p?.verified ?? false}', onCopy: (v) => _copy(context, v)),
                    const SizedBox(height: 10),
                    _Row(label: 'Profile ID', value: p?.id ?? '—', onCopy: (v) => _copy(context, v)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          AsyncValueWidget(
            value: shopValue,
            data: (s) {
              return HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Row(label: 'Shop ID', value: s?.id ?? '—', onCopy: (v) => _copy(context, v)),
                    const SizedBox(height: 10),
                    _Row(label: 'Shop owner_profile_id', value: s?.ownerProfileId ?? '—', onCopy: (v) => _copy(context, v)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          AsyncValueWidget(
            value: barberValue,
            data: (b) {
              return HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Row(label: 'Barber ID', value: b?.id ?? '—', onCopy: (v) => _copy(context, v)),
                    const SizedBox(height: 10),
                    _Row(label: 'Barber profile_id', value: b?.profileId ?? '—', onCopy: (v) => _copy(context, v)),
                    const SizedBox(height: 10),
                    _Row(label: 'Barber shop_id', value: b?.shopId ?? '—', onCopy: (v) => _copy(context, v)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          HallaqCard(
            glass: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Last error', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (lastError == null) const Text('—') else SelectableText(lastError.toString()),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: lastError == null
                            ? null
                            : () async {
                                final details = lastError.toString();
                                await Clipboard.setData(ClipboardData(text: details));
                                if (context.mounted) showSuccessSnackBar(context, 'Copied');
                              },
                        child: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => ref.read(lastErrorProvider.notifier).state = null,
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String>? onCopy;

  const _Row({required this.label, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(child: SelectableText(value, textAlign: TextAlign.end)),
              if (onCopy != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: value.trim().isEmpty || value == '—' ? null : () => onCopy!.call(value),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
