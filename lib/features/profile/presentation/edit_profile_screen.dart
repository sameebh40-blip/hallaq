import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/network/network_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../data/profile_repository.dart';
import 'profile_media_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _bio = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider);
    final media = ref.watch(profileMediaControllerProvider);

    ref.listen(profileMediaControllerProvider, (_, next) {
      next.whenOrNull(error: (e, __) => showErrorSnackBar(context, e));
    });

    Future<bool> confirmUpload(Uint8List bytes, {required bool cover}) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            backgroundColor: AppTheme.surface,
            contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            content: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: cover ? (16 / 9) : 1,
                child: Image.memory(bytes, fit: BoxFit.cover),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Upload')),
            ],
          );
        },
      );
      return confirmed ?? false;
    }

    Future<void> pickAndUploadAvatar() async {
      if (!ref.read(networkOnlineProvider)) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are offline.')));
        return;
      }
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 900);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ok = await confirmUpload(bytes, cover: false);
      if (!ok) return;
      await ref.read(profileMediaControllerProvider.notifier).updateAvatar(bytes: bytes);
    }

    Future<void> pickAndUploadCover() async {
      if (!ref.read(networkOnlineProvider)) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are offline.')));
        return;
      }
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ok = await confirmUpload(bytes, cover: true);
      if (!ok) return;
      await ref.read(profileMediaControllerProvider.notifier).updateCover(bytes: bytes);
    }

    return ColoredBox(
      color: AppTheme.background,
      child: AsyncValueWidget(
        value: profile,
        onRetry: () => ref.invalidate(myProfileProvider),
        data: (p) {
          if (p == null) {
            return Center(
              child: Text(
                'Sign in to continue',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            );
          }

          if (!_initialized) {
            _initialized = true;
            _fullName.text = (p.fullName ?? '').trim();
            _email.text = (p.email ?? '').trim();
            _phone.text = (p.phone ?? '').trim();
            _location.text = ((p.location ?? '').trim().isNotEmpty ? (p.location ?? '') : (p.area ?? '')).trim();
            _bio.text = (p.bio ?? '').trim();
          }

          return SafeArea(
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
                          child: Text(
                            'Edit Profile',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                try {
                                  await ref.read(profileRepositoryProvider).upsertMyProfile(
                                        fullName: _fullName.text,
                                        phone: _phone.text,
                                        email: _email.text,
                                        location: _location.text,
                                        bio: _bio.text.characters.take(120).toString(),
                                      );
                                  ref.invalidate(myProfileProvider);
                                  if (context.mounted) context.pop();
                                } catch (e) {
                                  if (context.mounted) showErrorSnackBar(context, e);
                                } finally {
                                  if (mounted) setState(() => _saving = false);
                                }
                              },
                        child: Text(
                          l10n.save,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: pickAndUploadCover,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                children: [
                                  LuxuryNetworkImage(
                                    key: ValueKey('edit_cover:${(p.coverUrl ?? '').trim()}'),
                                    imageUrl: p.coverUrl,
                                    fallbackUrl: '',
                                    fallbackKey: 'default_profile_cover',
                                    width: double.infinity,
                                    height: 120,
                                    borderRadius: BorderRadius.circular(18),
                                    bucket: 'profile-covers',
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: AppTheme.gold,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.photo_camera_outlined, size: 18, color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to change cover',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: pickAndUploadAvatar,
                          child: Column(
                            children: [
                              Hero(
                                tag: 'profile_avatar',
                                child: Stack(
                                  children: [
                                    ClipOval(
                                      child: LuxuryNetworkImage(
                                        key: ValueKey('edit_avatar:${(p.avatarUrl ?? '').trim()}'),
                                        imageUrl: p.avatarUrl,
                                        fallbackUrl: '',
                                        fallbackKey: 'default_profile_avatar',
                                        width: 84,
                                        height: 84,
                                        borderRadius: BorderRadius.circular(999),
                                        bucket: 'avatars',
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: AppTheme.gold,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.black),
                                      ),
                                    ),
                                    if (media.isLoading)
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(color: AppTheme.background.withValues(alpha: 0.72), shape: BoxShape.circle),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to change photo',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _Field(label: 'Full Name', controller: _fullName),
                      const SizedBox(height: 12),
                      _Field(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      _Field(label: 'Phone Number', controller: _phone, keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Location',
                        controller: _location,
                        readOnly: false,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Bio',
                        controller: _bio,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        helper: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_bio.text.characters.length}/120',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool readOnly;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? helper;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.readOnly = false,
    this.maxLines = 1,
    this.onChanged,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          maxLines: maxLines,
          onChanged: onChanged,
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
        if (helper != null) ...[
          const SizedBox(height: 6),
          helper!,
        ],
      ],
    );
  }
}
