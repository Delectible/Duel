/// Firestore can't hold a list directly inside a list, so the referee
/// stores an inner list as `{_list: [...]}` (server: `FirestoreStore`).
/// This turns those back into lists, all the way down.
Object? unnestLists(Object? v) => switch (v) {
  final Map<Object?, Object?> m when m.length == 1 && m['_list'] is List => unnestLists(m['_list']),
  final Map<Object?, Object?> m => {for (final e in m.entries) '${e.key}': unnestLists(e.value)},
  final List<Object?> l => [for (final x in l) unnestLists(x)],
  _ => v,
};
