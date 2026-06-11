import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_loader.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/role.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../profile/data/profile_repository.dart';

enum HealthStatus { working, warning, broken }

class HealthItem {
  final String label;
  final HealthStatus status;
  final String detail;

  const HealthItem({required this.label, required this.status, required this.detail});
}

class BuildHealthReport {
  final EnvLoadResult env;
  final List<HealthItem> items;
  final String sessionEmail;
  final AppUserRole role;

  const BuildHealthReport({
    required this.env,
    required this.items,
    required this.sessionEmail,
    required this.role,
  });
}

final buildHealthReportProvider = FutureProvider.autoDispose<BuildHealthReport>((ref) async {
  final env = await EnvLoader.load();
  final client = ref.watch(supabaseClientProvider);
  final media = ref.watch(mediaServiceProvider);
  final session = client.auth.currentSession;
  final user = client.auth.currentUser;

  HealthItem item(String label, HealthStatus status, String detail) => HealthItem(label: label, status: status, detail: detail);

  final urlOk = env.hasUrl && !env.env.supabaseUrl.contains('YOUR_PROJECT');
  final keyOk = env.hasAnonKey && !env.env.supabaseAnonKey.contains('YOUR_ANON_KEY');

  final items = <HealthItem>[
    item('Supabase URL loaded', urlOk ? HealthStatus.working : HealthStatus.broken, 'length=${env.urlLength} source=${env.source}'),
    item('Anon key loaded', keyOk ? HealthStatus.working : HealthStatus.broken, 'length=${env.anonKeyLength} source=${env.source}'),
  ];

  try {
    Supabase.instance.client;
    items.add(item('Supabase initialized', HealthStatus.working, 'ok'));
  } catch (e) {
    items.add(item('Supabase initialized', HealthStatus.broken, e.toString()));
  }

  if (session == null) {
    items.add(item('Auth connected', HealthStatus.warning, 'no session'));
  } else {
    items.add(item('Auth connected', HealthStatus.working, 'session ok'));
  }

  Future<void> checkTable(String table, {String column = 'id', String label = ''}) async {
    final name = label.trim().isEmpty ? table : label;
    try {
      await client.from(table).select(column).limit(1).timeout(const Duration(seconds: 6));
      items.add(item('Table $name', HealthStatus.working, 'read ok'));
    } catch (e) {
      final msg = e.toString();
      final status = msg.contains('42501') || msg.toLowerCase().contains('permission') ? HealthStatus.warning : HealthStatus.broken;
      items.add(item('Table $name', status, msg));
    }
  }

  if (user == null) {
    items.add(item('Database connected', HealthStatus.warning, 'login required'));
    items.add(item('Storage connected', HealthStatus.warning, 'login required'));
    items.add(item('Realtime ready', HealthStatus.warning, 'login required'));
    items.add(item('Core tables', HealthStatus.warning, 'login required'));
  } else {
    try {
      await client.from('profiles').select('id').eq('id', user.id).maybeSingle().timeout(const Duration(seconds: 6));
      items.add(item('Database connected', HealthStatus.working, 'query ok'));
    } catch (e) {
      items.add(item('Database connected', HealthStatus.broken, e.toString()));
    }

    try {
      final url = await media.resolveMediaUrl(bucket: 'brand-assets', path: '', legacyUrlOrPath: '');
      items.add(item('Storage connected', HealthStatus.working, url == null ? 'no object' : 'ok'));
    } catch (e) {
      final msg = e.toString();
      final status = msg.contains('403') || msg.toLowerCase().contains('permission') ? HealthStatus.warning : HealthStatus.broken;
      items.add(item('Storage connected', status, msg));
    }

    try {
      final ch = client.channel('rt_build_health_${user.id}').subscribe();
      client.removeChannel(ch);
      items.add(item('Realtime ready', HealthStatus.working, 'subscribe ok'));
    } catch (e) {
      items.add(item('Realtime ready', HealthStatus.broken, e.toString()));
    }

    await checkTable('bookings', label: 'bookings');
    await checkTable('booking_overview', label: 'booking_overview');
    await checkTable('posts', label: 'posts');
    await checkTable('notifications', label: 'notifications');
    await checkTable('offer_targets', label: 'offer_targets');
    await checkTable('feature_flags', label: 'feature_flags');
  }

  final profileValue = await ref.watch(myProfileProvider.future);
  final role = profileValue?.role ?? AppUserRole.unknown;
  if (user == null) {
    items.add(item('Current user role', HealthStatus.warning, 'no session'));
  } else if (profileValue == null) {
    items.add(item('Current user role', HealthStatus.warning, 'profile missing'));
  } else {
    items.add(item('Current user role', HealthStatus.working, role.toDb()));
  }

  return BuildHealthReport(
    env: env,
    items: items,
    sessionEmail: session?.user.email ?? '—',
    role: role,
  );
});

class BuildHealthScreen extends ConsumerWidget {
  const BuildHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportValue = ref.watch(buildHealthReportProvider);
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => Navigator.of(context).pop()),
        title: Text('Build Health', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(
          icon: Icons.refresh_rounded,
          onPressed: () => ref.invalidate(buildHealthReportProvider),
        ),
      ),
      child: AsyncValueWidget(
        value: reportValue,
        data: (report) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            children: [
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Row(label: 'Session', value: report.sessionEmail),
                    const SizedBox(height: 10),
                    _Row(label: 'Role', value: report.role.toDb()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final i in report.items) ...[
                _HealthTile(item: i),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: () => ref.invalidate(buildHealthReportProvider),
                child: const Text('Retry'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  final HealthItem item;

  const _HealthTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.status) {
      HealthStatus.working => (Icons.check_circle_rounded, Colors.green),
      HealthStatus.warning => (Icons.warning_rounded, Colors.orange),
      HealthStatus.broken => (Icons.error_rounded, Colors.red),
    };

    return HallaqCard(
      glass: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(item.detail, style: Theme.of(context).textTheme.bodySmall),
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

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    );
  }
}
