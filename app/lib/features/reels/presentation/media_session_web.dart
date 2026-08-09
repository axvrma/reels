import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

@JS('navigator.mediaSession')
external JSObject? get _mediaSession;

@JS('navigator.mediaSession.setActionHandler')
external void _setActionHandler(String action, JSFunction? handler);

@JS('MediaMetadata')
@staticInterop
class MediaMetadata {
  external factory MediaMetadata(JSObject init);
}

@JS('navigator.mediaSession.metadata')
external set _mediaMetadata(MediaMetadata? metadata);

@JS('eval')
external JSAny? _eval(String script);

void setupMediaSessionControls({VoidCallback? onNext, VoidCallback? onPrev}) {
  try {
    if (_mediaSession != null) {
      if (onNext != null) {
        final jsOnNext = () {
          _eval("document.querySelectorAll('video').forEach(function(v) { var p = v.play(); if (p !== undefined) p.catch(function(){}); })");
          onNext();
        }.toJS;
        _setActionHandler('nexttrack', jsOnNext);
      }
      if (onPrev != null) {
        final jsOnPrev = () {
          _eval("document.querySelectorAll('video').forEach(function(v) { var p = v.play(); if (p !== undefined) p.catch(function(){}); })");
          onPrev();
        }.toJS;
        _setActionHandler('previoustrack', jsOnPrev);
      }
    }
  } catch (e) {
    debugPrint('MediaSession setup failed: $e');
  }
}

void updateMediaSessionMetadata(String title, String artist) {
  try {
    if (_mediaSession != null) {
      final init = JSObject();
      init['title'] = title.toJS;
      init['artist'] = artist.toJS;
      _mediaMetadata = MediaMetadata(init);
    }
  } catch (e) {
    debugPrint('MediaMetadata setup failed: $e');
  }
}

void clearMediaSessionMetadata() {
  try {
    if (_mediaSession != null) {
      _mediaMetadata = null;
    }
  } catch (_) {}
}
