import 'dart:io';
import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

Future<Uint8List?> generateVideoThumbnail(Uint8List videoBytes) async {
  Directory? dir;
  File? file;
  try {
    dir = await Directory.systemTemp.createTemp('hallaq_video_thumb_');
    file = File('${dir.path}/video.mp4');
    await file.writeAsBytes(videoBytes, flush: true);
    return await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.PNG,
      maxWidth: 720,
      quality: 65,
    );
  } catch (_) {
    return null;
  } finally {
    try {
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    try {
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

Future<Uint8List?> generateVideoThumbnailFromUrl(String url) async {
  final u = url.trim();
  if (u.isEmpty) return null;
  try {
    return await VideoThumbnail.thumbnailData(
      video: u,
      imageFormat: ImageFormat.PNG,
      maxWidth: 720,
      quality: 65,
    );
  } catch (_) {
    return null;
  }
}
