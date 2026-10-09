import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Operação de escrita aguardando envio ao servidor (fila offline).
class PendingOp {
  PendingOp({
    required this.id,
    required this.entity,
    required this.method,
    required this.path,
    required this.body,
    required this.tempId,
  });

  final int id;
  final String entity;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final int? tempId; // id negativo atribuído a registros criados offline
}

/// Armazenamento local multiplataforma (shared_preferences):
///  - cache: espelho das listas da API para uso offline;
///  - pending: fila de criações/alterações feitas sem conexão.
///
/// Usa o mesmo mecanismo no celular, no navegador e no desktop, então o app offline funciona em todos.
/// As operações são serializadas (uma por vez) para evitar condições de corrida.
class LocalDb {
  static const _kCache = 'tc.cache.';
  static const _kPending = 'tc.pending';
  static const _kSeq = 'tc.pending.seq';

  SharedPreferences? _prefs;
  Future<void> _tail = Future<void>.value();

  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  Future<T> _locked<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  // ---------------- cache ----------------

  Future<Map<String, dynamic>> _readCache(String entity) async {
    final raw = (await _p).getString('$_kCache$entity');
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _writeCache(String entity, Map<String, dynamic> map) async {
    await (await _p).setString('$_kCache$entity', jsonEncode(map));
  }

  Future<List<Map<String, dynamic>>> cacheList(String entity) => _locked(() async {
        final map = await _readCache(entity);
        return map.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });

  Future<Map<String, dynamic>?> cacheGet(String entity, int id) => _locked(() async {
        final item = (await _readCache(entity))['$id'];
        return item == null ? null : Map<String, dynamic>.from(item as Map);
      });

  Future<void> cachePut(String entity, int id, Map<String, dynamic> json) => _locked(() async {
        final map = await _readCache(entity);
        map['$id'] = json;
        await _writeCache(entity, map);
      });

  Future<void> cacheDelete(String entity, int id) => _locked(() async {
        final map = await _readCache(entity);
        map.remove('$id');
        await _writeCache(entity, map);
      });

  /// Substitui os registros vindos do servidor (id > 0), preservando os criados offline (id < 0).
  Future<void> cacheReplaceServer(String entity, List<Map<String, dynamic>> items) =>
      _locked(() async {
        final map = await _readCache(entity);
        map.removeWhere((key, _) => (int.tryParse(key) ?? 0) > 0);
        for (final item in items) {
          map['${item['id']}'] = item;
        }
        await _writeCache(entity, map);
      });

  // ---------------- fila de pendências ----------------

  Future<List<Map<String, dynamic>>> _readPending() async {
    final raw = (await _p).getString(_kPending);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _writePending(List<Map<String, dynamic>> ops) async {
    await (await _p).setString(_kPending, jsonEncode(ops));
  }

  PendingOp _toOp(Map<String, dynamic> m) => PendingOp(
        id: m['id'] as int,
        entity: m['entity'] as String,
        method: m['method'] as String,
        path: m['path'] as String,
        body: Map<String, dynamic>.from((m['body'] as Map?) ?? const {}),
        tempId: m['tempId'] as int?,
      );

  Future<int> enqueue({
    required String entity,
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) =>
      _locked(() async {
        final prefs = await _p;
        final id = (prefs.getInt(_kSeq) ?? 0) + 1;
        await prefs.setInt(_kSeq, id);

        final ops = await _readPending();
        ops.add({
          'id': id,
          'entity': entity,
          'method': method,
          'path': path,
          'body': body ?? <String, dynamic>{},
          'tempId': null,
          'createdAt': DateTime.now().toIso8601String(),
        });
        await _writePending(ops);
        return id;
      });

  Future<void> setPendingTempId(int opId, int tempId) => _locked(() async {
        final ops = await _readPending();
        for (final op in ops) {
          if (op['id'] == opId) op['tempId'] = tempId;
        }
        await _writePending(ops);
      });

  Future<List<PendingOp>> pendingOps() => _locked(() async {
        final ops = await _readPending();
        ops.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
        return ops.map(_toOp).toList();
      });

  Future<PendingOp?> pendingByTempId(String entity, int tempId) => _locked(() async {
        for (final op in await _readPending()) {
          if (op['entity'] == entity && op['tempId'] == tempId) return _toOp(op);
        }
        return null;
      });

  Future<void> updatePendingBody(int opId, Map<String, dynamic> body) => _locked(() async {
        final ops = await _readPending();
        for (final op in ops) {
          if (op['id'] == opId) op['body'] = body;
        }
        await _writePending(ops);
      });

  Future<void> deletePending(int opId) => _locked(() async {
        final ops = await _readPending();
        ops.removeWhere((op) => op['id'] == opId);
        await _writePending(ops);
      });

  Future<int> pendingCount() => _locked(() async => (await _readPending()).length);

  /// Quando um registro criado offline recebe o id real do servidor, as operações
  /// pendentes que o referenciam (ex.: clienteId de uma OS) precisam ser atualizadas.
  Future<void> remapPendingReference({
    required String targetEntity,
    required String field,
    required int from,
    required int to,
  }) =>
      _locked(() async {
        final ops = await _readPending();
        for (final op in ops) {
          if (op['entity'] != targetEntity) continue;
          final body = Map<String, dynamic>.from((op['body'] as Map?) ?? const {});
          if (body[field] == from) {
            body[field] = to;
            op['body'] = body;
          }
        }
        await _writePending(ops);
      });

  /// Apaga todos os dados locais (usado no logout).
  Future<void> clearAll() => _locked(() async {
        final prefs = await _p;
        for (final key in prefs.getKeys().where((k) => k.startsWith('tc.cache.') || k == _kPending)) {
          await prefs.remove(key);
        }
      });
}
