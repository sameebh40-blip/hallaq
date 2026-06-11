import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LuxuryTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final void Function(String value)? onFieldSubmitted;
  final Widget? prefixIcon;
  final bool obscureText;
  final bool allowObscureToggle;

  const LuxuryTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.obscureText = false,
    this.allowObscureToggle = false,
  });

  @override
  State<LuxuryTextField> createState() => _LuxuryTextFieldState();
}

class _LuxuryTextFieldState extends State<LuxuryTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant LuxuryTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppTheme.radiusMd);
    final border = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppTheme.border),
    );

    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      validator: widget.validator,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onFieldSubmitted,
      obscureText: _obscured,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.allowObscureToggle
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.enabled ? () => setState(() => _obscured = !_obscured) : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(_obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              )
            : null,
        filled: true,
        fillColor: AppTheme.surface,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.6))),
        errorBorder: border.copyWith(borderSide: BorderSide(color: AppTheme.error.withValues(alpha: 0.55))),
        focusedErrorBorder: border.copyWith(borderSide: BorderSide(color: AppTheme.error.withValues(alpha: 0.75))),
        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted.withValues(alpha: 0.75)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
