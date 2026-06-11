import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../errors/app_exception.dart';
import '../storage/storage_service.dart';
import 'video_thumbnailer.dart';

class MediaImageProcessOptions {
  final double? cropAspectRatio;
  final int maxWidth;
  final int maxHeight;
  final int webpQuality;
  final int thumbMaxWidth;
  final int thumbMaxHeight;
  final int thumbWebpQuality;

  const MediaImageProcessOptions({
    this.cropAspectRatio,
    this.maxWidth = 1800,
    this.maxHeight = 1800,
    this.webpQuality = 80,
    this.thumbMaxWidth = 480,
    this.thumbMaxHeight = 480,
    this.thumbWebpQuality = 70,
  });
}

class MediaImageUploadResult {
  final String path;
  final String? thumbnailPath;
  final int originalBytes;
  final int optimizedBytes;
  final int? thumbnailBytes;

  const MediaImageUploadResult({
    required this.path,
    required this.thumbnailPath,
    required this.originalBytes,
    required this.optimizedBytes,
    required this.thumbnailBytes,
  });
}

class MediaVideoUploadResult {
  final String videoPath;
  final String? thumbnailPath;

  const MediaVideoUploadResult({
    required this.videoPath,
    required this.thumbnailPath,
  });
}

class MediaService {
  final StorageService _storage;
  final Random _rand = Random.secure();

  MediaService(this._storage);

  static const int _maxImageUploadBytes = 15 * 1024 * 1024;
  static const int _maxVideoUploadBytes = 50 * 1024 * 1024;
  static const int _maxSourceImageBytes = 60 * 1024 * 1024;

  static const Set<String> _publicBuckets = {
    'avatars',
    'profile-covers',
    'shop-images',
    'barber-images',
    'service-images',
    'portfolio',
    'product-images',
    'offer-images',
    'awards',
    'before-after',
    'review-photos',
    'haircut-history',
    'review-images',
    'products',
    'ai-style',
  };

  bool _looksLikeUrl(String v) => v.startsWith('http://') || v.startsWith('https://');

  String publicUrlFor({required String bucket, required String path}) {
    return _storage.publicUrl(bucket: bucket, path: path);
  }

  bool isPublicBucket(String bucket) => _publicBuckets.contains(bucket);

  void _ensureMaxBytes(Uint8List bytes, {required int maxBytes}) {
    if (bytes.lengthInBytes <= maxBytes) return;
    throw const AppException('File is too large. Please choose a smaller file.');
  }

  void _validatePathPrefix(String prefix) {
    final p = prefix.trim();
    if (p.isEmpty) throw const AppException('Invalid upload path');
    if (p.startsWith('/') || p.startsWith('\\')) throw const AppException('Invalid upload path');
    if (p.contains('..')) throw const AppException('Invalid upload path');
    if (p.contains('\\')) throw const AppException('Invalid upload path');
  }

  String _token([int bytes = 8]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final out = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      out.write(chars[_rand.nextInt(chars.length)]);
    }
    return out.toString();
  }

  String _jpgName(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_token()}.jpg';
  Future<String> _objectUrl({
    required String bucket,
    required String path,
    required int expiresInSeconds,
  }) async {
    if (_publicBuckets.contains(bucket)) {
      return _storage.publicUrl(bucket: bucket, path: path);
    }
    return _storage.signedUrl(bucket: bucket, path: path, expiresInSeconds: expiresInSeconds);
  }



  img.Image _resizeToBounds(
    img.Image source, {
    required int maxWidth,
    required int maxHeight,
  }) {
    return img.copyResize(
      source,
      width: source.width > maxWidth ? maxWidth : null,
      height: source.height > maxHeight ? maxHeight : null,
      maintainAspect: true,
      interpolation: img.Interpolation.average,
    );
  }

  Uint8List _encodeJpgToFit({
    required img.Image source,
    required int maxWidth,
    required int maxHeight,
    required int preferredQuality,
    int? maxBytes,
  }) {
    final scales = <double>[1, 0.92, 0.84, 0.76, 0.68, 0.6, 0.52, 0.44];
    final qualities = <int>{
      preferredQuality.clamp(35, 95),
      min(preferredQuality, 76),
      min(preferredQuality, 68),
      min(preferredQuality, 60),
      52,
      45,
      38,
      32,
    }.where((q) => q >= 30).toList(growable: false);

    Uint8List? smallest;
    for (final scale in scales) {
      final scaledWidth = max(1, (maxWidth * scale).round());
      final scaledHeight = max(1, (maxHeight * scale).round());
      final resized = _resizeToBounds(
        source,
        maxWidth: scaledWidth,
        maxHeight: scaledHeight,
      );
      for (final quality in qualities) {
        final encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
        if (smallest == null || encoded.lengthInBytes < smallest.lengthInBytes) {
          smallest = encoded;
        }
        if (maxBytes == null || encoded.lengthInBytes <= maxBytes) {
          return encoded;
        }
      }
    }

    if (smallest != null) {
      if (maxBytes == null || smallest.lengthInBytes <= maxBytes) return smallest;
    }
    throw const AppException(
      'Image is still too large after compression. Please choose a smaller image.',
    );
  }

  Future<({Uint8List optimized, Uint8List thumbnail})> _processImageToJpg({
    required Uint8List bytes,
    required MediaImageProcessOptions options,
    int? optimizedMaxBytes,
    int? thumbnailMaxBytes,
  }) async {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      try {
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: options.maxWidth, targetHeight: options.maxHeight);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        final png = data?.buffer.asUint8List() ?? Uint8List(0);
        if (png.isNotEmpty) {
          try {
            decoded = img.decodeImage(png);
          } catch (_) {
            decoded = null;
          }
        }
      } catch (_) {
        decoded = null;
      }
    }
    if (decoded == null) {
      throw const AppException('Unsupported image format');
    }
    if (decoded.width <= 0 || decoded.height <= 0) {
      throw const AppException('Invalid image');
    }

    img.Image working = decoded;

    final aspect = options.cropAspectRatio;
    if (aspect != null && aspect > 0) {
      final srcW = working.width;
      final srcH = working.height;
      final srcAspect = srcW / srcH;
      int cropW;
      int cropH;
      if (srcAspect > aspect) {
        cropH = srcH;
        cropW = (cropH * aspect).round();
      } else {
        cropW = srcW;
        cropH = (cropW / aspect).round();
      }
      cropW = cropW.clamp(1, srcW);
      cropH = cropH.clamp(1, srcH);
      final x = ((srcW - cropW) / 2).round().clamp(0, srcW - cropW);
      final y = ((srcH - cropH) / 2).round().clamp(0, srcH - cropH);
      working = img.copyCrop(working, x: x, y: y, width: cropW, height: cropH);
    }

    final optimized = _encodeJpgToFit(
      source: working,
      maxWidth: options.maxWidth,
      maxHeight: options.maxHeight,
      preferredQuality: options.webpQuality,
      maxBytes: optimizedMaxBytes,
    );
    final thumb = _encodeJpgToFit(
      source: working,
      maxWidth: options.thumbMaxWidth,
      maxHeight: options.thumbMaxHeight,
      preferredQuality: options.thumbWebpQuality,
      maxBytes: thumbnailMaxBytes,
    );
    return (optimized: optimized, thumbnail: thumb);
  }

  Future<String?> resolveMediaUrl({
    required String bucket,
    String? path,
    String? legacyUrlOrPath,
    int expiresInSeconds = 3600,
  }) async {
    final p = (path ?? '').trim();
    if (p.isNotEmpty) {
      return _objectUrl(bucket: bucket, path: p, expiresInSeconds: expiresInSeconds);
    }

    final u = (legacyUrlOrPath ?? '').trim();
    if (u.isEmpty) return null;
    if (!_looksLikeUrl(u)) {
      return _objectUrl(bucket: bucket, path: u, expiresInSeconds: expiresInSeconds);
    }

    final parsed = parseSupabasePublicStorageUrl(u);
    if (parsed != null) {
      if (_publicBuckets.contains(parsed.bucket)) return u;
      return _storage.signedUrl(bucket: parsed.bucket, path: parsed.path, expiresInSeconds: expiresInSeconds);
    }
    return u;
  }

  Future<String?> resolveMediaUrlMulti({
    required List<String> buckets,
    String? path,
    String? legacyUrlOrPath,
    int expiresInSeconds = 3600,
  }) async {
    for (final bucket in buckets) {
      try {
        final resolved = await resolveMediaUrl(
          bucket: bucket,
          path: path,
          legacyUrlOrPath: legacyUrlOrPath,
          expiresInSeconds: expiresInSeconds,
        );
        if (resolved != null) return resolved;
      } catch (_) {}
    }
    return null;
  }

  Future<String?> resolveAnyImageRef({
    required String primary,
    String? bucket,
    int expiresInSeconds = 3600,
  }) async {
    final v = primary.trim();
    if (v.isEmpty) return null;

    if (_looksLikeUrl(v)) {
      final parsed = parseSupabasePublicStorageUrl(v);
      if (parsed == null) return v;
      if (_publicBuckets.contains(parsed.bucket)) return v;
      return _storage.signedUrl(bucket: parsed.bucket, path: parsed.path, expiresInSeconds: expiresInSeconds);
    }

    final b = (bucket ?? '').trim();
    if (b.isEmpty) return null;
    return _objectUrl(bucket: b, path: v, expiresInSeconds: expiresInSeconds);
  }

  Future<void> precacheAnyImageRef(
    BuildContext context, {
    required String primary,
    String? bucket,
    int expiresInSeconds = 3600,
  }) async {
    final url = await resolveAnyImageRef(primary: primary, bucket: bucket, expiresInSeconds: expiresInSeconds);
    if (url == null || url.trim().isEmpty) return;
    if (!context.mounted) return;
    await precacheImage(CachedNetworkImageProvider(url), context);
  }

  Future<MediaImageUploadResult> uploadImage({
    required String bucket,
    required String pathPrefix,
    required Uint8List bytes,
    MediaImageProcessOptions options = const MediaImageProcessOptions(),
    bool uploadThumbnail = true,
    int? maxBytes,
  }) async {
    try {
      _validatePathPrefix(pathPrefix);
      final effectiveMax = maxBytes ?? _maxImageUploadBytes;
      final hardMax = max(effectiveMax * 4, _maxSourceImageBytes);
      _ensureMaxBytes(bytes, maxBytes: hardMax);
      final processed = await _processImageToJpg(
        bytes: bytes,
        options: options,
        optimizedMaxBytes: effectiveMax,
        thumbnailMaxBytes: uploadThumbnail ? effectiveMax : null,
      );
      _ensureMaxBytes(processed.optimized, maxBytes: effectiveMax);
      final name = _jpgName('img');
      final path = '$pathPrefix/$name';
      final storedPath = await _storage.uploadBytes(
        bucket: bucket,
        path: path,
        bytes: processed.optimized,
        contentType: 'image/jpeg',
      );

      String? storedThumbPath;
      int? thumbBytes;
      if (uploadThumbnail) {
        _ensureMaxBytes(processed.thumbnail, maxBytes: effectiveMax);
        final thumbName = _jpgName('thumb');
        final thumbPath = '$pathPrefix/$thumbName';
        storedThumbPath = await _storage.uploadBytes(
          bucket: bucket,
          path: thumbPath,
          bytes: processed.thumbnail,
          contentType: 'image/jpeg',
        );
        thumbBytes = processed.thumbnail.lengthInBytes;
      }

      return MediaImageUploadResult(
        path: storedPath,
        thumbnailPath: storedThumbPath,
        originalBytes: bytes.lengthInBytes,
        optimizedBytes: processed.optimized.lengthInBytes,
        thumbnailBytes: thumbBytes,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to upload image', cause: e);
    }
  }

  Future<MediaVideoUploadResult> uploadReelVideo({
    required String pathPrefix,
    required Uint8List videoBytes,
    String contentType = 'video/mp4',
    Uint8List? thumbnailBytes,
    MediaImageProcessOptions thumbnailOptions = const MediaImageProcessOptions(
      maxWidth: 1280,
      maxHeight: 1280,
      webpQuality: 75,
      thumbMaxWidth: 480,
      thumbMaxHeight: 480,
      thumbWebpQuality: 65,
    ),
  }) async {
    try {
      _validatePathPrefix(pathPrefix);
      _ensureMaxBytes(videoBytes, maxBytes: _maxVideoUploadBytes);
      final now = DateTime.now().microsecondsSinceEpoch;
      final videoPath = '$pathPrefix/video_${now}_${_token()}.mp4';
      final storedVideoPath = await _storage.uploadBytes(
        bucket: 'reels',
        path: videoPath,
        bytes: videoBytes,
        contentType: contentType,
      );

      String? storedThumbPath;
      final generatedThumb = thumbnailBytes ?? await _tryGenerateVideoThumbnail(videoBytes);
      if (generatedThumb != null) {
        final processed = await _processImageToJpg(
          bytes: generatedThumb,
          options: thumbnailOptions,
          optimizedMaxBytes: _maxImageUploadBytes,
          thumbnailMaxBytes: _maxImageUploadBytes,
        );
        _ensureMaxBytes(processed.thumbnail, maxBytes: _maxImageUploadBytes);
        final thumbPath = '$pathPrefix/thumb_${now}_${_token()}.jpg';
        storedThumbPath = await _storage.uploadBytes(
          bucket: 'reels',
          path: thumbPath,
          bytes: processed.thumbnail,
          contentType: 'image/jpeg',
        );
      }

      return MediaVideoUploadResult(videoPath: storedVideoPath, thumbnailPath: storedThumbPath);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to upload video', cause: e);
    }
  }

  Future<Uint8List?> _tryGenerateVideoThumbnail(Uint8List videoBytes) async {
    try {
      return await generateVideoThumbnail(videoBytes);
    } catch (_) {
      return null;
    }
  }
}

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(ref.watch(storageServiceProvider));
});
