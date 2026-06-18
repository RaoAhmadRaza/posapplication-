import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _initialized;
  }

  Future<String?> listen({
    void Function(String partial)? onPartial,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final available = await _ensureInitialized();
    if (!available) return null;

    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) return null;

    if (_speech.isListening) {
      _speech.stop();
      return null;
    }

    final completer = Completer<String?>();
    Timer? timeoutTimer;

    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        _speech.stop();
      }
    });

    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        if (result.finalResult) {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(words.isNotEmpty ? words : null);
          }
        } else {
          onPartial?.call(words);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        listenFor: timeout,
        pauseFor: const Duration(seconds: 2),
      ),
    );

    if (!completer.isCompleted) {
      completer.complete(null);
    }

    return completer.future;
  }

  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  void cancel() {
    _speech.cancel();
  }
}
