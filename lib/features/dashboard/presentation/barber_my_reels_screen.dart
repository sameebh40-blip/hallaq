import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/reel.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../explore/data/reels_repository.dart';
import '../../../core/routing/routes.dart';

class BarberMyReelsScreen extends ConsumerWidget {
  const BarberMyReelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myBarberReelsManageProvider);

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Reels', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        trailing: LuxuryIconButton(icon: Icons.add_rounded, onPressed: () => context.push(Routes.barberUploadReel)),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Published'),
                Tab(text: 'Pending'),
                Tab(text: 'Rejected'),
              ],
            ),
            Expanded(
              child: AsyncValueWidget<List<Reel>>(
                value: value,
                data: (items) {
                  final published = items.where((e) => e.status == 'approved').toList(growable: false);
                  final pending = items.where((e) => e.status == 'pending').toList(growable: false);
                  final rejected = items.where((e) => e.status == 'rejected').toList(growable: false);

                  return TabBarView(
                    children: [
                      _ReelsList(items: published),
                      _ReelsList(items: pending),
                      _ReelsList(items: rejected),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelsList extends StatelessWidget {
  final List<Reel> items;

  const _ReelsList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: HallaqEmptyState(
          title: 'No reels here',
          description: 'Upload a reel to start reaching more customers.',
          compact: true,
          showMascot: true,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: items.map((r) => _ReelRow(reel: r)).toList(),
    );
  }
}

class _ReelRow extends ConsumerWidget {
  final Reel reel;

  const _ReelRow({required this.reel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbPath = (reel.thumbnailPath ?? '').trim();
    final thumbUrl = (reel.thumbnailUrl ?? '').trim();
    final mediaPath = (reel.mediaPath ?? '').trim();
    final mediaUrl = reel.mediaUrl.trim();
    final thumb = thumbPath.isNotEmpty
        ? thumbPath
        : thumbUrl.isNotEmpty
            ? thumbUrl
            : reel.mediaType == 'image'
                ? (mediaPath.isNotEmpty ? mediaPath : mediaUrl)
                : '';
    final caption = (reel.caption ?? '').trim().isEmpty ? 'Reel' : (reel.caption ?? '').trim();
    final meta = '${reel.likesCount} likes · ${reel.commentsCount} comments · ${reel.savesCount} saves';
    final date = DateFormat('MMM d, yyyy').format(reel.createdAt.toLocal());
    final rejection = (reel.rejectionReason ?? '').trim();

    Future<void> edit() async {
      final updated = await showModalBottomSheet<({String caption, String location, String hashtags})>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _EditReelSheet(
          caption: reel.caption ?? '',
          location: reel.location ?? '',
          hashtags: reel.hashtags.map((e) => '#$e').join(' '),
        ),
      );
      if (updated == null || !context.mounted) return;
      final tags = updated.hashtags
          .split(RegExp(r'[,\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e.startsWith('#') ? e.substring(1) : e)
          .toList(growable: false);
      await ref.read(reelsRepositoryProvider).update(reelId: reel.id, caption: updated.caption, location: updated.location, hashtags: tags);
      ref.invalidate(myBarberReelsManageProvider);
    }

    Future<void> remove() async {
      await ref.read(reelsRepositoryProvider).softDelete(reel.id);
      ref.invalidate(myBarberReelsManageProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HallaqCard(
        glass: true,
        onTap: edit,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 74,
                height: 74,
                child: LuxuryNetworkImage(
                  imageUrl: thumb,
                  fallbackUrl: '',
                  bucket: 'reels',
                  borderRadius: BorderRadius.zero,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(meta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                  if (reel.status == 'rejected' && rejection.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(rejection, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.error)),
                  ],
                ],
              ),
            ),
            IconButton(onPressed: remove, icon: const Icon(Icons.delete_outline_rounded), color: AppTheme.textMuted),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EditReelSheet extends StatefulWidget {
  final String caption;
  final String location;
  final String hashtags;

  const _EditReelSheet({required this.caption, required this.location, required this.hashtags});

  @override
  State<_EditReelSheet> createState() => _EditReelSheetState();
}

class _EditReelSheetState extends State<_EditReelSheet> {
  late final TextEditingController _caption;
  late final TextEditingController _location;
  late final TextEditingController _hashtags;

  @override
  void initState() {
    super.initState();
    _caption = TextEditingController(text: widget.caption);
    _location = TextEditingController(text: widget.location);
    _hashtags = TextEditingController(text: widget.hashtags);
  }

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    _hashtags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: HallaqCard(
          glass: true,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit reel', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(controller: _caption, decoration: const InputDecoration(labelText: 'Caption'), maxLines: 2),
                const SizedBox(height: 12),
                TextField(controller: _hashtags, decoration: const InputDecoration(labelText: 'Hashtags'), maxLines: 1),
                const SizedBox(height: 12),
                TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location'), maxLines: 1),
                const SizedBox(height: 14),
                HallaqButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop((caption: _caption.text, location: _location.text, hashtags: _hashtags.text)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
