import 'dart:async';

import 'package:flutter/widgets.dart';

import 'engine/engine.dart';
import 'game/motion.dart';
import 'services/storage_service.dart';
import 'skins/skin.dart';
import 'skins/skin_registry.dart';

/// App-wide preferences and records. One of only two long-lived notifiers in
/// the app — see docs/ARCHITECTURE.md §5.
class AppSettings extends ChangeNotifier {
  AppSettings(this._storage)
    : _skin = SkinRegistry.byId(_storage.skinId),
      _showSymbols = _storage.showSymbols,
      _reducedMotion = _storage.reducedMotion,
      _performanceMode = _storage.performanceMode,
      _haptics = _storage.haptics,
      _sound = _storage.sound;

  final StorageService _storage;

  Skin _skin;
  bool _showSymbols;
  bool _reducedMotion;
  bool _performanceMode;
  bool _haptics;
  bool _sound;

  Skin get skin => _skin;
  bool get showSymbols => _showSymbols;
  bool get reducedMotion => _reducedMotion;

  /// Drops the expensive blurs and background decoration — the setting to
  /// reach for on an older phone.
  bool get performanceMode => _performanceMode;
  bool get haptics => _haptics;
  bool get sound => _sound;
  Motion get motion => Motion(reduced: _reducedMotion);

  void selectSkin(Skin skin) {
    if (skin.id == _skin.id) return;
    _skin = skin;
    unawaited(_storage.setSkinId(skin.id));
    notifyListeners();
  }

  void setShowSymbols({required bool value}) {
    _showSymbols = value;
    unawaited(_storage.setShowSymbols(value: value));
    notifyListeners();
  }

  void setReducedMotion({required bool value}) {
    _reducedMotion = value;
    unawaited(_storage.setReducedMotion(value: value));
    notifyListeners();
  }

  void setPerformanceMode({required bool value}) {
    _performanceMode = value;
    unawaited(_storage.setPerformanceMode(value: value));
    notifyListeners();
  }

  void setHaptics({required bool value}) {
    _haptics = value;
    unawaited(_storage.setHaptics(value: value));
    notifyListeners();
  }

  void setSound({required bool value}) {
    _sound = value;
    unawaited(_storage.setSound(value: value));
    notifyListeners();
  }

  int bestFor(String modeId) => _storage.bestFor(modeId);

  RunSnapshot? savedRun(String modeId) => _storage.savedRun(modeId);

  Future<void> saveRun(RunSnapshot snapshot) async {
    await _storage.saveRun(snapshot);
    notifyListeners();
  }

  Future<void> clearRun(String modeId) async {
    await _storage.clearRun(modeId);
    notifyListeners();
  }

  int starsFor(String packId, int levelNumber) =>
      _storage.starsFor(packId, levelNumber);

  Future<void> recordStars(String packId, int levelNumber, int stars) async {
    if (await _storage.recordStars(packId, levelNumber, stars)) {
      notifyListeners();
    }
  }

  Future<bool> recordScore(String modeId, int score) async {
    final isBest = await _storage.recordScore(modeId, score);
    if (isBest) notifyListeners();
    return isBest;
  }

  static AppSettings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope is missing above this widget');
    return scope!.notifier!;
  }
}

/// Makes [AppSettings] available to the tree and rebuilds on change.
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    required AppSettings super.notifier,
    required super.child,
    super.key,
  });
}
