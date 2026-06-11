import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/models/reel.dart';
import '../../../core/media/video_transcode_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../explore/data/reels_repository.dart';
import 'barber_reel_controller.dart';

class BarberUploadReelScreen extends ConsumerStatefulWidget {
  final String? draftId;

  const BarberUploadReelScreen({super.key, this.draftId});

  @override
  ConsumerState<BarberUploadReelScreen> createState() => _BarberUploadReelScreenState();
}

class _BarberUploadReelScreenState extends ConsumerState<BarberUploadReelScreen> {
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _hashtags = TextEditingController();
  String _mediaType = 'image';
  bool _seeded = false;

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    _hashtags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const maxVideoBytes = 50 * 1024 * 1024;
    final barberValue = ref.watch(myBarberProvider);
    final controller = ref.watch(barberReelControllerProvider);
    final draftValue = (widget.draftId ?? '').trim().isEmpty ? const AsyncValue.data(null) : ref.watch(_draftProvider(widget.draftId!.trim()));

    ref.listen(barberReelControllerProvider, (_, next) {
      next.whenOrNull(error: (e, __) => showErrorSnackBar(context, e));
      next.whenOrNull(data: (_) => showSuccessSnackBar(context, 'Saved'));
    });

    Future<List<String>> parseHashtags() async {
      return _hashtags.text
          .split(RegExp(r'[,\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e.startsWith('#') ? e.substring(1) : e)
          .toList(growable: false);
    }

    Future<void> upload({required bool asDraft}) async {
      final barber = await ref.read(myBarberProvider.future);
      if (barber == null) return;

      final hashtags = await parseHashtags();

      final picker = ImagePicker();
      if (_mediaType == 'video') {
        final video = await picker.pickVideo(source: ImageSource.gallery);
        if (video == null) return;
        if (!context.mounted) return;
        try {
          final d = await ref.read(videoTranscodeServiceProvider).readDurationMs(video.path);
          if (d != null && d > 20 * 1000) {
            showErrorSnackBar(context, 'Video must be 20 seconds or less.');
            return;
          }
        } catch (_) {}
        if (!context.mounted) return;

        final pickThumb = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Add thumbnail?'),
              content: const Text('Optional. If skipped, we will generate one automatically when possible.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Skip')),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Pick')),
              ],
            );
          },
        );

        Uint8List? thumbBytes;
        if (pickThumb == true) {
          final thumb = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
          final raw = thumb == null ? null : await thumb.readAsBytes();
          thumbBytes = raw;
        }

        final videoBytes = await ref.read(videoTranscodeServiceProvider).transcodeToMp4_720p(inputPath: video.path);
        if (videoBytes.lengthInBytes > maxVideoBytes) {
          if (!context.mounted) return;
          showErrorSnackBar(context, 'Video is still too large after compression. Please choose a shorter video.');
          return;
        }
        await ref.read(barberReelControllerProvider.notifier).uploadVideoReel(
              videoBytes: videoBytes,
              videoContentType: 'video/mp4',
              thumbnailBytes: thumbBytes,
              caption: _caption.text,
              location: _location.text,
              hashtags: hashtags,
              asDraft: asDraft,
              draftId: widget.draftId,
            );
        return;
      }

      final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
      if (img == null) return;
      final bytes = await img.readAsBytes();
      await ref.read(barberReelControllerProvider.notifier).uploadImageReel(
            bytes: bytes,
            caption: _caption.text,
            location: _location.text,
            hashtags: hashtags,
            asDraft: asDraft,
            draftId: widget.draftId,
          );
    }

    Future<void> publishDraft() async {
      final draftId = (widget.draftId ?? '').trim();
      if (draftId.isEmpty) return;
      final hashtags = await parseHashtags();
      await ref.read(barberReelControllerProvider.notifier).publishDraft(
            draftId: draftId,
            caption: _caption.text,
            location: _location.text,
            hashtags: hashtags,
          );
      if (!context.mounted) return;
      context.pop();
    }

    Future<void> deleteDraft() async {
      final draftId = (widget.draftId ?? '').trim();
      if (draftId.isEmpty) return;
      await ref.read(barberReelControllerProvider.notifier).deleteDraft(draftId);
      if (!context.mounted) return;
      context.pop();
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Upload reel', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      child: AsyncValueWidget(
        value: barberValue,
        data: (barber) {
          if (barber == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: HallaqCard(glass: true, child: Text('No barber assigned to this account.')),
            );
          }

          return AsyncValueWidget(
            value: draftValue,
            data: (draft) {
              if (!_seeded && draft != null) {
                _caption.text = (draft.caption ?? '').trim();
                _location.text = (draft.location ?? '').trim();
                _hashtags.text = draft.hashtags.map((e) => '#$e').join(' ');
                _mediaType = draft.mediaType;
                _seeded = true;
              } else if (!_seeded) {
                _seeded = true;
              }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            children: [
              HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (draft != null) ...[
                      Text('Draft', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: 160,
                          child: LuxuryNetworkImage(
                            imageUrl: (draft.thumbnailUrl ?? '').trim().isEmpty ? draft.mediaUrl : (draft.thumbnailUrl ?? '').trim(),
                            fallbackUrl: '',
                            bucket: 'reels',
                            borderRadius: BorderRadius.zero,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text('Media type', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: controller.isLoading ? null : () => setState(() => _mediaType = 'image'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _mediaType == 'image' ? AppTheme.gold.withValues(alpha: 0.12) : null,
                            ),
                            child: const Text('Image'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: controller.isLoading ? null : () => setState(() => _mediaType = 'video'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _mediaType == 'video' ? AppTheme.gold.withValues(alpha: 0.12) : null,
                            ),
                            child: const Text('Video'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _caption,
                      decoration: const InputDecoration(labelText: 'Caption (optional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _location,
                      decoration: const InputDecoration(labelText: 'Location (optional)'),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hashtags,
                      decoration: const InputDecoration(labelText: 'Hashtags (comma or space separated)'),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 14),
                    if (draft != null) ...[
                      LuxuryButton(
                        label: 'Publish draft',
                        isLoading: controller.isLoading,
                        onPressed: controller.isLoading ? null : publishDraft,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: controller.isLoading ? null : () => upload(asDraft: false),
                        child: Text(_mediaType == 'video' ? 'Replace with new video' : 'Replace with new image'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: controller.isLoading ? null : () => upload(asDraft: true),
                        child: Text(_mediaType == 'video' ? 'Update draft (pick video)' : 'Update draft (pick image)'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: controller.isLoading ? null : deleteDraft,
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                        child: const Text('Delete draft'),
                      ),
                    ] else ...[
                      LuxuryButton(
                        label: _mediaType == 'video' ? 'Publish (pick video)' : 'Publish (pick image)',
                        isLoading: controller.isLoading,
                        onPressed: controller.isLoading ? null : () => upload(asDraft: false),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: controller.isLoading ? null : () => upload(asDraft: true),
                        child: Text(_mediaType == 'video' ? 'Save draft (pick video)' : 'Save draft (pick image)'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
            },
          );
        },
      ),
    );
  }
}

final _draftProvider = FutureProvider.autoDispose.family<Reel?, String>((ref, id) async {
  return ref.watch(reelsRepositoryProvider).getById(id);
});
