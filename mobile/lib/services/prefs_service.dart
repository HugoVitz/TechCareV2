import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'tts_service.dart';
import 'vlibras.dart';

/// Preferências do usuário (mesmas da tela Configurações do site):
/// tema escuro, cor principal, compactar tabelas, tamanho da fonte, alto contraste, VLibras
/// e leitura por voz. Ficam no servidor (PUT /preferencias/me) e uma cópia no aparelho,
/// então o visual aparece certo mesmo antes de a rede responder ou sem conexão.
class PrefsService extends ChangeNotifier {
  PrefsService(this._api, this._tts);

  final ApiClient _api;
  final TtsService _tts;

  static const _kLocal = 'tc.prefs';
  static const _kVoz = 'tc.leituraVoz';

  static const corPadrao = '#2563eb';

  bool escuro = false;
  String cor = corPadrao;
  bool compactar = false;
  double fonte = 1.0;
  bool libras = false;
  bool altoContraste = false;
  bool leituraVoz = false;

  /// Carrega a cópia local (rápido, antes do login terminar).
  Future<void> loadLocal() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLocal);
    if (raw != null) {
      try {
        _apply(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
    leituraVoz = p.getBool(_kVoz) ?? false;
    _tts.enabled = leituraVoz;
    _syncLibras();
    notifyListeners();
  }

  /// Busca as preferências do servidor (após o login).
  Future<void> loadRemote() async {
    try {
      final data = await _api.send('GET', 'preferencias/me');
      if (data is Map) {
        _apply(Map<String, dynamic>.from(data));
        await _saveLocal();
        _syncLibras();
        notifyListeners();
      }
    } on NetworkException {
      // offline: segue com a cópia local
    } on ApiException {
      // sessão inválida etc.: tratado pelo ApiClient
    }
  }

  void _apply(Map<String, dynamic> m) {
    escuro = (m['tema'] ?? 'light') == 'dark';
    cor = (m['corPrincipal'] ?? corPadrao).toString();
    compactar = m['compactarTabelas'] == true;
    fonte = ((m['fatorFonte'] ?? 1.0) as num).toDouble().clamp(0.8, 1.5).toDouble();
    libras = m['libras'] == true;
    altoContraste = m['altoContraste'] == true;
  }

  Map<String, dynamic> toJson() => {
        'tema': escuro ? 'dark' : 'light',
        'corPrincipal': cor,
        'compactarTabelas': compactar,
        'fatorFonte': double.parse(fonte.toStringAsFixed(1)),
        'libras': libras,
        'altoContraste': altoContraste,
      };

  Future<void> _saveLocal() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocal, jsonEncode(toJson()));
  }

  void _syncLibras() => VLibras.setEnabled(libras);

  /// Aplica na tela, guarda no aparelho e envia ao servidor (se houver conexão).
  Future<void> _commit() async {
    _syncLibras();
    notifyListeners();
    await _saveLocal();
    try {
      await _api.send('PUT', 'preferencias/me', body: toJson());
    } on NetworkException {
      // fica salvo no aparelho; o servidor recebe na próxima alteração
    } on ApiException {
      // ignorado: as preferências locais continuam valendo
    }
  }

  Future<void> setEscuro(bool v) { escuro = v; return _commit(); }
  Future<void> setCor(String v) { cor = v; return _commit(); }
  Future<void> setCompactar(bool v) { compactar = v; return _commit(); }
  Future<void> setLibras(bool v) { libras = v; return _commit(); }
  Future<void> setAltoContraste(bool v) { altoContraste = v; return _commit(); }

  /// Passos de 10%, entre 80% e 150% (como A- / A+ do site).
  Future<void> mudarFonte(double delta) {
    fonte = ((fonte + delta) * 10).round() / 10;
    fonte = fonte.clamp(0.8, 1.5).toDouble();
    return _commit();
  }

  Future<void> restaurarPadrao() {
    escuro = false;
    cor = corPadrao;
    compactar = false;
    fonte = 1.0;
    libras = false;
    altoContraste = false;
    return _commit();
  }

  Future<void> setLeituraVoz(bool v) async {
    leituraVoz = v;
    _tts.enabled = v;
    if (!v) await _tts.stop();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kVoz, v);
  }
}
