import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'adaptive_video_player.dart';

AdaptiveVideoController createPlatformVideoController() {
  return MobileVideoController();
}

class MobileVideoController implements AdaptiveVideoController {
  final Player _player = Player();
  VideoController? _videoController;
  
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorDescription;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  final List<VoidCallback> _listeners = [];

  MobileVideoController() {
    _player.stream.playing.listen((playing) {
      _isPlaying = playing;
      _notifyListeners();
    });
    
    _player.stream.position.listen((position) {
      _position = position;
      _notifyListeners();
    });
    
    _player.stream.duration.listen((duration) {
      _duration = duration;
      _notifyListeners();
    });

    _player.stream.error.listen((error) {
      _hasError = true;
      _errorDescription = error;
      _notifyListeners();
    });
  }

  VideoController? get videoController => _videoController;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get hasError => _hasError;

  @override
  String? get errorDescription => _errorDescription;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  Future<void> initialize(Uri url, {Object? file, Map<String, String>? headers}) async {
    _videoController = VideoController(_player);
    if (file != null && file is File) {
      await _player.open(Media(file.path), play: false);
    } else {
      await _player.open(Media(url.toString(), httpHeaders: headers), play: false);
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> setLooping(bool looping) async {
    await _player.setPlaylistMode(looping ? PlaylistMode.single : PlaylistMode.none);
  }

  @override
  void dispose() {
    _player.dispose();
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }
}

class PlatformVideoPlayerWidget extends StatelessWidget {
  final AdaptiveVideoController controller;
  final BoxFit fit;

  const PlatformVideoPlayerWidget({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final mobileController = controller as MobileVideoController;
    if (mobileController.videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // We disable the built-in media_kit controls since our video_feed_screen
    // handles all the play/pause/like gestures.
    return Video(
      controller: mobileController.videoController!,
      fit: fit,
      controls: NoVideoControls,
    );
  }
}
