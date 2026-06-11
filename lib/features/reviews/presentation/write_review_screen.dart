import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/reviews_repository.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  final String targetType;
  final String targetId;
  final String? bookingId;

  const WriteReviewScreen({super.key, required this.targetType, required this.targetId, this.bookingId});

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  int _rating = 5;
  final _text = TextEditingController();
  XFile? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _photo = file);
  }

  Future<void> _submit() async {
    if ((widget.bookingId ?? '').trim().isEmpty) {
      showErrorSnackBar(context, const AppException('You can review after your booking is confirmed or completed.'));
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(reviewsRepositoryProvider).create(
            targetType: widget.targetType,
            targetId: widget.targetId,
            rating: _rating,
            comment: _text.text.trim().isEmpty ? null : _text.text.trim(),
            photo: _photo,
            bookingId: widget.bookingId,
          );
      ref.invalidate(reviewsForTargetProvider((targetType: widget.targetType, targetId: widget.targetId)));
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AppException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Write review', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Text('Rating', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          HallaqCard(
            glass: true,
            child: Row(
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: _busy ? null : () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      _rating >= i + 1 ? Icons.star_rounded : Icons.star_border_rounded,
                      color: _rating >= i + 1 ? AppTheme.gold : AppTheme.textMuted,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _text,
            maxLines: 5,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Review',
              hintText: 'Tell others about your experience',
              filled: true,
              fillColor: const Color(0xFF141414),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          HallaqButton(
            label: _photo == null ? 'Add photo' : 'Change photo',
            variant: HallaqButtonVariant.secondary,
            icon: Icons.photo_outlined,
            onPressed: _busy ? null : _pickPhoto,
          ),
          const SizedBox(height: 16),
          HallaqButton(label: 'Submit', onPressed: _busy ? null : _submit, isLoading: _busy),
        ],
      ),
    );
  }
}
