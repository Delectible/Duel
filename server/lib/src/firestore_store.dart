// The REST client is marked deprecated in favour of
// google_cloud_firestore_v1, which is still pre-1.0; swap when it's stable.
// ignore: deprecated_member_use
import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:http/http.dart' as http;

import 'store.dart';

/// [Store] on Cloud Firestore (REST). On Cloud Run it signs in as the
/// service's own account; against the emulator it needs no sign-in.
class FirestoreStore implements Store {
  FirestoreStore(http.Client client, {required String projectId, String? emulatorHost})
    : _api = fs.FirestoreApi(
        client,
        rootUrl: emulatorHost == null ? 'https://firestore.googleapis.com/' : 'http://$emulatorHost/',
      ),
      _db = 'projects/$projectId/databases/(default)';

  final fs.FirestoreApi _api;
  final String _db;

  String _name(String path) => '$_db/documents/$path';

  @override
  Future<Doc?> get(String path) async {
    try {
      final d = await _api.projects.databases.documents.get(_name(path));
      return fromFields(d.fields);
    } on fs.DetailedApiRequestError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Reads inside a transaction go through batchGet, as the official SDKs
  /// do (the emulator never answers a transactional single get).
  Future<Doc?> _txGet(String path, String transaction) async {
    final res = await _api.projects.databases.documents.batchGet(
      fs.BatchGetDocumentsRequest(documents: [_name(path)], transaction: transaction),
      _db,
    );
    final found = res.map((r) => r.found).nonNulls.firstOrNull;
    return found == null ? null : fromFields(found.fields);
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Tx tx) body) async {
    for (var attempt = 1; ; attempt++) {
      final begin = await _api.projects.databases.documents.beginTransaction(
        fs.BeginTransactionRequest(),
        _db,
      );
      final tx = _FirestoreTx(this, begin.transaction!);
      final T result;
      try {
        result = await body(tx);
      } catch (_) {
        // Let go of what we read, or the next write waits for the lock.
        await _api.projects.databases.documents
            .rollback(fs.RollbackRequest(transaction: begin.transaction), _db)
            .then((_) {}, onError: (Object _) {});
        rethrow;
      }
      try {
        await _api.projects.databases.documents.commit(
          fs.CommitRequest(transaction: begin.transaction, writes: tx.writes),
          _db,
        );
        return result;
      } on fs.DetailedApiRequestError catch (e) {
        // Someone else changed what we read (409 ABORTED): try again.
        if (e.status != 409 || attempt >= 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 40 * attempt));
      }
    }
  }

  // --- JSON <-> Firestore values ------------------------------------------

  static Doc fromFields(Map<String, fs.Value>? fields) => {
    for (final e in (fields ?? const <String, fs.Value>{}).entries) e.key: fromValue(e.value),
  };

  static Object? fromValue(fs.Value v) {
    if (v.nullValue != null) return null;
    if (v.booleanValue != null) return v.booleanValue;
    if (v.integerValue != null) return int.parse(v.integerValue!);
    if (v.doubleValue != null) return v.doubleValue;
    if (v.stringValue != null) return v.stringValue;
    if (v.timestampValue != null) return v.timestampValue;
    if (v.arrayValue != null) {
      return [for (final x in v.arrayValue!.values ?? const <fs.Value>[]) fromValue(x)];
    }
    if (v.mapValue != null) {
      final fields = v.mapValue!.fields;
      // A list that was inside a list (see [toValue]).
      if (fields != null && fields.length == 1 && fields[nestedList]?.arrayValue != null) {
        return fromValue(fields[nestedList]!);
      }
      return fromFields(fields);
    }
    return null;
  }

  /// Firestore can't hold a list directly inside a list, so an inner list
  /// is stored as a one-field map `{_list: [...]}` and unwrapped on the way
  /// back (the app unwraps it too: `unnestLists`).
  static const nestedList = '_list';

  static Map<String, fs.Value> toFields(Map<Object?, Object?> doc) => {
    for (final e in doc.entries) '${e.key}': toValue(e.value),
  };

  static fs.Value toValue(Object? v, {bool inList = false}) => switch (v) {
    null => fs.Value(nullValue: 'NULL_VALUE'),
    final bool b => fs.Value(booleanValue: b),
    final int i => fs.Value(integerValue: '$i'),
    final double d => fs.Value(doubleValue: d),
    final String s => fs.Value(stringValue: s),
    // A real timestamp, so Firestore's auto-delete (TTL) can use it.
    final DateTime t => fs.Value(timestampValue: t.toUtc().toIso8601String()),
    final List<Object?> l when inList => fs.Value(mapValue: fs.MapValue(fields: {nestedList: toValue(l)})),
    final List<Object?> l => fs.Value(
      arrayValue: fs.ArrayValue(values: [for (final x in l) toValue(x, inList: true)]),
    ),
    final Map<Object?, Object?> m => fs.Value(mapValue: fs.MapValue(fields: toFields(m))),
    _ => throw ArgumentError('Not storable: ${v.runtimeType}'),
  };
}

class _FirestoreTx implements Tx {
  _FirestoreTx(this._store, this._id);

  final FirestoreStore _store;
  final String _id;
  final List<fs.Write> writes = [];
  final Map<String, Doc?> _pending = {};

  @override
  Future<Doc?> get(String path) async {
    if (_pending.containsKey(path)) return _pending[path];
    return _store._txGet(path, _id);
  }

  @override
  void set(String path, Doc doc) {
    _pending[path] = doc;
    // One write per document in a commit: the last one wins.
    _drop(path);
    writes.add(
      fs.Write(
        update: fs.Document(name: _store._name(path), fields: FirestoreStore.toFields(doc)),
      ),
    );
  }

  @override
  void delete(String path) {
    _pending[path] = null;
    _drop(path);
    writes.add(fs.Write(delete: _store._name(path)));
  }

  void _drop(String path) {
    final name = _store._name(path);
    writes.removeWhere((w) => w.update?.name == name || w.delete == name);
  }
}
