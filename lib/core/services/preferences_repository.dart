import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class PreferencesRepository {
  static const _keySettings = 'app_settings_v1';

  final SharedPreferences _prefs;
  PreferencesRepository(this._prefs);

  Future<AppSettings?> loadSettings() async {
    final raw = _prefs.getString(_keySettings);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return AppSettings.fromJson(map);
      if (map is Map) return AppSettings.fromJson(Map<String, dynamic>.from(map));
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final raw = jsonEncode(settings.toJson());
    await _prefs.setString(_keySettings, raw);
  }

  Future<void> clear() async {
    await _prefs.remove(_keySettings);
  }
}
