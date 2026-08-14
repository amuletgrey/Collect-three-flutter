import '../models/board.dart';
import '../models/position.dart';
import '../models/tile.dart';
import '../models/tile_motion.dart';
import '../random/seeded_random.dart';

class RefillOutcome {
  const RefillOutcome(this.board, this.spawned);

  final Board board;
  final List<SpawnedTile> spawned;

  bool get spawnedAnything => spawned.isNotEmpty;
}

/// Where new tiles come from after a clear.
abstract class RefillRule {
  const RefillRule();

  RefillOutcome apply({
    required Board board,
    required SeededRandom rng,
    required TileFactory tiles,
    required int kindCount,
  });

  /// Clear the Board: what you see is all you get.
  static const RefillRule none = _NoRefill();

  /// Infinite Hunt: random tiles drop in from above the top edge.
  static const RefillRule fromTop = _TopRefill();
}

class _NoRefill extends RefillRule {
  const _NoRefill();

  @override
  RefillOutcome apply({
    required Board board,
    required SeededRandom rng,
    required TileFactory tiles,
    required int kindCount,
  }) => RefillOutcome(board, const []);
}

class _TopRefill extends RefillRule {
  const _TopRefill();

  @override
  RefillOutcome apply({
    required Board board,
    required SeededRandom rng,
    required TileFactory tiles,
    required int kindCount,
  }) {
    final cells = board.toCells();
    final spawned = <SpawnedTile>[];
    for (var col = 0; col < board.cols; col++) {
      // Gravity has already run, so every gap in this column sits at the top.
      var gaps = 0;
      for (var row = 0; row < board.rows; row++) {
        if (cells[row * board.cols + col] == null) gaps++;
      }
      for (var row = 0; row < gaps; row++) {
        final tile = tiles.create(rng.nextInt(kindCount));
        cells[row * board.cols + col] = tile;
        // Stagger the entry point above the board so tiles queue up naturally
        // instead of all appearing on the same off-screen row.
        spawned.add(SpawnedTile(tile, Pos(row, col), Pos(row - gaps, col)));
      }
    }
    return RefillOutcome(
      Board.fromCells(board.rows, board.cols, cells),
      spawned,
    );
  }
}
