import 'package:flutter/material.dart';
import 'video_player_mobile.dart' if (dart.library.js_interop) 'video_player_web.dart';

abstract class AdaptiveVideoController {
  bool get isPlaying;
  bool get hasError;
  String? get errorDescription;
  Duration get position;
  Duration get duration;

  Future<void> initialize(Uri url, {Object? file, Map<String, String>? headers});
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setLooping(bool looping);
  void dispose();
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}

/// A factory to create the correct controller for the current platform.
AdaptiveVideoController createAdaptiveVideoController() {
  return createPlatformVideoController();
}

/// A widget that displays the video using the provided controller.
class AdaptiveVideoPlayerWidget extends StatelessWidget {
  final AdaptiveVideoController controller;
  final BoxFit fit;
  final bool pauseUponEnteringBackgroundMode;

  const AdaptiveVideoPlayerWidget({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.pauseUponEnteringBackgroundMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformVideoPlayerWidget(
      controller: controller,
      fit: fit,
      pauseUponEnteringBackgroundMode: pauseUponEnteringBackgroundMode,
    );
  }
}
