import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../network/network_status.dart';

class LuxuryScaffold extends ConsumerWidget {
  final Widget child;
  final Widget? header;
  final Widget? bottom;
  final bool safeBottom;

  const LuxuryScaffold({
    super.key,
    required this.child,
    this.header,
    this.bottom,
    this.safeBottom = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(networkStatusProvider);
    final bannerText = switch (q) {
      NetworkQuality.offline => 'Offline. Showing saved data.',
      NetworkQuality.poor => 'Poor connection. Showing saved data.',
      _ => null,
    };

    return Scaffold(
      extendBody: false,
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppTheme.background)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (bannerText != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111).withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 18, color: AppTheme.gold),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bannerText,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (header != null) header!,
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottom == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SafeArea(
                top: false,
                bottom: safeBottom,
                child: bottom!,
              ),
            ),
    );
  }
}

class LuxuryTopBar extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? trailing;

  const LuxuryTopBar({super.key, this.leading, this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          SizedBox(width: 44, child: Align(alignment: Alignment.centerLeft, child: leading)),
          Expanded(child: Center(child: title)),
          SizedBox(width: 44, child: Align(alignment: Alignment.centerRight, child: trailing)),
        ],
      ),
    );
  }
}

 
