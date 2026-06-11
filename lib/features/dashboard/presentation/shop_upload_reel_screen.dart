import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/media/video_player_controller_factory.dart';
import '../../../core/media/video_transcode_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../barber/data/barber_repository.dart';
import '../../shop/data/shop_repository.dart';
import 'shop_reel_controller.dart';

class ShopUploadReelScreen extends ConsumerStatefulWidget {
  const ShopUploadReelScreen({super.key});

  @override
  ConsumerState<ShopUploadReelScreen> createState() => _ShopUploadReelScreenState();
}

class _ShopUploadReelScreenState extends ConsumerState<ShopUploadReelScreen> {
  static const int _maxVideoBytes = 50 * 1024 * 1024;
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _hashtags = TextEditingController();
  final _picker = ImagePicker();

  int _step = 0;
  String _mediaType = 'image';
  String _ownerType = 'shop';
  String _selectedBarberId = '';
  Uint8List? _imageBytes;
  XFile? _videoFile;
  VideoPlayerController? _videoController;
  Uint8List? _thumbnailBytes;
  bool _busy = false;
  double? _progress;

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    _hashtags.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_busy) return;
    if (_mediaType == 'video') {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      setState(() {
        _videoFile = file;
        _imageBytes = null;
        _videoController?.dispose();
        _videoController = null;
        _thumbnailBytes = null;
      });
      try {
        final d = await ref.read(videoTranscodeServiceProvider).readDurationMs(file.path);
        if (d != null && d > 20 * 1000) {
          if (!mounted) return;
          _clearMedia();
          showErrorSnackBar(context, 'Video must be 20 seconds or less.');
          return;
        }
      } catch (_) {}
      final controller = createVideoController(file.path);
      try {
        await controller.initialize();
        controller.setLooping(true);
      } catch (e) {
        controller.dispose();
        if (!mounted) return;
        showErrorSnackBar(context, 'Preview not available. The video will be converted on publish.');
        return;
      }
      final duration = controller.value.duration;
      if (duration.inMilliseconds > 20 * 1000) {
        controller.dispose();
        if (!mounted) return;
        showErrorSnackBar(context, 'Video must be 20 seconds or less.');
        return;
      }
      if (!mounted) return;
      setState(() => _videoController = controller);
      return;
    }

    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _videoFile = null;
      _videoController?.dispose();
      _videoController = null;
      _thumbnailBytes = null;
    });
  }

  void _clearMedia() {
    _videoController?.dispose();
    setState(() {
      _imageBytes = null;
      _videoFile = null;
      _videoController = null;
      _thumbnailBytes = null;
    });
  }

  Future<void> _pickThumbnail() async {
    if (_busy) return;
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1400);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _thumbnailBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopValue = ref.watch(myShopProvider);
    final state = ref.watch(shopReelControllerProvider);

    ref.listen(shopReelControllerProvider, (_, next) {
      next.whenOrNull(error: (e, __) => showErrorSnackBar(context, e));
      next.whenOrNull(data: (_) => showSuccessSnackBar(context, 'Published'));
    });

    Future<void> publish(String shopId) async {
      if (_busy || state.isLoading) return;

      final ownerId = _ownerType == 'barber' ? _selectedBarberId.trim() : shopId;
      if (_ownerType == 'barber' && ownerId.isEmpty) {
        showErrorSnackBar(context, 'Missing required field: barber');
        return;
      }

      final hashtags = _hashtags.text
          .split(RegExp(r'[,\\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e.startsWith('#') ? e.substring(1) : e)
          .toList(growable: false);

      if (_mediaType == 'image' && _imageBytes == null) {
        showErrorSnackBar(context, 'Missing required field: media');
        return;
      }
      if (_mediaType == 'video' && _videoFile == null) {
        showErrorSnackBar(context, 'Missing required field: media');
        return;
      }

      setState(() {
        _busy = true;
        _progress = 0.15;
      });

      try {
        if (_mediaType == 'video') {
          setState(() => _progress = 0.25);
          final bytes = await ref.read(videoTranscodeServiceProvider).transcodeToMp4_720p(inputPath: _videoFile!.path);
          if (bytes.lengthInBytes > _maxVideoBytes) {
            showErrorSnackBar(context, 'Video is still too large after compression. Please choose a shorter video.');
            return;
          }
          setState(() => _progress = 0.55);
          await ref.read(shopReelControllerProvider.notifier).uploadVideoReel(
                videoBytes: bytes,
                videoContentType: 'video/mp4',
                ownerType: _ownerType,
                ownerId: ownerId,
                thumbnailBytes: _thumbnailBytes,
                caption: _caption.text,
                location: _location.text,
                hashtags: hashtags,
              );
          return;
        }

        setState(() => _progress = 0.35);
        await ref.read(shopReelControllerProvider.notifier).uploadImageReel(
              bytes: _imageBytes!,
              ownerType: _ownerType,
              ownerId: ownerId,
              caption: _caption.text,
              location: _location.text,
              hashtags: hashtags,
            );
      } finally {
        if (mounted) {
          setState(() {
            _busy = false;
            _progress = null;
          });
        }
      }
    }

    void next() {
      if (_step == 0) {
        if (_ownerType == 'barber' && _selectedBarberId.trim().isEmpty) {
          showErrorSnackBar(context, 'Missing required field: barber');
          return;
        }
      }
      if (_step == 2) {
        if (_mediaType == 'image' && _imageBytes == null) {
          showErrorSnackBar(context, 'Missing required field: media');
          return;
        }
        if (_mediaType == 'video' && _videoFile == null) {
          showErrorSnackBar(context, 'Missing required field: media');
          return;
        }
      }
      setState(() => _step = (_step + 1).clamp(0, 4));
    }

    void back() => setState(() => _step = (_step - 1).clamp(0, 4));

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Upload reel', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      child: AsyncValueWidget(
        value: shopValue,
        data: (shop) {
          if (shop == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: HallaqCard(glass: true, child: Text('No shop assigned to this account.')),
            );
          }

          final barbersValue = ref.watch(barbersForShopProvider(shop.id));

          Widget stepBody() {
            if (_step == 0) {
              return HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('1. Select owner', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => setState(() => _ownerType = 'shop'),
                            style: OutlinedButton.styleFrom(backgroundColor: _ownerType == 'shop' ? AppTheme.gold.withValues(alpha: 0.12) : null),
                            child: const Text('Shop'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => setState(() => _ownerType = 'barber'),
                            style: OutlinedButton.styleFrom(backgroundColor: _ownerType == 'barber' ? AppTheme.gold.withValues(alpha: 0.12) : null),
                            child: const Text('Barber'),
                          ),
                        ),
                      ],
                    ),
                    if (_ownerType == 'barber') ...[
                      const SizedBox(height: 12),
                      AsyncValueWidget(
                        value: barbersValue,
                        data: (barbers) {
                          if (barbers.isEmpty) return const Text('No barbers found for this shop.');
                          final v = _selectedBarberId.isEmpty ? barbers.first.id : _selectedBarberId;
                          return DropdownButtonFormField<String>(
                            key: ValueKey('barber_$v'),
                            initialValue: v,
                            items: barbers
                                .map((b) => DropdownMenuItem<String>(value: b.id, child: Text(b.displayName)))
                                .toList(growable: false),
                            onChanged: _busy ? null : (val) => setState(() => _selectedBarberId = val ?? ''),
                            decoration: const InputDecoration(labelText: 'Select barber'),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            }

            if (_step == 1) {
              return HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('2. Select media type', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _mediaType = 'image';
                                      _clearMedia();
                                    }),
                            style: OutlinedButton.styleFrom(backgroundColor: _mediaType == 'image' ? AppTheme.gold.withValues(alpha: 0.12) : null),
                            child: const Text('Image'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _mediaType = 'video';
                                      _clearMedia();
                                    }),
                            style: OutlinedButton.styleFrom(backgroundColor: _mediaType == 'video' ? AppTheme.gold.withValues(alpha: 0.12) : null),
                            child: const Text('Video'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            if (_step == 2) {
              return HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('3. Upload media', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      child: SizedBox(
                        height: 210,
                        child: _mediaType == 'image'
                            ? (_imageBytes == null ? const _MediaPlaceholder() : Image.memory(_imageBytes!, fit: BoxFit.cover))
                            : (_videoController == null ? const _MediaPlaceholder() : _VideoPreview(controller: _videoController!)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: HallaqButton(
                            label: (_mediaType == 'video') ? 'Pick video' : 'Pick image',
                            expanded: true,
                            icon: Icons.upload_rounded,
                            variant: HallaqButtonVariant.secondary,
                            onPressed: _busy ? null : _pickMedia,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_imageBytes != null || _videoFile != null || _videoController != null)
                          HallaqButton(
                            label: 'Remove',
                            icon: Icons.close_rounded,
                            variant: HallaqButtonVariant.secondary,
                            onPressed: _busy ? null : _clearMedia,
                          ),
                      ],
                    ),
                    if (_mediaType == 'video') ...[
                      const SizedBox(height: 12),
                      Text('Thumbnail (optional)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: SizedBox(
                          height: 140,
                          child: _thumbnailBytes == null ? const _MediaPlaceholder() : Image.memory(_thumbnailBytes!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: HallaqButton(
                              label: _thumbnailBytes == null ? 'Pick thumbnail' : 'Replace thumbnail',
                              expanded: true,
                              icon: Icons.photo_library_rounded,
                              variant: HallaqButtonVariant.secondary,
                              onPressed: _busy ? null : _pickThumbnail,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_thumbnailBytes != null)
                            HallaqButton(
                              label: 'Remove',
                              icon: Icons.close_rounded,
                              variant: HallaqButtonVariant.secondary,
                              onPressed: _busy ? null : () => setState(() => _thumbnailBytes = null),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }

            if (_step == 3) {
              return HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('4. Add details', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    TextField(controller: _caption, decoration: const InputDecoration(labelText: 'Caption (optional)'), maxLines: 2),
                    const SizedBox(height: 12),
                    TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location (optional)')),
                    const SizedBox(height: 12),
                    TextField(controller: _hashtags, decoration: const InputDecoration(labelText: 'Hashtags (comma or space separated)')),
                  ],
                ),
              );
            }

            return HallaqCard(
              glass: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('5. Publish', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    'Owner: ${_ownerType == 'shop' ? 'Shop' : 'Barber'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Media: ${_mediaType == 'video' ? 'Video' : 'Image'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  LuxuryButton(
                    label: 'Publish',
                    isLoading: _busy || state.isLoading,
                    onPressed: (_busy || state.isLoading) ? null : () => publish(shop.id),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 130),
                children: [
                  if (_busy)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                  if (_busy) const SizedBox(height: 12),
                  stepBody(),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: HallaqButton(
                          label: 'Back',
                          expanded: true,
                          variant: HallaqButtonVariant.secondary,
                          icon: Icons.arrow_back_rounded,
                          onPressed: (_busy || _step == 0) ? null : back,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: HallaqButton(
                          label: _step >= 4 ? 'Done' : 'Next',
                          expanded: true,
                          icon: Icons.arrow_forward_rounded,
                          onPressed: _busy
                              ? null
                              : _step >= 4
                                  ? () => context.pop()
                                  : next,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Center(
        child: Text(
          'No media selected',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoPreview({required this.controller});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  @override
  void initState() {
    super.initState();
    widget.controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: widget.controller.value.size.width, height: widget.controller.value.size.height, child: VideoPlayer(widget.controller)))),
        Positioned(
          right: 10,
          bottom: 10,
          child: InkWell(
            onTap: () {
              setState(() {
                if (widget.controller.value.isPlaying) {
                  widget.controller.pause();
                } else {
                  widget.controller.play();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
