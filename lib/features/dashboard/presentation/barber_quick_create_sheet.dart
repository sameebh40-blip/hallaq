import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_ui.dart';

enum BarberQuickCreateAction {
  uploadReel,
  addPortfolio,
  blockTime,
  addService,
  createOffer,
}

class BarberQuickCreateSheet extends StatelessWidget {
  const BarberQuickCreateSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: HallaqCard(
          glass: true,
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Quick Create', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              _ActionRow(
                icon: Icons.upload_file_rounded,
                label: 'Upload Reel',
                subtitle: 'Post a new reel to Discover',
                onTap: () => Navigator.of(context).pop(BarberQuickCreateAction.uploadReel),
              ),
              _ActionRow(
                icon: Icons.photo_library_outlined,
                label: 'Add Portfolio',
                subtitle: 'Upload your latest work',
                onTap: () => Navigator.of(context).pop(BarberQuickCreateAction.addPortfolio),
              ),
              _ActionRow(
                icon: Icons.block_rounded,
                label: 'Block Time',
                subtitle: 'Take a break or go on vacation',
                onTap: () => Navigator.of(context).pop(BarberQuickCreateAction.blockTime),
              ),
              _ActionRow(
                icon: Icons.design_services_outlined,
                label: 'Add Service',
                subtitle: 'Create or enable a service',
                onTap: () => Navigator.of(context).pop(BarberQuickCreateAction.addService),
              ),
              _ActionRow(
                icon: Icons.local_offer_outlined,
                label: 'Create Offer',
                subtitle: 'Send a premium offer to clients',
                onTap: () => Navigator.of(context).pop(BarberQuickCreateAction.createOffer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: false,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppTheme.gold.withValues(alpha: 0.12),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, color: AppTheme.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

