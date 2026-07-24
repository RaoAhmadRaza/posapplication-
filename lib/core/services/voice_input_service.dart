import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  // The in-flight listen call. `_speech.listen()` returns as soon as listening
  // STARTS, not when speech ends — so the result is delivered later via the
  // onResult callback / pause / timeout, which complete this.
  Completer<String?>? _active;
  String _lastWords = '';

  bool get isListening => _speech.isListening;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (_) => _finish(null),
      onStatus: (status) {
        // Recogniser stopped on its own (pause/limit) without a final result.
        if (status == 'done' || status == 'notListening') {
          _finish(_lastWords.isEmpty ? null : _lastWords);
        }
      },
    );
    return _initialized;
  }

  void _finish(String? text) {
    final completer = _active;
    _active = null;
    if (completer != null && !completer.isCompleted) completer.complete(text);
  }

  /// Listen until the speaker pauses (or [timeout]). [onPartial] streams live
  /// text; the returned future resolves with the final transcript, or null.
  Future<String?> listen({
    void Function(String partial)? onPartial,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final available = await _ensureInitialized();
    if (!available) return null;
    if (!await _speech.hasPermission) return null;
    if (_speech.isListening) await _speech.stop();

    _lastWords = '';
    final completer = Completer<String?>();
    _active = completer;

    await _speech.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        onPartial?.call(_lastWords);
        if (result.finalResult) {
          _finish(_lastWords.isEmpty ? null : _lastWords);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        listenFor: timeout,
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
      ),
    );

    // Safety net: if no final result / status arrives, return the best partial.
    Timer(timeout + const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        _speech.stop();
        _finish(_lastWords.isEmpty ? null : _lastWords);
      }
    });

    return completer.future;
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
    _finish(_lastWords.isEmpty ? null : _lastWords);
  }

  void cancel() {
    _speech.cancel();
    _finish(null);
  }
}
