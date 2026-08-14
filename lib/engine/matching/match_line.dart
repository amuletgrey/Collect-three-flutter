import '../models/position.dart';

enum MatchOrientation { horizontal, vertical }

/// One contiguous run of 3+ identical kinds.
class MatchLine {
  MatchLine({
    required this.kind,
    required this.orientation,
    required this.cells,
  }) : assert(cells.length >= 3, 'a line shorter than 3 is not a match');

  final int kind;
  final MatchOrientation orientation;
  final List<Pos> cells;

  int get length => cells.length;

  @override
  String toString() =>
      'MatchLine(k$kind, ${orientation.name}, ${cells.first}..${cells.last})';
}

/// Everything matched in a single resolution step.
///
/// Intersecting lines (L and T shapes) stay separate in [lines] — each scores on
/// its own — while [cells] is their union, which is what actually gets cleared.
class MatchResult {
  MatchResult(this.lines) : cells = {for (final line in lines) ...line.cells};

  static final MatchResult none = MatchResult(const []);

  final List<MatchLine> lines;
  final Set<Pos> cells;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  /// Longest line in this result, or 0 — used for "best match" stats.
  int get longestLine =>
      lines.fold(0, (best, line) => line.length > best ? line.length : best);

  @override
  String toString() =>
      'MatchResult(${lines.length} lines, ${cells.length} tiles)';
}
