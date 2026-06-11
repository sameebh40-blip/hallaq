import 'dart:typed_data';
import 'dart:ui' as ui;

Future<Uint8List> resizeToPng({
  required Uint8List bytes,
  required int maxWidth,
  required int maxHeight,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final srcW = image.width.toDouble();
  final srcH = image.height.toDouble();

  final scaleW = maxWidth / srcW;
  final scaleH = maxHeight / srcH;
  final scale = scaleW < scaleH ? scaleW : scaleH;
  final effectiveScale = scale.clamp(0.0, 1.0);

  final outW = (srcW * effectiveScale).round().clamp(1, maxWidth);
  final outH = (srcH * effectiveScale).round().clamp(1, maxHeight);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final srcRect = ui.Rect.fromLTWH(0, 0, srcW, srcH);
  final dstRect = ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
  canvas.drawImageRect(image, srcRect, dstRect, ui.Paint()..filterQuality = ui.FilterQuality.high);
  final picture = recorder.endRecording();
  final out = await picture.toImage(outW, outH);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

Future<Uint8List> cropAndResizeToPng({
  required Uint8List bytes,
  required double aspectRatio,
  required int maxWidth,
  required int maxHeight,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final srcW = image.width.toDouble();
  final srcH = image.height.toDouble();
  final srcAspect = srcW / srcH;

  late final double cropW;
  late final double cropH;
  if (srcAspect > aspectRatio) {
    cropH = srcH;
    cropW = cropH * aspectRatio;
  } else {
    cropW = srcW;
    cropH = cropW / aspectRatio;
  }

  final left = (srcW - cropW) / 2;
  final top = (srcH - cropH) / 2;
  final srcRect = ui.Rect.fromLTWH(left, top, cropW, cropH);

  final scale = (maxWidth / cropW).clamp(0.0, double.infinity);
  final scaledH = cropH * scale;
  final effectiveScale = scaledH > maxHeight ? (maxHeight / cropH) : scale;

  final outW = (cropW * effectiveScale).round().clamp(1, maxWidth);
  final outH = (cropH * effectiveScale).round().clamp(1, maxHeight);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final dstRect = ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
  canvas.drawImageRect(image, srcRect, dstRect, ui.Paint()..filterQuality = ui.FilterQuality.high);
  final picture = recorder.endRecording();
  final out = await picture.toImage(outW, outH);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

Future<Uint8List> cropAvatarPng(Uint8List bytes) {
  return cropAndResizeToPng(
    bytes: bytes,
    aspectRatio: 1,
    maxWidth: 512,
    maxHeight: 512,
  );
}

Future<Uint8List> cropCoverPng(Uint8List bytes) {
  return cropAndResizeToPng(
    bytes: bytes,
    aspectRatio: 16 / 9,
    maxWidth: 1280,
    maxHeight: 720,
  );
}

String pngContentType() => 'image/png';
