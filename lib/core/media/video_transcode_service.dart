import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'video_transcode_service_stub.dart'
    if (dart.library.io) 'video_transcode_service_io.dart'
    if (dart.library.html) 'video_transcode_service_web.dart';

final videoTranscodeServiceProvider = Provider<VideoTranscodeService>((ref) => VideoTranscodeService());
