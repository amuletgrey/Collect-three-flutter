import '../generation/board_generator.dart';
import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';
import '../resolution/board_event.dart';
import 'game_mode.dart';

/// Endless score attack. Tiles refill from the top forever; the run ends the
/// moment the board has no legal move left. There is no shuffle rescue — the
/// dead board is the ending, so keeping the board alive is the real skill.
class InfiniteHuntMode extends GameMode {
  const InfiniteHuntMode({
    this.grid = const GridConfig(rows: 8, cols: 8, kindCount: 6),
  });

  @override
  final GridConfig grid;

  @override
  String get id => 'infinite_hunt';

  @override
  String get name => 'Infinite Hunt';

  @override
  String get tagline => 'The board never runs dry. You do.';

  @override
  GravityRule get gravity => GravityRule.down;

  @override
  RefillRule get refill => RefillRule.fromTop;

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) =>
      BoardGenerator.generate(grid: grid, rng: rng, tiles: tiles);

  @override
  ModeEvaluation evaluate(ModeContext ctx) => MoveFinder.hasLegalMove(ctx.board)
      ? const ModeEvaluation.playing()
      : const ModeEvaluation.lost(GameEndReason.noMovesLeft);

  @override
  GameMode fresh() => this;
}
