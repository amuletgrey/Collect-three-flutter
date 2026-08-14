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

/// Survival. Every few moves a fresh row is inserted at the bottom and the
/// whole stack is shoved up one row; the run ends when a tile is pushed past
/// the top. Gravity still points down — the stack grows upwards because it is
/// being fed from underneath.
///
/// Running out of legal moves does not end the run: the tide rises immediately
/// instead, because new tiles mean new options. This mode can only be lost by
/// drowning.
class RisingTideMode extends GameMode {
  RisingTideMode({
    this.grid = const GridConfig(rows: 10, cols: 8, kindCount: 6),
    this.initialRows = 5,
    this.baseInterval = 5,
    this.minInterval = 2,
    this.rowsPerSpeedUp = 8,
  });

  @override
  final GridConfig grid;

  /// How many rows are already stacked when the run starts.
  final int initialRows;

  /// Moves between rises at the start of a run.
  final int baseInterval;

  /// The interval never drops below this, or the game stops being playable.
  final int minInterval;

  /// The interval tightens by one move every this many risen rows.
  final int rowsPerSpeedUp;

  int _movesSinceRise = 0;
  int _rowsRisen = 0;
  bool _overflowed = false;

  int get rowsRisen => _rowsRisen;
  bool get overflowed => _overflowed;

  /// Moves left before the next rise — the HUD's tide meter reads this.
  int get movesUntilRise => (currentInterval - _movesSinceRise).clamp(0, 99);

  int get currentInterval => intervalForRows(_rowsRisen);

  /// Pure form of the difficulty curve, so it can be reasoned about (and
  /// tested) without driving a whole run.
  int intervalForRows(int rowsRisen) =>
      (baseInterval - rowsRisen ~/ rowsPerSpeedUp).clamp(minInterval, 99);

  @override
  String get id => 'rising_tide';

  @override
  String get name => 'Rising Tide';

  @override
  String get tagline => 'The floor keeps handing you more work.';

  @override
  GravityRule get gravity => GravityRule.down;

  @override
  RefillRule get refill => RefillRule.none;

  @override
  bool get allowsSpecials => true;

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) =>
      BoardGenerator.generate(
        grid: grid,
        rng: rng,
        tiles: tiles,
        filledRows: initialRows,
      );

  @override
  ModeStepOutcome afterMove(ModeContext ctx) {
    _movesSinceRise++;

    var board = ctx.board;
    final events = <BoardEvent>[];
    var scoreDelta = 0;

    // One rise does not always hand the player a move — a single fresh row can
    // be just as stuck as the board it landed under. Keep feeding the board
    // until it is playable again or it drowns, so the run can never dead-end.
    for (var guard = 0; guard <= grid.rows; guard++) {
      final due = _movesSinceRise >= currentInterval;
      final stalled = !MoveFinder.hasLegalMove(board, specials: allowsSpecials);
      if (!due && !stalled) break;

      final risen = _rise(ctx.withBoard(board));
      board = risen.board;
      events.addAll(risen.events);
      scoreDelta += risen.scoreDelta;
      if (_overflowed) break;
    }

    return ModeStepOutcome(
      board: board,
      events: events,
      scoreDelta: scoreDelta,
    );
  }

  @override
  ModeEvaluation evaluate(ModeContext ctx) => _overflowed
      ? const ModeEvaluation.lost(GameEndReason.overflow)
      : const ModeEvaluation.playing();

  @override
  GameMode fresh() => RisingTideMode(
    grid: grid,
    initialRows: initialRows,
    baseInterval: baseInterval,
    minInterval: minInterval,
    rowsPerSpeedUp: rowsPerSpeedUp,
  );

  ModeStepOutcome _rise(ModeContext ctx) {
    final board = ctx.board;

    // Anything still sitting in the top row has nowhere to go.
    for (var col = 0; col < board.cols; col++) {
      if (board.atRc(0, col) != null) {
        _overflowed = true;
        return ModeStepOutcome(board: board);
      }
    }

    _movesSinceRise = 0;
    _rowsRisen++;

    final cells = board.toCells();
    final pushed = <TileMove>[];
    for (var row = 1; row < board.rows; row++) {
      for (var col = 0; col < board.cols; col++) {
        final tile = cells[row * board.cols + col];
        if (tile == null) continue;
        cells[(row - 1) * board.cols + col] = tile;
        cells[row * board.cols + col] = null;
        pushed.add(TileMove(tile.id, Pos(row, col), Pos(row - 1, col)));
      }
    }

    final bottom = board.rows - 1;
    final spawned = <SpawnedTile>[];
    for (var col = 0; col < board.cols; col++) {
      final kind = _kindWithoutMatch(cells, board.cols, bottom, col, ctx.rng);
      final tile = ctx.tiles.create(kind);
      cells[bottom * board.cols + col] = tile;
      spawned.add(SpawnedTile(tile, Pos(bottom, col), Pos(bottom + 1, col)));
    }

    final risen = Board.fromCells(board.rows, board.cols, cells);

    // The new row is built match-free on purpose: the tide hands the player
    // material, it never scores for them. Resolving anyway keeps the pipeline
    // honest if that ever changes.
    final settled = ctx.resolver.resolve(
      board: risen,
      rng: ctx.rng,
      tiles: ctx.tiles,
    );

    return ModeStepOutcome(
      board: settled.board,
      events: [
        RowInserted(pushed: pushed, spawned: spawned),
        ...settled.events,
      ],
      scoreDelta: settled.score,
    );
  }

  /// Picks a kind for the new bottom row that forms no immediate line, looking
  /// left along the row and up the column.
  int _kindWithoutMatch(
    List<Tile?> cells,
    int cols,
    int row,
    int col,
    SeededRandom rng,
  ) {
    int? kindAt(int r, int c) {
      if (r < 0 || c < 0 || c >= cols) return null;
      final index = r * cols + c;
      if (index >= cells.length) return null;
      return cells[index]?.kind;
    }

    final banned = <int>{};
    if (kindAt(row, col - 1) != null &&
        kindAt(row, col - 1) == kindAt(row, col - 2)) {
      banned.add(kindAt(row, col - 1)!);
    }
    if (kindAt(row - 1, col) != null &&
        kindAt(row - 1, col) == kindAt(row - 2, col)) {
      banned.add(kindAt(row - 1, col)!);
    }

    final candidates = [
      for (var k = 0; k < grid.kindCount; k++)
        if (!banned.contains(k)) k,
    ];
    return candidates.isEmpty
        ? rng.nextInt(grid.kindCount)
        : rng.pick(candidates);
  }
}
