import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';

class HistoryService {
  static const _key = 'conversion_history';
  static const _maxEntries = 100;

  final SharedPreferences _prefs;

  HistoryService(this._prefs);

  List<HistoryEntry> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return [
      for (final item in list.cast<Map<String, dynamic>>())
        ?_tryParse(item),
    ];
  }

  static HistoryEntry? _tryParse(Map<String, dynamic> json) {
    try {
      return HistoryEntry.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(HistoryEntry entry) async {
    final entries = load();
    entries.insert(0, entry);
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    await _prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
