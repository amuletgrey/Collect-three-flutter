/// The rules of Collect Three.
///
/// Pure Dart: nothing in this library imports Flutter, touches the clock, or
/// draws anything. See AGENTS.md — `test/engine/purity_test.dart` enforces it.
library;

export 'game_engine.dart';
export 'generation/board_generator.dart';
export 'generation/clear_board_solver.dart';
export 'generation/level.dart';
export 'gravity/gravity_rule.dart';
export 'gravity/refill_rule.dart';
export 'matching/match_finder.dart';
export 'matching/match_line.dart';
export 'matching/move_finder.dart';
export 'models/board.dart';
export 'models/grid_config.dart';
export 'models/move.dart';
export 'models/position.dart';
export 'models/tile.dart';
export 'models/tile_motion.dart';
export 'modes/clear_board_mode.dart';
export 'modes/game_mode.dart';
export 'modes/infinite_hunt_mode.dart';
export 'modes/mode_registry.dart';
export 'modes/rising_tide_mode.dart';
export 'random/seeded_random.dart';
export 'resolution/board_event.dart';
export 'resolution/move_result.dart';
export 'resolution/resolver.dart';
export 'scoring/score_rules.dart';
