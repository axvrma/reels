import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('navigator.mediaSession')
external JSObject? get _mediaSession;

@JS('navigator.mediaSession.setActionHandler')
external void _setActionHandler(String action, JSFunction? handler);

void setupMediaSessionControls({VoidCallback? onNext, VoidCallback? onPrev}) {
  try {
    if (_mediaSession != null) {
      if (onNext != null) {
        _setActionHandler('nexttrack', onNext.toJS);
      }
      if (onPrev != null) {
        _setActionHandler('previoustrack', onPrev.toJS);
      }
    }
  } catch (e) {
    debugPrint('MediaSession setup failed: $e');
  }
}
