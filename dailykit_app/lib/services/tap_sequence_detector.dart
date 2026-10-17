import 'dart:async';
import 'package:flutter/foundation.dart';

/// Detector for single-tap vs triple-tap gesture sequences.
///
/// Rules:
/// - Taps within [sequenceTimeout] (default 600 ms) count as one sequence.
/// - Single tap fires ONLY after the sequence ends with exactly 1 tap.
/// - Triple tap fires immediately upon the 3rd tap within the window.
/// - Any other tap count (e.g. exactly 2 taps) simply resets when the sequence times out without firing single tap.
class TapSequenceDetector {
  final Duration sequenceTimeout;
  final VoidCallback onSingleTap;
  final VoidCallback onTripleTap;

  int _tapCount = 0;
  Timer? _timer;

  TapSequenceDetector({
    this.sequenceTimeout = const Duration(milliseconds: 600),
    required this.onSingleTap,
    required this.onTripleTap,
  });

  int get currentTapCount => _tapCount;
  bool get isWaiting => _timer?.isActive ?? false;

  void registerTap() {
    _tapCount++;

    if (_tapCount == 3) {
      // Sequence completed with 3 taps: fire triple tap immediately
      _timer?.cancel();
      _timer = null;
      _tapCount = 0;
      onTripleTap();
      return;
    }

    if (_tapCount > 3) {
      // Over-tapped: cancel and reset
      _timer?.cancel();
      _timer = null;
      _tapCount = 0;
      return;
    }

    // Reset sequence timer for subsequent tap
    _timer?.cancel();
    _timer = Timer(sequenceTimeout, () {
      if (_tapCount == 1) {
        onSingleTap();
      }
      _tapCount = 0;
      _timer = null;
    });
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _tapCount = 0;
  }

  void dispose() {
    reset();
  }
}

