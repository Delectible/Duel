import 'package:shared_preferences/shared_preferences.dart';

import 'account.dart';

/// Keeps the account in shared preferences on the phone.
class PrefsStore implements AccountStore {
  PrefsStore(this._prefs);

  static const _key = 'duel.account';
  final SharedPreferences _prefs;

  @override
  String? load() => _prefs.getString(_key);

  @override
  void save(String json) => _prefs.setString(_key, json);
}
