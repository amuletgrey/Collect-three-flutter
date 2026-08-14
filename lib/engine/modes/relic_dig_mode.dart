import '../generation/board_generator.dart';
import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/position.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';
import '../resolution/board_event.dart';
import 'game_mode.dart';

/// Escort the relics down.
///
/// A handful of tiles start buried near the top as **relics**: they fall with
/// gravity like everything else, but they never match, cannot be swapped, and
/// no blast can touch them. The only way to move one is to clear what is
/// underneath it. Get every relic to the bottom row and the dig is finished.
///
/// It plays like Infinite Hunt — refills from the top, ends when the board runs
/// out of moves — but it inverts the goal: matching is no longer the point, it
/// is the shovel. Clearing greedily near the top does nothing; the tiles worth
/// taking are the ones under the cargo.
class RelicDigMode extends GameMode {
  RelicDigMode({
    this.grid = const GridConfig(rows: 8, cols: 8, kindCount: 6),
    this.relicCount = 3,

    /// Relics start somewhere in the top this many rows.
    this.buryDepth = 2,
  });

  @override
  final GridConfig grid;

  final int relicCount;
  final int buryDepth;

  int _delivered = 0;

  int get delivered => _delivered;
  int get remaining => relicCount - _delivered;

  /// Awarded per relic delivered — the whole point of the mode, so it dwarfs a
  /// plain match.
  static const int deliveryBonus = 500;

  @override
  String get id => 'relic_dig';

  @override
  String get name => 'Relic Dig';

  @override
  String get tagline => 'Dig the relics out. Matching is just the shovel.';

  @override
  GravityRule get gravity => GravityRule.down;

  @override
  RefillRule get refill => RefillRule.fromTop;

  @override
  bool get allowsSpecials => true;

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) {
    var board = BoardGenerator.generate(grid: grid, rng: rng, tiles: tiles);

    // Spread the relics across distinct columns, so they cannot stack up in one
    // shaft and come down together for free.
    final columns = [for (var col = 0; col < grid.cols; col++) col];
    rng.shuffle(columns);
    for (var i = 0; i < relicCount && i < columns.length; i++) {
      final row = rng.nextInt(buryDepth);
      final at = Pos(row, columns[i]);
      board = board.withTile(at, board.at(at)!.asRelic());
    }
    return board;
  }

  @override
  ModeStepOutcome afterMove(ModeContext ctx) {
    final landed = [
      for (var col = 0; col < ctx.board.cols; col++)
        if (ctx.board.atRc(ctx.board.rows - 1, col)?.isRelic ?? false)
          Pos(ctx.board.rows - 1, col),
    ];
    if (landed.isEmpty) return ModeStepOutcome(board: ctx.board);

    _delivered += landed.length;
    final bonus = landed.length * deliveryBonus;

    final events = <BoardEvent>[
      TilesCleared(
        cells: landed,
        lines: const [],
        scoreDelta: bonus,
        cascadeStep: 1,
        multiplier: 1,
      ),
    ];

    // Take the cargo off the board, then let everything fall into the gap and
    // resolve whatever that starts.
    final settled = ctx.resolver.resolve(
      board: ctx.board.withCleared(landed),
      rng: ctx.rng,
      tiles: ctx.tiles,
      settleFirst: true,
    );

    return ModeStepOutcome(
      board: settled.board,
      events: [...events, ...settled.events],
      scoreDelta: bonus + settled.score,
    );
  }

  @override
  ModeEvaluation evaluate(ModeContext ctx) {
    if (_delivered >= relicCount) {
      return const ModeEvaluation.won(GameEndReason.relicsDelivered);
    }
    return MoveFinder.hasLegalMove(ctx.board, specials: allowsSpecials)
        ? const ModeEvaluation.playing()
        : const ModeEvaluation.lost(GameEndReason.noMovesLeft);
  }

  @override
  Map<String, Object?> saveState() => {'delivered': _delivered};

  @override
  void restoreState(Map<String, Object?> state) {
    _delivered = state['delivered'] as int? ?? 0;
  }

  @override
  GameMode fresh() =>
      RelicDigMode(grid: grid, relicCount: relicCount, buryDepth: buryDepth);
}
