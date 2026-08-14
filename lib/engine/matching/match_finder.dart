import '../models/board.dart';
import '../models/position.dart';
import 'match_line.dart';

/// Finds every line of 3+ identical kinds on a board.
///
/// Empty cells never match. Horizontal and vertical runs are found
/// independently, so an L or T shape yields two lines that share a cell — the
/// resolver clears their union and scores them separately.
class MatchFinder {
  const MatchFinder._();

  static MatchResult find(Board board) {
    final lines = <MatchLine>[];
    _scan(
      board: board,
      outer: board.rows,
      inner: board.cols,
      orientation: MatchOrientation.horizontal,
      lines: lines,
    );
    _scan(
      board: board,
      outer: board.cols,
      inner: board.rows,
      orientation: MatchOrientation.vertical,
      lines: lines,
    );
    return MatchResult(lines);
  }

  static bool hasAnyMatch(Board board) => find(board).isNotEmpty;

  /// Whether a run of 3+ passes through [p].
  ///
  /// A swap can only create matches involving one of the two moved tiles, so
  /// move validation checks these two cells instead of rescanning the board.
  static bool hasMatchThrough(Board board, Pos p) {
    final kind = board.kindAt(p);
    if (kind == null) return false;
    final horizontal =
        1 +
        _runLength(board, p, kind, 0, -1) +
        _runLength(board, p, kind, 0, 1);
    if (horizontal >= 3) return true;
    final vertical =
        1 +
        _runLength(board, p, kind, -1, 0) +
        _runLength(board, p, kind, 1, 0);
    return vertical >= 3;
  }

  static void _scan({
    required Board board,
    required int outer,
    required int inner,
    required MatchOrientation orientation,
    required List<MatchLine> lines,
  }) {
    final horizontal = orientation == MatchOrientation.horizontal;
    for (var o = 0; o < outer; o++) {
      var runStart = 0;
      int? runKind;
      for (var i = 0; i <= inner; i++) {
        // The extra iteration past the end flushes a run that reaches the edge.
        final kind = i == inner
            ? null
            : board.kindAt(horizontal ? Pos(o, i) : Pos(i, o));
        if (kind != runKind) {
          if (runKind != null && i - runStart >= 3) {
            lines.add(
              MatchLine(
                kind: runKind,
                orientation: orientation,
                cells: [
                  for (var k = runStart; k < i; k++)
                    horizontal ? Pos(o, k) : Pos(k, o),
                ],
              ),
            );
          }
          runStart = i;
          runKind = kind;
        }
      }
    }
  }

  static int _runLength(Board board, Pos from, int kind, int dRow, int dCol) {
    var count = 0;
    var p = from.translate(dRow, dCol);
    while (board.kindAt(p) == kind) {
      count++;
      p = p.translate(dRow, dCol);
    }
    return count;
  }
}
