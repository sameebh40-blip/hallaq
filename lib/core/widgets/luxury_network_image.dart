import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../media/media_service.dart';
import '../theme/app_theme.dart';
import '../brand/brand_assets_controller.dart';
import 'gold_shimmer.dart';
import 'hallaq_logo.dart';

class LuxuryNetworkImage extends ConsumerWidget {
  final String? imageUrl;
  final String fallbackUrl;
  final String? fallbackKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final String? bucket;

  const LuxuryNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fallbackUrl,
    this.fallbackKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppTheme.radiusMd)),
    this.bucket,
  });

  Future<String?> _resolveUrl(MediaService media, String primary) async {
    if (primary.isEmpty) return null;
    return media.resolveAnyImageRef(primary: primary, bucket: bucket);
  }

  bool _looksLikeSupabasePublicStorageUrl(String v) => v.contains('/storage/v1/object/public/');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = (imageUrl ?? '').trim();
    final fallback0 = fallbackUrl.trim();
    final key = (fallbackKey ?? '').trim();
    final fromBrand = key.isEmpty ? null : (ref.watch(brandAssetUrlProvider(key)) ?? '').trim();
    final fallback = fromBrand != null && fromBrand.isNotEmpty ? fromBrand : fallback0;
    final bucket0 = (bucket ?? '').trim();
    final shouldResolve = primary.isNotEmpty && bucket0.isNotEmpty && !(primary.startsWith('http://') || primary.startsWith('https://'));
    final looksLikePublic = primary.isNotEmpty && primary.startsWith('http') && _looksLikeSupabasePublicStorageUrl(primary);
    final media = ref.read(mediaServiceProvider);
    final canSyncResolvePublicPath = shouldResolve && media.isPublicBucket(bucket0);
    final needsResolution = !canSyncResolvePublicPath && shouldResolve;
    final urlForPublicPath = canSyncResolvePublicPath ? media.publicUrlFor(bucket: bucket0, path: primary) : null;

    return ClipRRect(
      borderRadius: borderRadius,
      child: primary.isEmpty && fallback.isEmpty
          ? _PremiumFallback(width: width, height: height)
          : looksLikePublic
              ? _ImageWithFallback(
                  url: primary,
                  fallback: fallback,
                  width: width,
                  height: height,
                  fit: fit,
                  borderRadius: borderRadius,
                )
              : urlForPublicPath != null
                  ? _ImageWithFallback(
                      url: urlForPublicPath,
                      fallback: fallback,
                      width: width,
                      height: height,
                      fit: fit,
                      borderRadius: borderRadius,
                    )
                  : needsResolution
              ? FutureBuilder<String?>(
                  future: _resolveUrl(media, primary),
                  builder: (context, snapshot) {
                    final resolved = (snapshot.data ?? '').trim();
                    final url = resolved.isNotEmpty ? resolved : (primary.isNotEmpty ? primary : fallback);
                    if (snapshot.connectionState != ConnectionState.done && url.isEmpty) {
                      return GoldShimmer(
                        width: width ?? double.infinity,
                        height: height ?? double.infinity,
                        borderRadius: borderRadius,
                      );
                    }
                    return _ImageWithFallback(
                      url: url,
                      fallback: fallback,
                      width: width,
                      height: height,
                      fit: fit,
                      borderRadius: borderRadius,
                    );
                  },
                )
              : _ImageWithFallback(
                  url: primary.isNotEmpty ? primary : fallback,
                  fallback: fallback,
                  width: width,
                  height: height,
                  fit: fit,
                  borderRadius: borderRadius,
                ),
    );
  }
}

class _ImageWithFallback extends StatelessWidget {
  final String url;
  final String fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  const _ImageWithFallback({
    required this.url,
    required this.fallback,
    required this.width,
    required this.height,
    required this.fit,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _PremiumFallback(width: width, height: height);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = (width != null && width!.isFinite && width! > 0) ? (width! * dpr).round().clamp(1, 4096) : null;
    final cacheH = (height != null && height!.isFinite && height! > 0) ? (height! * dpr).round().clamp(1, 4096) : null;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      useOldImageOnUrlChange: true,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      maxWidthDiskCache: cacheW,
      maxHeightDiskCache: cacheH,
      placeholder: (_, __) => GoldShimmer(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        borderRadius: borderRadius,
      ),
      errorWidget: (_, __, ___) {
        if (url != fallback && fallback.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: fallback,
            width: width,
            height: height,
            fit: fit,
            useOldImageOnUrlChange: true,
            memCacheWidth: cacheW,
            memCacheHeight: cacheH,
            maxWidthDiskCache: cacheW,
            maxHeightDiskCache: cacheH,
            placeholder: (_, __) => GoldShimmer(
              width: width ?? double.infinity,
              height: height ?? double.infinity,
              borderRadius: borderRadius,
            ),
            errorWidget: (_, __, ___) => _PremiumFallback(width: width, height: height),
          );
        }
        return _PremiumFallback(width: width, height: height);
      },
    );
  }
}

class _PremiumFallback extends StatelessWidget {
  final double? width;
  final double? height;

  const _PremiumFallback({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.onyx2,
            AppTheme.onyx4,
          ],
        ),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.18)),
      ),
      child: Center(
        child: HallaqLogo(size: 46, color: AppTheme.goldSoft.withValues(alpha: 0.92)),
      ),
    );
  }
}
