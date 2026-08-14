import '../models/board.dart';
import '../models/position.dart';
import '../models/tile.dart';
import '../models/tile_motion.dart';

/// Result of settling a board.
///
/// [steps] is a list of animation batches, not a flat move list: `downThenLeft`
/// produces a fall and then a slide, and they must be shown one after the other
/// or the motion reads as a diagonal teleport.
class GravityOutcome {
  const GravityOutcome(this.board, this.steps);

  final Board board;
  final List<List<TileMove>> steps;

  bool get movedAnything => steps.any((s) => s.isNotEmpty);
}

/// How tiles settle after a clear.
abstract class GravityRule {
  const GravityRule();

  GravityOutcome apply(Board board);

  /// Infinite Hunt and Rising Tide: tiles fall straight down.
  static const GravityRule down = _DownGravity();

  /// Clear the Board: tiles fall, then whole columns that went empty are
  /// removed and everything to their right slides left.
  static const GravityRule downThenLeft = _DownThenLeftGravity();
}

class _DownGravity extends GravityRule {
  const _DownGravity();

  @override
  GravityOutcome apply(Board board) {
    final cells = board.toCells();
    final moves = <TileMove>[];
    for (var col = 0; col < board.cols; col++) {
      var write = board.rows - 1;
      for (var row = board.rows - 1; row >= 0; row--) {
        final tile = cells[row * board.cols + col];
        if (tile == null) continue;
        if (write != row) {
          cells[write * board.cols + col] = tile;
          cells[row * board.cols + col] = null;
          moves.add(TileMove(tile.id, Pos(row, col), Pos(write, col)));
        }
        write--;
      }
    }
    return GravityOutcome(Board.fromCells(board.rows, board.cols, cells), [
      if (moves.isNotEmpty) moves,
    ]);
  }
}

class _DownThenLeftGravity extends GravityRule {
  const _DownThenLeftGravity();

  @override
  GravityOutcome apply(Board board) {
    final fallen = GravityRule.down.apply(board);
    final settled = fallen.board;

    // A column can only be skipped when it is *completely* empty; partially
    // filled columns never slide, which is what makes this mode's geometry
    // predictable enough to plan around.
    final occupied = <int>[
      for (var col = 0; col < settled.cols; col++)
        if (_columnHasTile(settled, col)) col,
    ];
    if (occupied.length == settled.cols) return fallen;

    final cells = List<Tile?>.filled(settled.rows * settled.cols, null);
    final slides = <TileMove>[];
    for (var dest = 0; dest < occupied.length; dest++) {
      final src = occupied[dest];
      for (var row = 0; row < settled.rows; row++) {
        final tile = settled.atRc(row, src);
        cells[row * settled.cols + dest] = tile;
        if (tile != null && src != dest) {
          slides.add(TileMove(tile.id, Pos(row, src), Pos(row, dest)));
        }
      }
    }

    return GravityOutcome(Board.fromCells(settled.rows, settled.cols, cells), [
      ...fallen.steps,
      if (slides.isNotEmpty) slides,
    ]);
  }

  static bool _columnHasTile(Board board, int col) {
    for (var row = 0; row < board.rows; row++) {
      if (board.atRc(row, col) != null) return true;
    }
    return false;
  }
}
