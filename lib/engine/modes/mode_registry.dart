import 'clear_board_mode.dart';
import 'game_mode.dart';
import 'infinite_hunt_mode.dart';
import 'rising_tide_mode.dart';

/// Every playable mode, by id. Adding a mode means adding it here and to
/// docs/CONCEPT.md §3 — nothing else in the engine needs to know.
class ModeRegistry {
  const ModeRegistry._();

  static const String infiniteHuntId = 'infinite_hunt';
  static const String clearBoardId = 'clear_board';
  static const String risingTideId = 'rising_tide';

  static const List<String> ids = [infiniteHuntId, clearBoardId, risingTideId];

  /// Always returns a fresh instance: modes may carry per-run state.
  static GameMode create(String id) => switch (id) {
    infiniteHuntId => const InfiniteHuntMode(),
    clearBoardId => const ClearBoardMode(),
    risingTideId => RisingTideMode(),
    _ => throw ArgumentError('unknown game mode "$id"'),
  };

  static List<GameMode> createAll() => [for (final id in ids) create(id)];
}
