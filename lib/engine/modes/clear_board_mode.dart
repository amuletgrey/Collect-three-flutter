import '../generation/board_generator.dart';
import '../generation/clear_board_solver.dart';
import '../generation/level.dart';
import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/hint.dart';
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
    this.hintNodeBudget = 8000,
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

  /// Board states the hint solver may expand before giving up and showing an
  /// ordinary legal move.
  ///
  /// Deliberately far below the generator's 150,000: this one runs on a button
  /// press, on a phone. Measured on the shipped pack, a full board finds a
  /// winning line in under 2,000 nodes, and a wrecked board is *proved* dead in
  /// under 100 — the tree collapses once the tiles are gone. 8,000 leaves room
  /// either way while capping the worst case at a few hundred milliseconds.
  final int hintNodeBudget;

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

  /// Steers the player down a line that actually empties the board.
  ///
  /// Every shipped level was proven solvable before it shipped, but the player
  /// can wreck one in a single careless move: this mode has no refills, so a
  /// clear that strands a lone tile is unrecoverable. A hint that pointed at
  /// any old legal move would happily march them further into a dead level,
  /// which is worse than useless in the one mode where thinking ahead is the
  /// entire game.
  ///
  /// Three outcomes, and the difference between the last two matters: a line
  /// was found, the level was *proved* dead, or the search ran out of budget
  /// and we simply do not know. Only the proved case is reported as a dead end.
  @override
  Hint? hintFor(Board board, SeededRandom rng) {
    final fallback = super.hintFor(board, rng);
    if (fallback == null) return null;

    final outcome = ClearBoardSolver(nodeBudget: hintNodeBudget).solve(board);
    if (outcome.solved && outcome.moves.isNotEmpty) {
      return Hint(outcome.moves.first, kind: HintKind.winningLine);
    }
    if (outcome.budgetExhausted) return fallback;
    return Hint(fallback.move, kind: HintKind.deadEnd);
  }

  @override
  GameMode fresh() => this;
}
