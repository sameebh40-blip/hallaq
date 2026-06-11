import 'package:video_player/video_player.dart';

import 'video_player_controller_factory_stub.dart'
    if (dart.library.io) 'video_player_controller_factory_io.dart'
    if (dart.library.html) 'video_player_controller_factory_web.dart';

VideoPlayerController createVideoController(String path) => createVideoControllerImpl(path);
