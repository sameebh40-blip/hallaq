import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../payments/data/earnings_repository.dart';
import '../../../core/supabase/supabase_client_provider.dart';

final _barberEarningsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(earningsRepositoryProvider).listBarberDaily(barber.id, days: 30);
});

final _barberPaymentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final barber = await ref.watch(myBarberProvider.future);
  if (barber == null) return const [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('payments')
      .select('id, amount, currency, status, created_at, captured_at, booking_id, payer_profile_id, profiles(full_name, avatar_url, avatar_path), bookings(start_at, service_id, services(name_en, name))')
      .eq('payee_type', 'barber')
      .eq('payee_id', barber.id)
      .order('created_at', ascending: false)
      .limit(60);
  return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
});

class BarberEarningsScreen extends ConsumerWidget {
  const BarberEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(_barberEarningsProvider);
    final payments = ref.watch(_barberPaymentsProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Wallet', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(
          icon: Icons.ios_share_rounded,
          onPressed: () async {
            final rows = payments.valueOrNull ?? const <Map<String, dynamic>>[];
            final picked = await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              backgroundColor: Colors.transparent,
              builder: (context) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: HallaqCard(
                      glass: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HallaqCard(
                            glass: true,
                            onTap: () => Navigator.of(context).pop('pdf'),
                            child: const Row(
                              children: [
                                Icon(Icons.picture_as_pdf_outlined),
                                SizedBox(width: 10),
                                Expanded(child: Text('Export PDF')),
                                Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          HallaqCard(
                            glass: true,
                            onTap: () => Navigator.of(context).pop('csv'),
                            child: const Row(
                              children: [
                                Icon(Icons.table_chart_outlined),
                                SizedBox(width: 10),
                                Expanded(child: Text('Export CSV')),
                                Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
            if (picked == null) return;

            final dir = Directory.systemTemp.createTempSync('hallaq_wallet_');
            if (picked == 'csv') {
              final csv = _buildWalletCsv(rows);
              final file = File('${dir.path}/wallet_report.csv');
              await file.writeAsString(csv, flush: true);
              await Share.shareXFiles([XFile(file.path)], text: 'Hallaq Wallet Report (CSV)');
              return;
            }

            final bytes = _buildSimplePdfBytes(_buildWalletReportText(rows));
            final file = File('${dir.path}/wallet_report.pdf');
            await file.writeAsBytes(bytes, flush: true);
            await Share.shareXFiles([XFile(file.path)], text: 'Hallaq Wallet Report (PDF)');
          },
        ),
      ),
      child: AsyncValueWidget<List<Map<String, dynamic>>>(
        value: value,
        data: (rows) {
          final currency = rows.isEmpty ? 'BHD' : (rows.first['currency'] as String? ?? 'BHD');
          final total30d = rows.fold<double>(0, (s, r) => s + ((r['gross_revenue'] as num?)?.toDouble() ?? 0));
          final now = DateTime.now();
          final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
          final monthTotal = rows
              .where((r) => (r['day']?.toString() ?? '').startsWith(monthKey))
              .fold<double>(0, (s, r) => s + ((r['gross_revenue'] as num?)?.toDouble() ?? 0));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            children: [
              Text('Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              AsyncValueWidget(
                value: payments,
                data: (tx) {
                  final completed = tx.where((e) => (e['status'] as String?) == 'succeeded').fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
                  final pending = tx.where((e) => (e['status'] as String?) == 'pending').fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.45,
                    ),
                    children: [
                      _WalletStat(title: 'Total Earnings', value: 'BD ${completed.toStringAsFixed(3)}', icon: Icons.account_balance_wallet_rounded),
                      _WalletStat(title: 'Pending Earnings', value: 'BD ${pending.toStringAsFixed(3)}', icon: Icons.timelapse_rounded),
                      _WalletStat(title: 'Monthly Earnings', value: 'BD ${monthTotal.toStringAsFixed(3)}', icon: Icons.calendar_month_rounded),
                      _WalletStat(title: '30 Day Earnings', value: 'BD ${total30d.toStringAsFixed(3)}', icon: Icons.trending_up_rounded),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Text('Daily Revenue', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                HallaqEmptyState(
                  title: 'No earnings yet',
                  description: 'Revenue will appear after payments are captured.',
                  compact: true,
                  showMascot: true,
                )
              else
                ...rows.take(30).map((r) {
                  final day = r['day']?.toString() ?? '';
                  final amount = ((r['gross_revenue'] as num?)?.toDouble() ?? 0);
                  final count = (r['payments_count'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: HallaqCard(
                      glass: true,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(day, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                Text('$count payments', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          Text('${amount.toStringAsFixed(3)} $currency', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 18),
              Text('Transactions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              AsyncValueWidget(
                value: payments,
                data: (tx) {
                  if (tx.isEmpty) {
                    return HallaqEmptyState(
                      title: 'No transactions yet',
                      description: 'Transactions will appear here after payments.',
                      compact: true,
                      showMascot: true,
                    );
                  }
                  return Column(
                    children: tx.map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _TxRow(row: t, currency: currency))).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _WalletStat({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppTheme.goldGradient,
              boxShadow: AppTheme.softShadow(opacity: 0.35),
            ),
            child: Icon(icon, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted)),
                const SizedBox(height: 6),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final String currency;

  const _TxRow({required this.row, required this.currency});

  @override
  Widget build(BuildContext context) {
    final amount = ((row['amount'] as num?)?.toDouble() ?? 0);
    final status = (row['status'] as String?) ?? 'pending';
    final profile = (row['profiles'] is Map) ? Map<String, dynamic>.from(row['profiles'] as Map) : null;
    final name = (profile?['full_name'] as String?) ?? 'Customer';
    final createdAt = (row['created_at'] as String?) ?? '';
    final label = status == 'succeeded' ? 'Completed' : status == 'pending' ? 'Pending' : status;

    return HallaqCard(
      glass: true,
      child: Row(
        children: [
          HallaqAvatar(imageUrl: profile?['avatar_url'] as String?, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(createdAt.substring(0, createdAt.length.clamp(0, 10)), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ],
            ),
          ),
          Text('${amount.toStringAsFixed(3)} $currency', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

String _buildWalletReportText(List<Map<String, dynamic>> rows) {
  final buf = StringBuffer();
  buf.writeln('Hallaq Wallet Report');
  buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buf.writeln('');
  for (final r in rows) {
    final id = (r['id'] as String?) ?? '';
    final amount = ((r['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(3);
    final currency = (r['currency'] as String?) ?? 'BHD';
    final status = (r['status'] as String?) ?? '';
    final createdAt = (r['created_at'] as String?) ?? '';
    buf.writeln('$createdAt | $status | $amount $currency | $id');
  }
  return buf.toString();
}

String _buildWalletCsv(List<Map<String, dynamic>> rows) {
  String esc(String v) {
    final s = v.replaceAll('"', '""');
    return '"$s"';
  }

  final buf = StringBuffer();
  buf.writeln('created_at,status,amount,currency,id');
  for (final r in rows) {
    final id = (r['id'] as String?) ?? '';
    final amount = ((r['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(3);
    final currency = (r['currency'] as String?) ?? 'BHD';
    final status = (r['status'] as String?) ?? '';
    final createdAt = (r['created_at'] as String?) ?? '';
    buf.writeln('${esc(createdAt)},${esc(status)},${esc(amount)},${esc(currency)},${esc(id)}');
  }
  return buf.toString();
}

Uint8List _buildSimplePdfBytes(String text) {
  final safe = text.replaceAll(RegExp(r'[^\\x20-\\x7E\\n\\r]'), '');
  final lines = safe.split('\n').take(55).toList(growable: false);
  final content = StringBuffer();
  content.writeln('BT');
  content.writeln('/F1 11 Tf');
  content.writeln('72 760 Td');
  for (final line in lines) {
    final escaped = line.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)');
    content.writeln('($escaped) Tj');
    content.writeln('T*');
  }
  content.writeln('ET');
  final stream = content.toString();
  final objects = <String>[
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj',
    '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj',
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj',
    '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
    '5 0 obj << /Length ${stream.length} >> stream\n$stream\nendstream endobj',
  ];
  final buffer = StringBuffer();
  buffer.writeln('%PDF-1.4');
  final offsets = <int>[0];
  for (final obj in objects) {
    offsets.add(buffer.length);
    buffer.writeln(obj);
  }
  final xrefStart = buffer.length;
  buffer.writeln('xref');
  buffer.writeln('0 ${objects.length + 1}');
  buffer.writeln('0000000000 65535 f ');
  for (var i = 1; i <= objects.length; i++) {
    final off = offsets[i].toString().padLeft(10, '0');
    buffer.writeln('$off 00000 n ');
  }
  buffer.writeln('trailer << /Size ${objects.length + 1} /Root 1 0 R >>');
  buffer.writeln('startxref');
  buffer.writeln(xrefStart);
  buffer.writeln('%%EOF');
  return Uint8List.fromList(buffer.toString().codeUnits);
}
