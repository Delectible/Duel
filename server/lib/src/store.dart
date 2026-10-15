import 'dart:convert';

/// A document: plain JSON-like data (String, num, bool, null, List, Map).
typedef Doc = Map<String, Object?>;

/// Reads and writes inside one transaction: everything read is checked for
/// changes when it commits, so two moves can't race each other.
abstract interface class Tx {
  Future<Doc?> get(String path);
  void set(String path, Doc doc);
  void delete(String path);
}

/// Where parties and matches live: Firestore in production, memory in
/// tests. Paths look like `matches/abc` or `matches/abc/hands/uid`.
abstract interface class Store {
  /// Runs [body] in a transaction, retrying if what it read changed.
  Future<T> transaction<T>(Future<T> Function(Tx tx) body);

  Future<Doc?> get(String path);
}

/// An in-memory store for tests and local runs. Transactions are serial
/// (one at a time), which is all the referee needs to be correct.
class MemoryStore implements Store {
  final Map<String, String> _docs = {};
  Future<void> _queue = Future.value();

  /// Every write, for tests to look at.
  Map<String, Doc> get docs => {for (final e in _docs.entries) e.key: _decode(e.value)};

  static Doc _decode(String s) => (jsonDecode(s) as Map).cast<String, Object?>();

  @override
  Future<Doc?> get(String path) async {
    final s = _docs[path];
    return s == null ? null : _decode(s);
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Tx tx) body) {
    final run = _queue.then((_) async {
      final tx = _MemoryTx(this);
      final result = await body(tx);
      tx._commit();
      return result;
    });
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }
}

class _MemoryTx implements Tx {
  _MemoryTx(this._store);

  final MemoryStore _store;
  final Map<String, String?> _writes = {};

  @override
  Future<Doc?> get(String path) async {
    if (_writes.containsKey(path)) {
      final w = _writes[path];
      return w == null ? null : MemoryStore._decode(w);
    }
    return _store.get(path);
  }

  @override
  void set(String path, Doc doc) => _writes[path] = jsonEncode(doc);

  @override
  void delete(String path) => _writes[path] = null;

  void _commit() {
    for (final e in _writes.entries) {
      if (e.value == null) {
        _store._docs.remove(e.key);
      } else {
        _store._docs[e.key] = e.value!;
      }
    }
  }
}
