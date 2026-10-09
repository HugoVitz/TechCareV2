import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/local_db.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ListResult {
  ListResult(this.items, {required this.fromCache});
  final List<Map<String, dynamic>> items;
  final bool fromCache;
}

class SaveResult {
  SaveResult(this.item, {required this.queued});
  final Map<String, dynamic> item;

  /// true = salvo apenas no aparelho; será enviado quando houver conexão.
  final bool queued;
}

/// Camada de dados "offline-first":
///  - leituras: tenta a API, grava o resultado no SQLite e, sem rede, devolve o cache;
///  - escritas: tenta a API; sem rede, grava no cache + fila e sincroniza depois;
///  - sincronização: automática ao voltar a conexão e manual pelo botão da barra.
///
/// Registros criados offline recebem id negativo até o servidor devolver o id real.
class DataService extends ChangeNotifier {
  DataService(this._api, this._db, this._auth);

  final ApiClient _api;
  final LocalDb _db;
  final AuthService _auth;

  static const _paths = {
    'clientes': 'pacientes',
    'servicos': 'servicos',
    'produtos': 'produtos',
    'equipe': 'equipe',
    'ordens': 'ordens-servico',
    'agendamentos': 'agendamentos',
  };

  bool online = true;
  bool syncing = false;
  int pendingCount = 0;

  /// Incrementa quando uma sincronização altera dados; as telas recarregam ao perceber.
  int version = 0;
  String? lastError;

  StreamSubscription? _connSub;

  // ------------------------------------------------------------------ ciclo de vida

  void start() {
    _connSub ??= Connectivity().onConnectivityChanged.listen((_) => syncNow());
    refreshPending();
    syncNow();
  }

  void stop() {
    _connSub?.cancel();
    _connSub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  Future<void> clearLocal() async {
    await _db.clearAll();
    pendingCount = 0;
    notifyListeners();
  }

  Future<void> refreshPending() async {
    pendingCount = await _db.pendingCount();
    notifyListeners();
  }

  void _setOnline(bool value) {
    if (online != value) {
      online = value;
      notifyListeners();
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on UnauthorizedException {
      // O ApiClient já encerrou a sessão e guardou o motivo para a tela de login.
      rethrow;
    }
  }

  // ------------------------------------------------------------------ leituras

  Future<ListResult> list(String entity) async {
    try {
      if (pendingCount > 0) await syncNow();
      final data = await _guard(() => _api.send('GET', _paths[entity]!));
      final items = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await _db.cacheReplaceServer(entity, items);
      _setOnline(true);
      return ListResult(await _db.cacheList(entity), fromCache: false);
    } on NetworkException {
      _setOnline(false);
      return ListResult(await _db.cacheList(entity), fromCache: true);
    }
  }

  Future<Map<String, dynamic>> dashboard() async {
    try {
      final data = await _guard(() => _api.send('GET', 'dashboard'));
      final map = Map<String, dynamic>.from(data as Map);
      await _db.cachePut('dashboard', 0, map);
      _setOnline(true);
      return map;
    } on NetworkException {
      _setOnline(false);
      return await _db.cacheGet('dashboard', 0) ?? <String, dynamic>{};
    }
  }

  /// Histórico filtrado (somente Administrador, exige conexão).
  Future<Map<String, dynamic>> historico(Map<String, String> filtros) async {
    final qs = Uri(queryParameters: filtros.isEmpty ? null : filtros).query;
    final data = await _guard(() => _api.send('GET', qs.isEmpty ? 'historico' : 'historico?$qs'));
    _setOnline(true);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Lista da equipe (para o filtro de vendedor).
  Future<List<Map<String, dynamic>>> equipe() async {
    final data = await _guard(() => _api.send('GET', 'usuarios'));
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Faturamento por dia/semana/mês/ano (Administrador; exige conexão).
  Future<Map<String, dynamic>> financeiro(Map<String, String> filtros) async {
    final qs = Uri(queryParameters: filtros).query;
    final data = await _guard(() => _api.send('GET', 'financeiro?$qs'));
    _setOnline(true);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Presença: avisa que o app está aberto (online=true) ou que foi fechado/minimizado (false).
  Future<void> presenca(bool online) async {
    try {
      await _api.send('POST', online ? 'conta/presenca' : 'conta/saiu', timeout: const Duration(seconds: 5));
    } catch (_) {
      // sem rede: o servidor derruba sozinho em 90 s sem batimento
    }
  }

  /// Ranking de vendas do mês (cache para quando estiver offline).
  Future<Map<String, dynamic>> ranking() async {
    try {
      final data = await _guard(() => _api.send('GET', 'ranking'));
      final map = Map<String, dynamic>.from(data as Map);
      await _db.cachePut('ranking', 0, map);
      _setOnline(true);
      return map;
    } on NetworkException {
      _setOnline(false);
      return await _db.cacheGet('ranking', 0) ?? <String, dynamic>{};
    }
  }

  // ------------------------------------------------------------------ escritas

  /// Cria (id == 0) ou atualiza (id > 0) um registro. Sem rede, enfileira.
  Future<SaveResult> save(String entity, Map<String, dynamic> body) async {
    final id = (body['id'] as int?) ?? 0;
    final path = _paths[entity]!;

    // Edição de algo criado offline: atualiza o POST que ainda está na fila.
    if (id < 0) {
      final merged = await _mergePendingCreate(entity, id, body);
      return SaveResult(merged, queued: true);
    }

    // OS que aponta para um cliente ainda não sincronizado precisa esperar o id real:
    // entra na fila (que respeita a ordem) e a sincronização corrige o clienteId.
    if (entity == 'ordens' && ((body['clienteId'] as int?) ?? 0) < 0) {
      final queuedResult = await _enqueueSave(entity, path, id, body);
      unawaited(syncNow());
      return queuedResult;
    }

    try {
      final dynamic res = id == 0
          ? await _guard(() => _api.send('POST', path, body: _clean(body)))
          : await _guard(() => _api.send('PUT', '$path/$id', body: _clean(body)));
      final item = _toCacheItem(entity, Map<String, dynamic>.from(res as Map));
      await _db.cachePut(entity, item['id'] as int, item);
      _setOnline(true);
      return SaveResult(item, queued: false);
    } on NetworkException {
      _setOnline(false);
      return _enqueueSave(entity, path, id, body);
    }
  }

  Future<SaveResult> _enqueueSave(
      String entity, String path, int id, Map<String, dynamic> body) async {
    final clean = _clean(body)..remove('id');
    Map<String, dynamic> item;

    if (id == 0) {
      final opId = await _db.enqueue(entity: entity, method: 'POST', path: path, body: clean);
      final tempId = -opId;
      await _db.setPendingTempId(opId, tempId);
      final base = entity == 'ordens' ? await _buildOrderSummary(clean) : Map.of(clean);
      item = {...base, 'id': tempId, '_pendente': true};
      await _db.cachePut(entity, tempId, item);
    } else {
      await _db.enqueue(entity: entity, method: 'PUT', path: '$path/$id', body: {...clean, 'id': id});
      item = {...clean, 'id': id, '_pendente': true};
      await _db.cachePut(entity, id, item);
    }

    await refreshPending();
    return SaveResult(item, queued: true);
  }

  /// Altera o status de uma OS. Retorna true se ficou apenas na fila (offline).
  Future<bool> updateOrderStatus(int id, String status) async {
    if (id < 0) {
      await _mergePendingCreate('ordens', id, {'status': status});
      return true;
    }

    final path = 'ordens-servico/$id/status';
    try {
      await _guard(() => _api.send('PUT', path, body: {'status': status}));
      final cached = await _db.cacheGet('ordens', id);
      if (cached != null) {
        await _db.cachePut('ordens', id, {...cached, 'status': status}..remove('_pendente'));
      }
      _setOnline(true);
      return false;
    } on NetworkException {
      _setOnline(false);
      await _db.enqueue(entity: 'ordens', method: 'PUT', path: path, body: {'status': status});
      final cached = await _db.cacheGet('ordens', id);
      if (cached != null) {
        await _db.cachePut('ordens', id, {...cached, 'status': status, '_pendente': true});
      }
      await refreshPending();
      return true;
    }
  }

  /// Grava uma OS com carrinho. Exige conexão: o servidor confere estoque, preços e desconto.
  Future<Map<String, dynamic>> createOrderOnline(Map<String, dynamic> body) async {
    final data = await _guard(() => _api.send('POST', 'ordens-servico', body: body));
    _setOnline(true);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Exclusão exige conexão com o servidor.
  Future<void> delete(String entity, int id) async {
    if (id < 0) {
      final op = await _db.pendingByTempId(entity, id);
      if (op != null) await _db.deletePending(op.id);
      await _db.cacheDelete(entity, id);
      await refreshPending();
      return;
    }
    await _guard(() => _api.send('DELETE', '${_paths[entity]}/$id'));
    await _db.cacheDelete(entity, id);
  }

  // ------------------------------------------------------------------ sincronização

  Future<void> syncNow() async {
    if (syncing || !_auth.isLogged) return;
    syncing = true;
    notifyListeners();

    var changed = false;
    try {
      final ops = await _db.pendingOps();
      for (final op in ops) {
        try {
          final res = await _guard(() => _api.send(op.method, op.path, body: op.body));
          changed = true;
          _setOnline(true);

          if (op.method == 'POST' && op.tempId != null && res is Map) {
            final newId = res['id'] as int;
            await _db.cacheDelete(op.entity, op.tempId!);
            final item = _toCacheItem(op.entity, Map<String, dynamic>.from(res));
            await _db.cachePut(op.entity, newId, item);

            // OS criadas offline para um cliente também offline passam a apontar para o id real.
            if (op.entity == 'clientes') {
              await _db.remapPendingReference(
                  targetEntity: 'ordens', field: 'clienteId', from: op.tempId!, to: newId);
            }
          }
          await _db.deletePending(op.id);
        } on NetworkException {
          _setOnline(false);
          break; // mantém a fila e tenta de novo quando voltar a conexão
        } on UnauthorizedException {
          break;
        } on ApiException catch (e) {
          // O servidor recusou (validação, permissão, registro removido): descarta a operação.
          lastError = 'Uma alteração offline foi recusada: ${e.message}';
          if (op.tempId != null) await _db.cacheDelete(op.entity, op.tempId!);
          await _db.deletePending(op.id);
          changed = true;
        }
      }
    } finally {
      syncing = false;
      if (changed) version++;
      await refreshPending();
    }
  }

  // ------------------------------------------------------------------ auxiliares

  Map<String, dynamic> _clean(Map<String, dynamic> body) =>
      Map<String, dynamic>.from(body)..removeWhere((k, _) => k.startsWith('_'));

  Future<Map<String, dynamic>> _mergePendingCreate(
      String entity, int tempId, Map<String, dynamic> patch) async {
    final op = await _db.pendingByTempId(entity, tempId);
    if (op == null) {
      throw ApiException(409, 'Este registro já foi sincronizado. Atualize a lista e tente de novo.');
    }
    final cleanPatch = _clean(patch)..remove('id');
    await _db.updatePendingBody(op.id, {...op.body, ...cleanPatch});

    final cached = await _db.cacheGet(entity, tempId) ?? <String, dynamic>{'id': tempId};
    final merged = {...cached, ...cleanPatch, 'id': tempId, '_pendente': true};
    await _db.cachePut(entity, tempId, merged);
    return merged;
  }

  /// A API devolve a OS completa (com itens e imagens); o cache guarda só o resumo.
  Map<String, dynamic> _toCacheItem(String entity, Map<String, dynamic> json) {
    if (entity != 'ordens') return json;
    final itens = (json['itens'] as List?) ?? const [];
    final total = json['valorTotal'] ??
        itens.fold<num>(0, (s, i) => s + ((i as Map)['valorTotal'] as num? ?? 0));
    return {
      'id': json['id'],
      'clienteId': json['clienteId'],
      'clienteNome': json['clienteNome'],
      'profissionalId': json['profissionalId'],
      'profissionalNome': json['profissionalNome'],
      'titulo': json['titulo'],
      'descricao': json['descricao'],
      'status': json['status'],
      'dataAbertura': json['dataAbertura'],
      'dataPrevista': json['dataPrevista'],
      'dataConclusao': json['dataConclusao'],
      'valorTotal': total,
    };
  }

  Future<Map<String, dynamic>> _buildOrderSummary(Map<String, dynamic> body) async {
    final cliente = await _db.cacheGet('clientes', body['clienteId'] as int);
    final prof = await _db.cacheGet('equipe', body['profissionalId'] as int);
    num total = 0;
    for (final it in (body['itens'] as List?) ?? const []) {
      final m = it as Map;
      total += (m['quantidade'] as num) * (m['valorUnitario'] as num);
    }
    return {
      'clienteId': body['clienteId'],
      'clienteNome': cliente?['nome'] ?? '-',
      'profissionalId': body['profissionalId'],
      'profissionalNome': prof?['nome'] ?? '-',
      'titulo': body['titulo'],
      'descricao': body['descricao'],
      'status': body['status'] ?? 'Aberta',
      'dataAbertura': body['dataAbertura'],
      'dataPrevista': body['dataPrevista'],
      'dataConclusao': null,
      'valorTotal': total,
    };
  }
}
