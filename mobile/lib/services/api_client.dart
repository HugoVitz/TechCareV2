import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Sem conexão (ou servidor inacessível): o app cai para o modo offline.
class NetworkException implements Exception {
  NetworkException([this.detail = '']);

  /// Motivo técnico (timeout, conexão recusada, DNS...), útil para diagnosticar.
  final String detail;

  @override
  String toString() =>
      detail.isEmpty ? 'Sem conexão com o servidor.' : 'Sem conexão com o servidor ($detail).';
}

/// Erro devolvido pela API (validação, permissão, conflito...).
class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => message;
}

/// Token inválido/expirado: o usuário precisa entrar novamente.
class UnauthorizedException extends ApiException {
  UnauthorizedException([String? motivo]) : super(401, motivo ?? 'Sessão expirada. Entre novamente.');
}

/// Senha provisória: só é possível trocar a senha até definir uma nova.
class MustChangePasswordException extends ApiException {
  MustChangePasswordException() : super(403, 'Defina uma nova senha para continuar.');
}

/// Cliente HTTP da API REST (ASP.NET Core). Anexa o JWT automaticamente.
class ApiClient {
  ApiClient(this._auth);

  final AuthService _auth;
  final http.Client _http = http.Client();

  Future<dynamic> send(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.tryParse('${baseUrl ?? _auth.apiBase}/$path');
    if (uri == null || uri.host.isEmpty) {
      throw NetworkException('endereço da API inválido: ${baseUrl ?? _auth.apiBase}');
    }
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';

    if (authenticated && _auth.token != null) {
      request.headers['Authorization'] = 'Bearer ${_auth.token}';
    }
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw NetworkException(
          'tempo esgotado em ${uri.host}:${uri.port} - API desligada, IP errado ou Firewall bloqueando');
    } catch (e) {
      // SocketException (celular/desktop), ClientException (web) e afins: tudo vira "sem conexão".
      throw NetworkException('$e');
    }

    if (response.statusCode == 401 && authenticated) {
      // Sessão derrubada (pagamento, bloqueio, senha redefinida...): mostra o motivo no login.
      final motivo = _jsonField(response, 'mensagem');
      await _auth.expireSession(motivo ?? 'Sua sessão terminou. Entre novamente.');
      throw UnauthorizedException(motivo);
    }

    if (response.statusCode == 403 && authenticated && _jsonField(response, 'trocarSenha') == 'true') {
      _auth.requirePasswordChange();
      throw MustChangePasswordException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _extractMessage(response));
    }

    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
          response.statusCode, 'O endereço respondeu, mas não parece ser a API do TechCare.');
    }
  }

  /// Testa API + banco (GET /api/health, público). Lança [NetworkException] ou [ApiException].
  Future<String> checkHealth(String baseUrl) async {
    final data = await send(
      'GET',
      'health',
      authenticated: false,
      baseUrl: baseUrl,
      timeout: const Duration(seconds: 6),
    );
    final m = Map<String, dynamic>.from(data as Map);
    return 'API: ${m['api']}  |  Banco de dados: ${m['banco']}';
  }

  /// Lê um campo de um corpo JSON simples (retorna como texto) ou null.
  String? _jsonField(http.Response r, String field) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map && d[field] != null) return d[field].toString();
    } catch (_) {}
    return null;
  }

  String _extractMessage(http.Response r) {
    final texto = _jsonField(r, 'mensagem');
    if (texto != null) return texto;

    switch (r.statusCode) {
      case 403:
        final t = utf8.decode(r.bodyBytes).trim().replaceAll('"', '');
        return t.isNotEmpty && !t.startsWith('{') ? t : 'Você não tem permissão para esta ação.';
      case 404:
        return 'Registro não encontrado.';
      case 429:
        return 'Muitas tentativas. Aguarde um minuto e tente novamente.';
      case 503:
        return 'A API está no ar, mas o banco de dados não respondeu.';
    }

    final text = utf8.decode(r.bodyBytes).trim();
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['errors'] is Map) {
        final msgs = (decoded['errors'] as Map)
            .values
            .expand((v) => v is List ? v : [v])
            .map((e) => e.toString())
            .toList();
        if (msgs.isNotEmpty) return msgs.join(' ');
      }
      if (decoded is String) return decoded;
    } catch (_) {
      // corpo em texto puro
    }
    if (text.isEmpty) return 'Erro ${r.statusCode} ao chamar a API.';
    return text.replaceAll('"', '');
  }
}
