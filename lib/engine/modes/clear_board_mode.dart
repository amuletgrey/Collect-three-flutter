import '../generation/board_generator.dart';
import '../generation/level.dart';
import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';
import '../resolution/board_event.dart';
import 'game_mode.dart';

/// The thinking mode: no refills, and tiles settle down *and then left*, so
/// clearing a match reshapes the whole board to the right of it. The player
/// wins by removing every last tile.
///
/// Layouts are not generated at runtime — random ones are almost never
/// solvable. Levels come from `tool/generate_levels.dart`, which only emits
/// layouts it actually solved. [layoutSketch] is how one is handed over; the
/// balanced fallback exists for tests and free play.
class ClearBoardMode extends GameMode {
  const ClearBoardMode({
    this.grid = const GridConfig(rows: 7, cols: 6, kindCount: 4),
    this.layoutSketch,
    this.moveLimit,
    this.undoBudget = 3,
  });

  /// Builds the mode for a shipped level. The grid comes from the level's own
  /// layout, so a pack can mix board sizes freely.
  factory ClearBoardMode.fromLevel(Level level) => ClearBoardMode(
    grid: GridConfig(
      rows: level.rows,
      cols: level.cols,
      kindCount: level.kindCount,
    ),
    layoutSketch: level.sketch,
  );

  /// Text layout in [Board.parse] form, straight from a level file.
  final String? layoutSketch;

  @override
  final GridConfig grid;

  @override
  final int? moveLimit;

  @override
  final int undoBudget;

  @override
  String get id => 'clear_board';

  @override
  String get name => 'Clear the Board';

  @override
  String get tagline => 'Every tile must go. There are no more coming.';

  @override
  GravityRule get gravity => GravityRule.downThenLeft;

  @override
  RefillRule get refill => RefillRule.none;

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) {
    final sketch = layoutSketch;
    if (sketch != null) return Board.parse(sketch, tiles: tiles);
    return BoardGenerator.generateBalanced(grid: grid, rng: rng, tiles: tiles);
  }

  @override
  ModeEvaluation evaluate(ModeContext ctx) {
    if (ctx.board.isEmpty) {
      return const ModeEvaluation.won(GameEndReason.boardCleared);
    }
    final limit = moveLimit;
    if (limit != null && ctx.movesMade >= limit) {
      return const ModeEvaluation.lost(GameEndReason.outOfMoves);
    }
    if (!MoveFinder.hasLegalMove(ctx.board)) {
      return const ModeEvaluation.lost(GameEndReason.noMovesLeft);
    }
    return const ModeEvaluation.playing();
  }

  @override
  GameMode fresh() => this;
}
