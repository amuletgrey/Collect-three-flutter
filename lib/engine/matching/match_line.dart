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

/// Lines that touch each other, treated as one shape.
///
/// An L or a T is two lines sharing a corner; the player made one move and
/// should be rewarded once for it, so powers are granted per group rather than
/// per line. Scoring still counts each line separately.
class MatchGroup {
  MatchGroup(this.lines) : cells = {for (final line in lines) ...line.cells};

  final List<MatchLine> lines;
  final Set<Pos> cells;

  int get kind => lines.first.kind;

  /// True for L and T shapes — two lines crossing.
  bool get isIntersection => lines.length > 1;

  int get longestLine =>
      lines.fold(0, (best, line) => line.length > best ? line.length : best);

  /// Where two lines cross, if they do.
  Pos? get intersection {
    if (!isIntersection) return null;
    for (final candidate in lines.first.cells) {
      for (final other in lines.skip(1)) {
        if (other.cells.contains(candidate)) return candidate;
      }
    }
    return null;
  }

  @override
  String toString() =>
      'MatchGroup(${lines.length} lines, ${cells.length} tiles)';
}

/// Everything matched in a single resolution step.
///
/// Intersecting lines (L and T shapes) stay separate in [lines] — each scores
/// on its own — while [cells] is their union, which is what actually gets
/// cleared. [groups] joins touching lines back together for power creation.
class MatchResult {
  MatchResult(this.lines)
    : cells = {for (final line in lines) ...line.cells},
      groups = _group(lines);

  static final MatchResult none = MatchResult(const []);

  final List<MatchLine> lines;
  final Set<Pos> cells;
  final List<MatchGroup> groups;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  /// Longest line in this result, or 0 — used for "best match" stats.
  int get longestLine =>
      lines.fold(0, (best, line) => line.length > best ? line.length : best);

  /// Joins lines that share at least one cell into connected shapes.
  static List<MatchGroup> _group(List<MatchLine> lines) {
    final remaining = List<MatchLine>.of(lines);
    final groups = <MatchGroup>[];

    while (remaining.isNotEmpty) {
      final members = [remaining.removeAt(0)];
      final cells = {...members.first.cells};

      var grew = true;
      while (grew) {
        grew = false;
        for (var i = remaining.length - 1; i >= 0; i--) {
          if (remaining[i].cells.any(cells.contains)) {
            members.add(remaining[i]);
            cells.addAll(remaining[i].cells);
            remaining.removeAt(i);
            grew = true;
          }
        }
      }
      groups.add(MatchGroup(members));
    }
    return groups;
  }

  @override
  String toString() =>
      'MatchResult(${lines.length} lines, ${cells.length} tiles)';
}
