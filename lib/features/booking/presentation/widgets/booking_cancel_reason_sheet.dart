import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/hallaq_ui.dart';

class BookingCancelReasonSheet extends StatefulWidget {
  const BookingCancelReasonSheet({super.key});

  @override
  State<BookingCancelReasonSheet> createState() => _BookingCancelReasonSheetState();
}

class _BookingCancelReasonSheetState extends State<BookingCancelReasonSheet> {
  static const _other = 'Other';

  final _controller = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = <String>[
      'Customer requested cancellation',
      'Booked by mistake',
      'Change of plans',
      'Barber unavailable',
      'Shop unavailable',
      'Emergency',
      _other,
    ];

    final showOther = _selected == _other;
    final otherText = _controller.text.trim();
    final canConfirm = _selected != null && (!showOther || otherText.isNotEmpty);
    final result = showOther ? otherText : (_selected ?? '');
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
          child: HallaqCard(
            glass: true,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Cancellation reason', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: reasons
                          .map(
                            (r) => ChoiceChip(
                              label: Text(r),
                              selected: _selected == r,
                              onSelected: (_) {
                                setState(() {
                                  _selected = r;
                                  if (r != _other) _controller.clear();
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    if (showOther) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Write a short reason',
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: BorderSide(color: AppTheme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: BorderSide(color: AppTheme.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.7))),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 14),
                    HallaqButton(
                      label: 'Confirm cancel',
                      icon: Icons.cancel_outlined,
                      onPressed: canConfirm ? () => Navigator.of(context).pop(result) : null,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Back')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
