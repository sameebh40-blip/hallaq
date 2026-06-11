import 'dart:typed_data';

import '../errors/app_exception.dart';

class VideoTranscodeService {
  static const int maxReelDurationMs = 20 * 1000;

  Future<int?> readDurationMs(String inputPath) async {
    return null;
  }

  Future<Uint8List> transcodeToMp4_720p({
    required String inputPath,
    int maxDurationMs = maxReelDurationMs,
  }) async {
    throw const AppException('Video conversion is not supported on this platform.');
  }
}
