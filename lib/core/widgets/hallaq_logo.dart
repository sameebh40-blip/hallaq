import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../brand/brand_assets_controller.dart';

class HallaqLogo extends ConsumerWidget {
  final double size;
  final Color? color;
  final String? assetKey;

  const HallaqLogo({super.key, this.size = 112, this.color, this.assetKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final baseKey = (assetKey ?? 'app_logo').trim();
    final preferred = brightness == Brightness.dark ? '${baseKey}_dark' : '${baseKey}_light';

    final urlPreferred = (ref.watch(brandAssetUrlProvider(preferred)) ?? '').trim();
    final urlBase = (ref.watch(brandAssetUrlProvider(baseKey)) ?? '').trim();
    final url = urlPreferred.isNotEmpty ? urlPreferred : urlBase;

    final fallback = Image.asset(
      'assets/brand/hallaq_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (url.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
