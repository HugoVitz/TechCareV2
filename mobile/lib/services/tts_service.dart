import 'package:flutter_tts/flutter_tts.dart';

/// Leitura por voz em português (equivalente ao speechSynthesis do site).
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool enabled = false;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
    } catch (_) {
      // plataforma sem voz disponível: segue em silêncio
    }
  }

  Future<void> speak(String text) async {
    if (!enabled || text.trim().isEmpty) return;
    try {
      await _init();
      await _tts.stop();
      await _tts.speak(text.trim());
    } catch (_) {}
  }

  /// Lê mesmo com a leitura por clique desativada (botão de teste nas Configurações).
  Future<void> speakAlways(String text) async {
    try {
      await _init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
