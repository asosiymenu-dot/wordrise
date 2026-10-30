import 'package:flutter_tts/flutter_tts.dart';

class PronunciationService {
  PronunciationService._();

  static final instance = PronunciationService._();

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    try {
      if (!_configured) {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(.44);
        await _tts.setPitch(1.0);
        _configured = true;
      }
      await _tts.stop();
      await _tts.speak(clean);
    } on Object {
      // Browser/device speech engines are optional and must not break a quiz.
    }
  }

  Future<void> stop() => _tts.stop();
}
