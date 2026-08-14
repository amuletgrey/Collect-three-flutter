import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// Local persistence: best scores, chosen skin, accessibility settings.
///
/// Keys are namespaced and versioned so a future format change can migrate
/// rather than silently reset somebody's records.
class StorageService {
  StorageService(this._prefs);

  static Future<StorageService> open() async =>
      StorageService(await SharedPreferences.getInstance());

  static const String _prefix = 'ct1';
  static const String _skinKey = '$_prefix.skin';
  static const String _symbolsKey = '$_prefix.symbols';
  static const String _reducedMotionKey = '$_prefix.reducedMotion';
  static const String _performanceKey = '$_prefix.performanceMode';
  static const String _hapticsKey = '$_prefix.haptics';

  final SharedPreferences _prefs;

  String? get skinId => _prefs.getString(_skinKey);
  Future<void> setSkinId(String id) => _prefs.setString(_skinKey, id);

  bool get showSymbols => _prefs.getBool(_symbolsKey) ?? false;
  Future<void> setShowSymbols({required bool value}) =>
      _prefs.setBool(_symbolsKey, value);

  bool get reducedMotion => _prefs.getBool(_reducedMotionKey) ?? false;
  Future<void> setReducedMotion({required bool value}) =>
      _prefs.setBool(_reducedMotionKey, value);

  bool get performanceMode => _prefs.getBool(_performanceKey) ?? false;
  Future<void> setPerformanceMode({required bool value}) =>
      _prefs.setBool(_performanceKey, value);

  bool get haptics => _prefs.getBool(_hapticsKey) ?? true;
  Future<void> setHaptics({required bool value}) =>
      _prefs.setBool(_hapticsKey, value);

  /// The run in progress for a mode, if there is one.
  ///
  /// A save from an older format is dropped rather than guessed at, and a
  /// corrupt one is treated the same way — a lost run is annoying, a crash on
  /// launch is worse.
  RunSnapshot? savedRun(String modeId) {
    final raw = _prefs.getString('$_prefix.run.$modeId');
    if (raw == null) return null;
    try {
      final snapshot = RunSnapshot.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
      return snapshot.isCurrent ? snapshot : null;
    } on Object {
      return null;
    }
  }

  Future<void> saveRun(RunSnapshot snapshot) => _prefs.setString(
    '$_prefix.run.${snapshot.modeId}',
    jsonEncode(snapshot.toJson()),
  );

  Future<void> clearRun(String modeId) => _prefs.remove('$_prefix.run.$modeId');

  int bestFor(String modeId) => _prefs.getInt('$_prefix.best.$modeId') ?? 0;

  /// 0 = not cleared, 1–3 = stars earned.
  int starsFor(String packId, int levelNumber) =>
      _prefs.getInt('$_prefix.stars.$packId.$levelNumber') ?? 0;

  /// Keeps the best result: replaying a level can never lose you a star.
  Future<bool> recordStars(String packId, int levelNumber, int stars) async {
    if (stars <= starsFor(packId, levelNumber)) return false;
    await _prefs.setInt('$_prefix.stars.$packId.$levelNumber', stars);
    return true;
  }

  /// Stores [score] if it beats the record, and reports whether it did.
  Future<bool> recordScore(String modeId, int score) async {
    if (score <= bestFor(modeId)) return false;
    await _prefs.setInt('$_prefix.best.$modeId', score);
    return true;
  }
}
