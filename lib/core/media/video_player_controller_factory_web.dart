import 'package:video_player/video_player.dart';

VideoPlayerController createVideoControllerImpl(String path) {
  return VideoPlayerController.networkUrl(Uri.parse(path));
}
