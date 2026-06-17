import 'dart:async';

import 'package:flutter/services.dart';

typedef SetFullScreen = Future<void> Function(bool enabled);

class WindowsFullscreenShortcuts {
  WindowsFullscreenShortcuts({
    required this.setFullScreen,
    this.escapeHoldDuration = const Duration(milliseconds: 700),
  });

  final SetFullScreen setFullScreen;
  final Duration escapeHoldDuration;

  Timer? _escapeHoldTimer;

  bool handleKey(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.f11 && event is KeyDownEvent) {
      unawaited(setFullScreen(true));
      return true;
    }

    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }

    if (event is KeyDownEvent) {
      _escapeHoldTimer ??= Timer(escapeHoldDuration, () {
        _escapeHoldTimer = null;
        unawaited(setFullScreen(false));
      });
      return true;
    }

    if (event is KeyUpEvent) {
      _escapeHoldTimer?.cancel();
      _escapeHoldTimer = null;
      return true;
    }

    // Suppress key-repeat events while Escape is being held.
    return true;
  }

  void dispose() {
    _escapeHoldTimer?.cancel();
    _escapeHoldTimer = null;
  }
}
