import '../matching/match_finder.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';

/// Builds starting boards that satisfy the invariants in docs/CONCEPT.md §2:
/// no free matches, and at least one legal move.
class BoardGenerator {
  const BoardGenerator._();

  /// Give up rather than spin forever if a configuration is impossible — for
  /// example three kinds on a wide board where every layout is degenerate.
  static const int _maxRepairs = 2000;

  /// A board filled with random kinds.
  ///
  /// [filledRows] fills only that many rows at the bottom, leaving the rest
  /// empty — Rising Tide starts this way.
  static Board generate({
    required GridConfig grid,
    required SeededRandom rng,
    required TileFactory tiles,
    int? filledRows,
  }) {
    final firstRow = filledRows == null ? 0 : grid.rows - filledRows;
    var board = Board.empty(grid.rows, grid.cols);
    final cells = board.toCells();

    for (var row = firstRow.clamp(0, grid.rows); row < grid.rows; row++) {
      for (var col = 0; col < grid.cols; col++) {
        // Placing left-to-right, top-to-bottom means only the two cells to the
        // left and the two above can already form a run, so a free match is
        // avoided by simply not picking those kinds.
        final banned = <int>{
          ..._kindCompletingRun(cells, grid, row, col, 0, -1),
          ..._kindCompletingRun(cells, grid, row, col, -1, 0),
        };
        final candidates = [
          for (var k = 0; k < grid.kindCount; k++)
            if (!banned.contains(k)) k,
        ];
        final kind = candidates.isEmpty
            ? rng.nextInt(grid.kindCount)
            : rng.pick(candidates);
        cells[row * grid.cols + col] = tiles.create(kind);
      }
    }

    board = Board.fromCells(grid.rows, grid.cols, cells);
    return _ensurePlayable(board, grid, rng, tiles);
  }

  /// A layout for Clear the Board: every kind appears a multiple of three
  /// times, so a complete clear is arithmetically possible.
  ///
  /// This does not prove the layout is *solvable* — that is the job of the
  /// offline solver in `tool/generate_levels.dart`.
  static Board generateBalanced({
    required GridConfig grid,
    required SeededRandom rng,
    required TileFactory tiles,
    int? tileCount,
  }) {
    final total = (tileCount ?? grid.cellCount) ~/ 3 * 3;
    if (total < 3) throw ArgumentError('need at least 3 tiles');

    final triples = total ~/ 3;
    final perKind = List<int>.filled(grid.kindCount, 0);
    for (var i = 0; i < triples; i++) {
      perKind[i % grid.kindCount] += 3;
    }
    final kinds = <int>[
      for (var k = 0; k < grid.kindCount; k++)
        for (var i = 0; i < perKind[k]; i++) k,
    ];
    rng.shuffle(kinds);

    // Fill columns from the bottom so the layout is already settled under
    // gravity and the player never sees a tile hanging in mid-air.
    final cells = List<Tile?>.filled(grid.cellCount, null);
    var next = 0;
    for (var col = 0; col < grid.cols && next < kinds.length; col++) {
      final columnHeight = ((kinds.length - next) / (grid.cols - col))
          .ceil()
          .clamp(0, grid.rows);
      for (var i = 0; i < columnHeight && next < kinds.length; i++) {
        final row = grid.rows - 1 - i;
        cells[row * grid.cols + col] = tiles.create(kinds[next++]);
      }
    }

    final board = Board.fromCells(grid.rows, grid.cols, cells);
    return _repairBySwapping(board, rng);
  }

  /// Kinds that would complete a run of three when placed at (row, col),
  /// looking in the direction (dRow, dCol).
  static Set<int> _kindCompletingRun(
    List<Tile?> cells,
    GridConfig grid,
    int row,
    int col,
    int dRow,
    int dCol,
  ) {
    int? kindAt(int r, int c) {
      if (r < 0 || r >= grid.rows || c < 0 || c >= grid.cols) return null;
      return cells[r * grid.cols + c]?.kind;
    }

    final first = kindAt(row + dRow, col + dCol);
    final second = kindAt(row + dRow * 2, col + dCol * 2);
    if (first != null && first == second) return {first};
    return const {};
  }

  /// Re-rolls single cells until the board has something to play.
  static Board _ensurePlayable(
    Board board,
    GridConfig grid,
    SeededRandom rng,
    TileFactory tiles,
  ) {
    var current = board;
    var attempts = 0;
    while (!MoveFinder.hasLegalMove(current)) {
      if (attempts++ > _maxRepairs) {
        throw StateError('could not generate a playable board for $grid');
      }
      final occupied = [
        for (final p in current.positions)
          if (!current.isEmptyAt(p)) p,
      ];
      if (occupied.isEmpty) return current;
      final target = rng.pick(occupied);
      final tile = current.at(target)!;
      final candidate = current.withTile(
        target,
        tile.withKind(rng.nextInt(grid.kindCount)),
      );
      if (!MatchFinder.hasMatchThrough(candidate, target)) current = candidate;
    }
    return current;
  }

  /// Fixes a layout by swapping cells, which preserves the kind counts — vital
  /// for Clear the Board, where the counts are what make a full clear possible.
  static Board _repairBySwapping(Board board, SeededRandom rng) {
    var current = board;
    var attempts = 0;
    while (true) {
      final matches = MatchFinder.find(current);
      final playable = MoveFinder.hasLegalMove(current);
      if (matches.isEmpty && playable) return current;
      if (attempts++ > _maxRepairs) {
        throw StateError('could not repair a balanced layout');
      }

      final occupied = [
        for (final p in current.positions)
          if (!current.isEmptyAt(p)) p,
      ];
      if (occupied.length < 3) return current;

      final source = matches.isEmpty
          ? rng.pick(occupied)
          : rng.pick(matches.cells.toList());
      final partner = rng.pick(occupied);
      if (current.kindAt(source) == current.kindAt(partner)) continue;
      current = current.withSwap(source, partner);
    }
  }
}
