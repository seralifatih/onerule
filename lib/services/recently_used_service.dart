import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentlyUsedService {
  static const String _recentAccessMapKey = 'recentAccessMap';
  static const String _hideRecentlyUsedKey = 'hideRecentlyUsed';

  Future<Map<String, int>> readAccessMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentAccessMapKey);
    if (raw == null || raw.isEmpty) {
      return <String, int>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, int>{};
      }
      return <String, int>{
        for (final entry in decoded.entries)
          if (entry.value is int) entry.key: entry.value as int,
      };
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> markAccessed(String entryId) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await readAccessMap();
    map[entryId] = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_recentAccessMapKey, jsonEncode(map));
  }

  Future<List<String>> getTopIds({
    required Set<String> allowedIds,
    int limit = 5,
  }) async {
    final map = await readAccessMap();
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .where((entry) => allowedIds.contains(entry.key))
        .take(limit)
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  Future<bool> isHidden() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideRecentlyUsedKey) ?? false;
  }

  Future<void> setHidden(bool hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideRecentlyUsedKey, hidden);
  }
}
