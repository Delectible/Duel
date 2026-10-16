import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:duel/core/online/party.dart';
import 'package:duel_server/duel_server.dart' as server;
import 'package:shelf/shelf.dart' as shelf;

/// The real referee and its HTTP routes, in memory, with Firestore's live
/// documents and read rules played by hand. Each [player] is one phone.
class FakeServer {
  FakeServer({int seed = 1}) {
    referee = server.Referee(store, rng: Random(seed), clock: () => now);
    handler = server.api(referee, const server.TrustingVerifier());
  }

  final store = server.MemoryStore();
  late final server.Referee referee;
  late final shelf.Handler handler;
  DateTime now = DateTime.utc(2026, 10, 16, 12);

  final _watchers = <_Watcher>[];

  /// The network is down (calls fail).
  bool offline = false;

  FakeBackend player(String uid) => FakeBackend(this, uid);

  /// Pushes every watched document to whoever may read it (the rules:
  /// parties to members, games to players).
  Future<void> publish() async {
    for (final w in [..._watchers]) {
      if (w.out.isClosed) {
        _watchers.remove(w);
        continue;
      }
      final doc = await store.get(w.path);
      final key = w.path.startsWith('parties/') ? 'members' : 'seats';
      final visible = doc != null && (doc[key]! as List).contains(w.uid);
      final json = visible ? jsonEncode(doc) : null;
      if (json == w.last || w.out.isClosed) continue;
      w.last = json;
      w.out.add(visible ? (jsonDecode(json!) as Map).cast<String, Object?>() : null);
    }
  }
}

class _Watcher {
  _Watcher(this.path, this.uid, this.out);
  final String path;
  final String uid;
  final StreamController<Doc?> out;
  String? last = '';
}

class FakeBackend implements OnlineBackend {
  FakeBackend(this.server, this.uid);

  final FakeServer server;
  final String uid;

  @override
  Future<String> signIn() async => uid;

  @override
  Stream<Doc?> watch(String path) {
    late final StreamController<Doc?> out;
    out = StreamController<Doc?>(
      onListen: () => scheduleMicrotask(server.publish),
      onCancel: () => out.close(),
    );
    server._watchers.add(_Watcher(path, uid, out));
    return out.stream;
  }

  @override
  Future<Doc> call(String path, [Doc body = const {}]) async {
    if (server.offline) throw StateError('offline');
    final res = await server.handler(
      shelf.Request(
        'POST',
        Uri.parse('http://referee$path'),
        headers: {'authorization': 'Bearer $uid'},
        body: jsonEncode(body),
      ),
    );
    final json = (jsonDecode(await res.readAsString()) as Map).cast<String, Object?>();
    await server.publish();
    if (res.statusCode != 200) throw OnlineError('${json['error']}');
    return json;
  }
}
