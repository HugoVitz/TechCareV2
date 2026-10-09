import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'api_client.dart';

/// Sessão do usuário.
///
/// - Android / iOS / desktop: o JWT fica no armazenamento seguro do sistema
///   (Keystore, Keychain, Credential Locker).
/// - Web: o navegador não oferece cofre seguro em páginas HTTP de rede local, então usa
///   o armazenamento do próprio site (localStorage). Em produção, sirva por HTTPS.
///
/// Perfis: Dono (console web, não usa o app), Admin (loja inteira) e Atendente.
class AuthService extends ChangeNotifier {
  static const _secure = FlutterSecureStorage();
  static const _kToken = 'token';
  static const _kUser = 'usuario';
  static const _kRole = 'perfil';
  static const _kLoja = 'loja';
  static const _kMust = 'must_change';
  static const _kApi = 'api_base';

  late ApiClient _api;
  void attach(ApiClient api) => _api = api;

  /// Chamado ao encerrar a sessão (limpa os dados guardados no aparelho).
  Future<void> Function()? onLogout;

  bool ready = false;
  String? token;
  String? usuario;
  String? perfil;
  String? lojaNome;
  bool mustChange = false;

  /// Perfil exibido no menu (vem de conta/me).
  String? nomeExibicao;
  String? foto;
  String? cargo;
  String? etnia;
  bool lider = false;
  String apiBase = AppConfig.defaultApiBase;

  /// Mensagem mostrada no login quando a sessão foi derrubada (ex.: falta de pagamento).
  String? notice;

  bool get isLogged => token != null && token!.isNotEmpty;
  bool get isAdmin => perfil == 'Admin';

  // ---------------- armazenamento (por plataforma) ----------------

  Future<String?> _read(String key) async {
    try {
      if (kIsWeb) return (await SharedPreferences.getInstance()).getString('tc.auth.$key');
      return await _secure.read(key: key);
    } catch (_) {
      return null; // cofre indisponível: o usuário só precisa entrar de novo
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      if (kIsWeb) {
        await (await SharedPreferences.getInstance()).setString('tc.auth.$key', value);
      } else {
        await _secure.write(key: key, value: value);
      }
    } catch (_) {
      // sessão fica só em memória
    }
  }

  Future<void> _delete(String key) async {
    try {
      if (kIsWeb) {
        await (await SharedPreferences.getInstance()).remove('tc.auth.$key');
      } else {
        await _secure.delete(key: key);
      }
    } catch (_) {}
  }

  // ---------------- ciclo de vida ----------------

  Future<void> init() async {
    token = await _read(_kToken);
    usuario = await _read(_kUser);
    perfil = await _read(_kRole);
    lojaNome = await _read(_kLoja);
    mustChange = (await _read(_kMust)) == '1';
    apiBase = await _read(_kApi) ?? AppConfig.defaultApiBase;
    ready = true;
    notifyListeners();
  }

  /// Aceita "192.168.0.15:5000", "http://192.168.0.15:5000" ou a URL completa com /api.
  static String normalizeApiBase(String value) {
    var v = value.trim();
    if (v.isEmpty) return AppConfig.defaultApiBase;
    if (!v.startsWith('http://') && !v.startsWith('https://')) v = 'http://$v';
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (!v.endsWith('/api')) v = '$v/api';
    return v;
  }

  Future<void> setApiBase(String value) async {
    apiBase = normalizeApiBase(value);
    await _write(_kApi, apiBase);
    notifyListeners();
  }

  /// Testa o endereço informado sem salvá-lo.
  Future<String> testConnection(String value) => _api.checkHealth(normalizeApiBase(value));

  Future<void> login(String user, String password) async {
    final data = await _api.send(
      'POST',
      'auth/login',
      body: {'usuario': user.trim(), 'senha': password},
      authenticated: false,
    ) as Map;

    final role = (data['perfil'] ?? 'Atendente') as String;
    if (role == 'Dono') {
      throw ApiException(403, 'Esta é uma conta do Dono do sistema. Use o Console do Dono (navegador, porta 5100).');
    }
    await _saveSession(data, user);
  }

  Future<void> _saveSession(Map data, String fallbackUser) async {
    token = data['token'] as String;
    usuario = (data['usuario'] ?? fallbackUser) as String;
    perfil = (data['perfil'] ?? 'Atendente') as String;
    lojaNome = data['lojaNome'] as String?;
    mustChange = data['deveTrocarSenha'] == true;
    notice = null;

    await _write(_kToken, token!);
    await _write(_kUser, usuario!);
    await _write(_kRole, perfil!);
    await _write(_kLoja, lojaNome ?? '');
    await _write(_kMust, mustChange ? '1' : '0');
    notifyListeners();
  }

  /// Troca a senha. Com senha provisória a atual não é exigida.
  Future<void> changePassword({String? atual, required String nova}) async {
    final data = await _api.send(
      'POST',
      'auth/trocar-senha',
      body: {'senhaAtual': (atual == null || atual.isEmpty) ? null : atual, 'novaSenha': nova},
    ) as Map;
    await _saveSession(data, usuario ?? '');
  }

  /// O servidor exigiu a troca de senha (403 trocarSenha).
  void requirePasswordChange() {
    if (!mustChange) {
      mustChange = true;
      notifyListeners();
    }
  }

  /// Sessão derrubada pelo servidor: sai do app e mostra o motivo na tela de login.
  Future<void> expireSession(String motivo) async {
    if (!isLogged) return;
    await _clear();
    notice = motivo;
    notifyListeners();
  }

  /// Saída voluntária. Encerra a sessão também no servidor (se houver conexão).
  Future<void> logout() async {
    if (isLogged) {
      try {
        await _api.send('POST', 'auth/logout', timeout: const Duration(seconds: 4));
      } catch (_) {
        // sem conexão: a sessão do aparelho é apagada mesmo assim
      }
    }
    await _clear();
    notifyListeners();
  }

  /// Busca nome, cargo, foto e se é o 1º do ranking do mês.
  Future<void> refreshProfile() async {
    try {
      final d = await _api.send('GET', 'conta/me');
      final m = Map<String, dynamic>.from(d as Map);
      nomeExibicao = m['nome'] as String?;
      cargo = m['cargo'] as String?;
      foto = m['fotoPerfilBase64'] as String?;
      etnia = m['etnia'] as String?;
      lider = m['lider'] == true;
      notifyListeners();
    } catch (_) {
      // offline: mantém o que já tinha
    }
  }

  Future<void> saveProfile(String nome, String cargoNovo) async {
    await _api.send('PUT', 'conta/me', body: {'nome': nome, 'cargo': cargoNovo, 'etnia': etnia});
    await refreshProfile();
  }

  /// [dataUrl] vazio remove a foto.
  Future<void> saveFoto(String dataUrl) async {
    await _api.send('PUT', 'conta/foto', body: {'fotoPerfilBase64': dataUrl});
    await refreshProfile();
  }

  Future<void> _clear() async {
    nomeExibicao = null;
    foto = null;
    cargo = null;
    etnia = null;
    lider = false;
    token = null;
    usuario = null;
    perfil = null;
    lojaNome = null;
    mustChange = false;
    await _delete(_kToken);
    await _delete(_kUser);
    await _delete(_kRole);
    await _delete(_kLoja);
    await _delete(_kMust);
    final cb = onLogout;
    if (cb != null) await cb();
  }
}
