import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../brand/brand_assets_controller.dart';
import '../theme/app_theme.dart';
import 'glass_bottom_nav.dart';
import 'hallaq_mascot.dart';
import 'luxury_button.dart';
import 'luxury_card.dart';
import 'luxury_loader.dart';
import 'luxury_network_image.dart';
import 'luxury_text_field.dart';
import 'section_header.dart';

enum HallaqButtonVariant { primary, secondary, ghost }

class HallaqButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final HallaqButtonVariant variant;
  final bool expanded;
  final bool isLoading;
  final IconData? icon;

  const HallaqButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HallaqButtonVariant.primary,
    this.expanded = true,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryButton(
      label: label,
      onPressed: onPressed,
      variant: switch (variant) {
        HallaqButtonVariant.primary => LuxuryButtonVariant.primary,
        HallaqButtonVariant.secondary => LuxuryButtonVariant.secondary,
        HallaqButtonVariant.ghost => LuxuryButtonVariant.ghost,
      },
      expanded: expanded,
      isLoading: isLoading,
      icon: icon,
    );
  }
}

class HallaqCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool glass;

  const HallaqCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(onTap: onTap, padding: padding, glass: glass, child: child);
  }
}

class HallaqTextField extends StatelessWidget {
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

  const HallaqTextField({
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
  Widget build(BuildContext context) {
    return LuxuryTextField(
      controller: controller,
      label: label,
      hintText: hintText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enabled: enabled,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      prefixIcon: prefixIcon,
      obscureText: obscureText,
      allowObscureToggle: allowObscureToggle,
    );
  }
}

class HallaqBottomNavItem {
  final IconData icon;
  final String label;

  const HallaqBottomNavItem({required this.icon, required this.label});
}

class HallaqBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<HallaqBottomNavItem> items;
  final VoidCallback? onActionTap;
  final bool actionSelected;
  final IconData actionIcon;
  final String? actionLabel;

  const HallaqBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.onActionTap,
    this.actionSelected = false,
    this.actionIcon = Icons.add_rounded,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GlassBottomNav(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items.map((e) => GlassBottomNavItem(icon: e.icon, label: e.label)).toList(),
      onActionTap: onActionTap,
      actionSelected: actionSelected,
      actionIcon: actionIcon,
      actionLabel: actionLabel,
    );
  }
}

class HallaqAvatar extends ConsumerWidget {
  final String? imageUrl;
  final double size;
  final String variant;
  final String? fallbackUrl;
  final String? bucket;

  const HallaqAvatar({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.variant = '01',
    this.fallbackUrl,
    this.bucket,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = (fallbackUrl ?? '').trim();
    final brandFallback = ref.watch(brandAssetUrlProvider('default_barber_avatar'))?.trim();
    final bucket0 = (bucket ?? '').trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.32), width: 1),
        boxShadow: AppTheme.softShadow(opacity: 0.10),
      ),
      child: ClipOval(
        child: LuxuryNetworkImage(
          imageUrl: imageUrl,
          fallbackUrl: fallback.isNotEmpty ? fallback : (brandFallback ?? ''),
          bucket: bucket0.isEmpty ? null : bucket0,
          width: size,
          height: size,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class HallaqRating extends StatelessWidget {
  final double value;
  final int? count;
  final double iconSize;
  final bool showValue;

  const HallaqRating({
    super.key,
    required this.value,
    this.count,
    this.iconSize = 16,
    this.showValue = true,
  });

  @override
  Widget build(BuildContext context) {
    final full = value.floor().clamp(0, 5);
    final hasHalf = (value - full) >= 0.5 && full < 5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          if (i < full) return Icon(Icons.star_rounded, size: iconSize, color: AppTheme.gold);
          if (i == full && hasHalf) return Icon(Icons.star_half_rounded, size: iconSize, color: AppTheme.gold);
          return Icon(Icons.star_border_rounded, size: iconSize, color: AppTheme.textMuted);
        }),
        if (showValue || count != null) ...[
          const SizedBox(width: 8),
          if (showValue)
            Text(
              value.toStringAsFixed(1),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              '($count)',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted),
            ),
          ],
        ],
      ],
    );
  }
}

class HallaqSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const HallaqSectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return SectionHeader(title: title, trailing: trailing);
  }
}

class HallaqLoading extends StatelessWidget {
  final double size;

  const HallaqLoading({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return LuxuryLoader(size: size);
  }
}

class HallaqEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String? imageUrl;
  final String imageVariant;
  final bool showMascot;
  final bool compact;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HallaqEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    this.imageVariant = '01',
    this.showMascot = false,
    this.compact = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final img = (imageUrl ?? '').trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0;
        final isCompact = compact || !hasBoundedHeight || constraints.maxHeight < 280;
        final pad = EdgeInsets.symmetric(horizontal: 16, vertical: isCompact ? 12 : 26);
        final imageHeight = isCompact ? 84.0 : 220.0;
        final mascotSize = isCompact ? 62.0 : 120.0;
        final spacingLg = isCompact ? 10.0 : 18.0;
        final spacingSm = isCompact ? 6.0 : 8.0;

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (img.isEmpty || (showMascot && img.isEmpty))
              HallaqMascot(size: mascotSize)
            else
              LuxuryNetworkImage(
                imageUrl: img,
                fallbackUrl: img,
                height: imageHeight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
            SizedBox(height: spacingLg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: (isCompact ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge)?.copyWith(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: spacingSm),
            Text(
              description,
              textAlign: TextAlign.center,
              maxLines: isCompact ? 2 : 4,
              overflow: TextOverflow.ellipsis,
              style: (isCompact ? Theme.of(context).textTheme.bodySmall : Theme.of(context).textTheme.bodyMedium)?.copyWith(color: AppTheme.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: spacingLg),
              HallaqButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        );

        if (!isCompact) {
          final minH = hasBoundedHeight ? constraints.maxHeight : 0.0;
          return SingleChildScrollView(
            padding: pad,
            child: ConstrainedBox(constraints: BoxConstraints(minHeight: minH), child: content),
          );
        }

        return Padding(
          padding: pad,
          child: HallaqCard(
            glass: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppTheme.gold.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0, 1],
                ),
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class HallaqTeaserCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const HallaqTeaserCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppTheme.goldGradient,
              boxShadow: AppTheme.softShadow(opacity: 0.45),
            ),
            child: Icon(icon, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
