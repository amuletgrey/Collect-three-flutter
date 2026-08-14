import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../engine/engine.dart';

/// Loads the shipped Clear the Board levels.
///
/// The pack is generated offline by `tool/generate_levels.dart`; every level in
/// it was solved by [ClearBoardSolver] before being written, so the runtime can
/// trust it blindly.
class LevelRepository {
  LevelRepository({this.assetPath = defaultAssetPath});

  static const String defaultAssetPath = 'assets/levels/pack_01.json';

  final String assetPath;

  LevelPack? _cached;

  Future<LevelPack> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(assetPath);
    final pack = LevelPack.fromJson(jsonDecode(raw) as Map<String, Object?>);
    return _cached = pack;
  }
}
