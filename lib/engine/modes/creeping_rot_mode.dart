import '../generation/board_generator.dart';
import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/position.dart';
import '../models/tile.dart';
import '../models/tile_motion.dart';
import '../random/seeded_random.dart';
import '../resolution/board_event.dart';
import 'game_mode.dart';

/// Rot spreads across the board; clearing beside it burns it back.
///
/// Every few moves one tile turns to rot. Rot falls with gravity like cargo,
/// but it never matches, cannot be swapped, and no blast touches it — so it
/// silts up at the bottom and the playable board shrinks from underneath. The
/// only way to be rid of it is to clear tiles *next to* it.
///
/// This is Infinite Hunt with the stalling fixed. A careful player can keep an
/// endless board alive forever by matching in a safe corner; here that corner
/// rots. It answers the question the endless mode never asks — not "can you
/// keep finding moves" but "can you keep finding moves *where they are needed*".
class CreepingRotMode extends GameMode {
  CreepingRotMode({
    this.grid = const GridConfig(rows: 8, cols: 8, kindCount: 6),
    this.baseInterval = 3,
    this.minInterval = 2,
    this.spreadsPerSpeedUp = 12,

    /// Fraction of the board that ends the run.
    this.rotLimit = 0.4,
  });

  @override
  final GridConfig grid;

  /// Moves between spreads at the start of a run.
  final int baseInterval;
  final int minInterval;

  /// The interval tightens by one every this many spreads.
  final int spreadsPerSpeedUp;

  final double rotLimit;

  int _movesSinceSpread = 0;
  int _spreads = 0;
  int _burned = 0;

  int get spreads => _spreads;

  /// Rot burned off over the run — the stat that says how hard you fought.
  int get burned => _burned;

  /// Awarded per rot tile burned. Well above a plain tile: cleaning up is the
  /// point, and a player who ignores the rot should lose to one who does not.
  static const int burnBonus = 60;

  /// How many rot tiles end the run.
  int get rotCapacity => (grid.rows * grid.cols * rotLimit).floor();

  int rotOn(Board board) {
    var count = 0;
    for (final pos in board.positions) {
      if (board.at(pos)?.isRot ?? false) count++;
    }
    return count;
  }

  int get currentInterval => intervalForSpreads(_spreads);

  /// Pure form of the curve, so it can be reasoned about — and tested —
  /// without driving a whole run.
  int intervalForSpreads(int spreads) =>
      (baseInterval - spreads ~/ spreadsPerSpeedUp).clamp(minInterval, 99);

  /// Moves left before the next tile turns. The HUD counts this down.
  int get movesUntilSpread =>
      (currentInterval - _movesSinceSpread).clamp(0, 99);

  @override
  String get id => 'creeping_rot';

  @override
  String get name => 'Creeping Rot';

  @override
  String get tagline => 'Match beside it, or lose the board to it.';

  @override
  GravityRule get gravity => GravityRule.down;

  @override
  RefillRule get refill => RefillRule.fromTop;

  @override
  bool get allowsSpecials => true;

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) =>
      BoardGenerator.generate(grid: grid, rng: rng, tiles: tiles);

  @override
  ModeStepOutcome afterMove(ModeContext ctx) {
    var board = ctx.board;
    final events = <BoardEvent>[];
    var scoreDelta = 0;

    // Burning comes first: the rot you just cleared beside should not also get
    // a free spread out of the same move.
    final burn = _burnAdjacentTo(board, ctx.move?.clearedCells ?? const {});
    if (burn.isNotEmpty) {
      _burned += burn.length;
      scoreDelta += burn.length * burnBonus;
      events.add(
        TilesCleared(
          cells: burn,
          lines: const [],
          scoreDelta: burn.length * burnBonus,
          cascadeStep: 1,
          multiplier: 1,
          cause: ClearCause.burned,
        ),
      );
      final settled = ctx.resolver.resolve(
        board: board.withCleared(burn),
        rng: ctx.rng,
        tiles: ctx.tiles,
        settleFirst: true,
      );
      board = settled.board;
      events.addAll(settled.events);
      scoreDelta += settled.score;
    }

    _movesSinceSpread++;
    if (_movesSinceSpread >= currentInterval) {
      final spread = _spread(board, ctx.rng);
      if (spread != null) {
        _movesSinceSpread = 0;
        _spreads++;
        board = board.withTile(spread.at, spread.tile);
        events.add(TilesTransformed([spread]));
      }
    }

    return ModeStepOutcome(
      board: board,
      events: events,
      scoreDelta: scoreDelta,
    );
  }

  /// Rot orthogonally touching a cell that was cleared this move.
  ///
  /// [cleared] holds cells from every step of the cascade, so this is generous
  /// by a tile or two where the board shifted mid-move. Generous in the
  /// player's favour is the right way to be wrong about it.
  List<Pos> _burnAdjacentTo(Board board, Set<Pos> cleared) {
    if (cleared.isEmpty) return const [];
    return [
      for (final pos in board.positions)
        if ((board.at(pos)?.isRot ?? false) &&
            pos.neighbours.any(cleared.contains))
          pos,
    ];
  }

  /// Turns one tile. Rot grows from rot where it can, so it reads as spreading
  /// rather than as tiles randomly dying; the first one starts low, where it
  /// has room to become a problem.
  UpgradedTile? _spread(Board board, SeededRandom rng) {
    final rotted = [
      for (final pos in board.positions)
        if (board.at(pos)?.isRot ?? false) pos,
    ];

    final candidates = <Pos>[];
    if (rotted.isEmpty) {
      for (final pos in board.positions) {
        if (pos.row < board.rows ~/ 2) continue;
        final tile = board.at(pos);
        if (tile != null && !tile.isInert) candidates.add(pos);
      }
    } else {
      final seen = <Pos>{};
      for (final pos in rotted) {
        for (final next in pos.neighbours) {
          if (!board.contains(next) || !seen.add(next)) continue;
          final tile = board.at(next);
          if (tile != null && !tile.isInert) candidates.add(next);
        }
      }
    }

    if (candidates.isEmpty) return null;
    final at = rng.pick(candidates);
    return UpgradedTile(board.at(at)!.asRot(), at);
  }

  @override
  ModeEvaluation evaluate(ModeContext ctx) {
    if (rotOn(ctx.board) >= rotCapacity) {
      return const ModeEvaluation.lost(GameEndReason.overrun);
    }
    return MoveFinder.hasLegalMove(ctx.board, specials: allowsSpecials)
        ? const ModeEvaluation.playing()
        : const ModeEvaluation.lost(GameEndReason.noMovesLeft);
  }

  @override
  Map<String, Object?> saveState() => {
    'movesSinceSpread': _movesSinceSpread,
    'spreads': _spreads,
    'burned': _burned,
  };

  @override
  void restoreState(Map<String, Object?> state) {
    _movesSinceSpread = state['movesSinceSpread'] as int? ?? 0;
    _spreads = state['spreads'] as int? ?? 0;
    _burned = state['burned'] as int? ?? 0;
  }

  @override
  GameMode fresh() => CreepingRotMode(
    grid: grid,
    baseInterval: baseInterval,
    minInterval: minInterval,
    spreadsPerSpeedUp: spreadsPerSpeedUp,
    rotLimit: rotLimit,
  );
}
