import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime? _debugNow;
bool _debugTimeLoaded = false;

Future<void> ensureDebugTimeLoaded() async {
  if (_debugTimeLoaded) return;
  _debugTimeLoaded = true;

  if (!kDebugMode) {
    _debugNow = null;
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('debug_now_iso');
  _debugNow = raw == null ? null : DateTime.tryParse(raw);
}

DateTime getNow() {
  return _debugNow ?? DateTime.now();
}

Future<void> setDebugNow(DateTime value) async {
  if (!kDebugMode) return;
  _debugNow = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('debug_now_iso', value.toIso8601String());
}

Future<void> clearDebugNow() async {
  if (!kDebugMode) return;
  _debugNow = null;
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('debug_now_iso');
}