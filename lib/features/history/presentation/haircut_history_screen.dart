import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import 'package:hallaq/core/widgets/luxury_scaffold.dart';
import '../data/haircut_history_repository.dart';

class HaircutHistoryScreen extends ConsumerWidget {
  const HaircutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myHaircutHistoryProvider);
    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Haircut history', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        trailing: LuxuryIconButton(
          icon: Icons.add_rounded,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AddHistoryScreen())),
        ),
      ),
      child: AsyncValueWidget<List<HaircutHistoryItem>>(
        value: value,
        data: (items) {
          if (items.isEmpty) return Center(child: Text('No history yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textMuted)));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            itemBuilder: (context, index) {
              final h = items[index];
              return HallaqCard(
                glass: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${h.cutDate.year}-${h.cutDate.month.toString().padLeft(2, '0')}-${h.cutDate.day.toString().padLeft(2, '0')}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    if (h.styleName != null) ...[
                      const SizedBox(height: 8),
                      Text(h.styleName!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                    if (h.notes != null && h.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(h.notes!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                    ],
                    if (h.photoUrls.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('${h.photoUrls.length} photos', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                    ],
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}

class _AddHistoryScreen extends ConsumerStatefulWidget {
  const _AddHistoryScreen();

  @override
  ConsumerState<_AddHistoryScreen> createState() => _AddHistoryScreenState();
}

class _AddHistoryScreenState extends ConsumerState<_AddHistoryScreen> {
  DateTime _date = DateTime.now();
  final _style = TextEditingController();
  final _notes = TextEditingController();
  List<XFile> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
    _style.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _date,
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    setState(() => _photos = files);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(haircutHistoryRepositoryProvider).add(
            cutDate: _date,
            styleName: _style.text.trim().isEmpty ? null : _style.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            photos: _photos,
          );
      ref.invalidate(myHaircutHistoryProvider);
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
        title: Text('Add haircut', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          HallaqCard(
            glass: true,
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppTheme.gold),
                const SizedBox(width: 10),
                Expanded(child: Text('Date: ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _busy ? null : _pickDate,
                  child: Text('Change', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.gold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HallaqTextField(controller: _style, label: 'Style name', hintText: 'Fade, beard, etc.'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            maxLines: 4,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Notes',
              hintText: 'What you liked, what to change next time...',
              filled: true,
              fillColor: const Color(0xFF141414),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          HallaqButton(
            label: _photos.isEmpty ? 'Add photos' : '${_photos.length} selected',
            variant: HallaqButtonVariant.secondary,
            icon: Icons.photo_library_outlined,
            onPressed: _busy ? null : _pickPhotos,
          ),
          const SizedBox(height: 16),
          HallaqButton(label: 'Save', onPressed: _busy ? null : _save, isLoading: _busy),
        ],
      ),
    );
  }
}
