import 'dart:io';
import 'dart:typed_data';

import 'package:video_compress/video_compress.dart';

import '../errors/app_exception.dart';

class VideoTranscodeService {
  static const int maxReelDurationMs = 20 * 1000;
  static const int maxReelUploadBytes = 50 * 1024 * 1024;

  Future<int?> readDurationMs(String inputPath) async {
    final info = await VideoCompress.getMediaInfo(inputPath);
    final duration = info.duration;
    if (duration == null) return null;
    return duration.round();
  }

  Future<Uint8List> transcodeToMp4_720p({
    required String inputPath,
    int maxDurationMs = maxReelDurationMs,
  }) async {
    final info = await VideoCompress.getMediaInfo(inputPath);
    final durationMs = (info.duration ?? 0).round();
    if (durationMs > maxDurationMs) {
      throw const AppException('Upload failed: video must be 20 seconds or less');
    }

    Uint8List? smallest;
    for (final quality in const [VideoQuality.MediumQuality, VideoQuality.LowQuality]) {
      final out = await VideoCompress.compressVideo(
        inputPath,
        quality: quality,
        includeAudio: true,
        deleteOrigin: false,
      );
      final path = out?.path;
      if (path == null || path.trim().isEmpty) {
        continue;
      }
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        continue;
      }
      if (smallest == null || bytes.lengthInBytes < smallest.lengthInBytes) {
        smallest = bytes;
      }
      if (bytes.lengthInBytes <= maxReelUploadBytes) {
        return bytes;
      }
    }
    if (smallest == null) {
      throw const AppException('Could not process this video for upload.');
    }
    throw const AppException(
      'Video is still too large after compression. Please choose a shorter video.',
    );
  }
}
