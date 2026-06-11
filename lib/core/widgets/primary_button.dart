import 'package:flutter/material.dart';

import 'luxury_button.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryButton(
      label: label,
      onPressed: isLoading ? null : onPressed,
      expanded: expanded,
      isLoading: isLoading,
      variant: LuxuryButtonVariant.primary,
    );
  }
}
