import '../matching/match_line.dart';
import '../models/position.dart';
import '../models/tile_motion.dart';

/// Why a game ended.
enum GameEndReason {
  /// Infinite Hunt / Clear the Board: the board is alive but unplayable.
  noMovesLeft,

  /// Clear the Board: every tile collected.
  boardCleared,

  /// Clear the Board: the move budget ran out.
  outOfMoves,

  /// Rising Tide: the stack was pushed past the top row.
  overflow,
}

/// An ordered, replayable description of everything that happened.
///
/// The engine emits these; the UI plays them back as animation and never
/// re-derives game state from the board itself. Because the list is data, a
/// headless test can assert on exactly what the player would have seen.
///
/// This hierarchy is sealed on purpose: adding a variant makes the compiler
/// point at every consumer that needs updating. Do not add `default:` branches
/// when switching over it.
sealed class BoardEvent {
  const BoardEvent();
}

/// The two tiles trade places. Emitted for illegal swaps too — they are shown
/// and then taken back.
class SwapPerformed extends BoardEvent {
  const SwapPerformed(this.a, this.b);

  final Pos a;
  final Pos b;

  @override
  String toString() => 'SwapPerformed($a, $b)';
}

/// The swap produced nothing, so it snaps back.
class SwapReverted extends BoardEvent {
  const SwapReverted(this.a, this.b);

  final Pos a;
  final Pos b;

  @override
  String toString() => 'SwapReverted($a, $b)';
}

/// One resolution step's worth of collected tiles.
class TilesCleared extends BoardEvent {
  const TilesCleared({
    required this.cells,
    required this.lines,
    required this.scoreDelta,
    required this.cascadeStep,
    required this.multiplier,
  });

  /// Union of every matched line — these are the cells being emptied.
  final List<Pos> cells;
  final List<MatchLine> lines;
  final int scoreDelta;

  /// 1 for the player's own match, 2+ for chain reactions.
  final int cascadeStep;
  final int multiplier;

  @override
  String toString() =>
      'TilesCleared(${cells.length} tiles, +$scoreDelta, x$multiplier)';
}

/// Tiles settling — one batch is one animation.
class TilesMoved extends BoardEvent {
  const TilesMoved(this.moves);

  final List<TileMove> moves;

  @override
  String toString() => 'TilesMoved(${moves.length})';
}

/// New tiles entering the board.
class TilesSpawned extends BoardEvent {
  const TilesSpawned(this.tiles);

  final List<SpawnedTile> tiles;

  @override
  String toString() => 'TilesSpawned(${tiles.length})';
}

/// Rising Tide: a row appears at the bottom and shoves the stack up.
class RowInserted extends BoardEvent {
  const RowInserted({required this.pushed, required this.spawned});

  /// Everything already on the board moving up one row.
  final List<TileMove> pushed;

  /// The new bottom row.
  final List<SpawnedTile> spawned;

  @override
  String toString() => 'RowInserted(+${spawned.length})';
}

/// Terminal event. Always the last entry in a move's event list.
class GameEnded extends BoardEvent {
  const GameEnded(this.reason);

  final GameEndReason reason;

  @override
  String toString() => 'GameEnded(${reason.name})';
}
