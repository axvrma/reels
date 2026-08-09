import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

class ReelsAudioHandler extends BaseAudioHandler {
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;

  ReelsAudioHandler() {
    // Initial state
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: false,
    ));
  }

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
    return super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
    return super.skipToPrevious();
  }

  @override
  Future<void> play() async {
    // We let the app handle actual playback; this just updates the notification UI.
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
    ));
    return super.play();
  }

  @override
  Future<void> pause() async {
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
    ));
    return super.pause();
  }

  @override
  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }
}

late ReelsAudioHandler audioHandler;

Future<void> initAudioService() async {
  audioHandler = await AudioService.init(
    builder: () => ReelsAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.vibes.app.channel.audio',
      androidNotificationChannelName: 'Vibes Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
