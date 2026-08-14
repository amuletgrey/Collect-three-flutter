import '../matching/match_line.dart';
import '../models/board.dart';
import '../models/position.dart';
import '../models/tile.dart';

/// A power to be placed on the board after a match is cleared.
class SpecialSpawn {
  const SpecialSpawn({
    required this.at,
    required this.kind,
    required this.power,
  });

  final Pos at;
  final int kind;
  final TilePower power;

  @override
  String toString() => 'SpecialSpawn(${power.name} k$kind at $at)';
}

/// Which matches create powers, and what those powers destroy.
///
/// Kept apart from the resolver so the rules can be read and tested on their
/// own — see docs/CONCEPT.md §2 for the player-facing version.
class SpecialRules {
  const SpecialRules._();

  /// Decides the power a single match group earns, if any.
  ///
  /// [origins] are the two cells the player's swap touched. A power lands on
  /// whichever of them is part of the shape, which is the tile the player was
  /// dragging — and the drag can end on either side, so both are offered.
  static SpecialSpawn? spawnFor(
    MatchGroup group, {
    Set<Pos> origins = const {},
  }) {
    final power = _powerFor(group);
    if (power == TilePower.none) return null;
    return SpecialSpawn(
      at: _placementFor(group, origins: origins),
      kind: group.kind,
      power: power,
    );
  }

  static List<SpecialSpawn> spawnsFor(
    MatchResult matches, {
    Set<Pos> origins = const {},
  }) => [
    for (final group in matches.groups) ?spawnFor(group, origins: origins),
  ];

  /// Stronger powers win when a shape qualifies for more than one.
  static TilePower _powerFor(MatchGroup group) {
    if (group.longestLine >= 5) return TilePower.colourBomb;
    if (group.isIntersection) return TilePower.bomb;
    if (group.longestLine == 4) {
      // The blast runs along the match: four in a row clears that row.
      return group.lines.first.orientation == MatchOrientation.horizontal
          ? TilePower.clearRow
          : TilePower.clearColumn;
    }
    return TilePower.none;
  }

  static Pos _placementFor(MatchGroup group, {Set<Pos> origins = const {}}) {
    for (final origin in origins) {
      if (group.cells.contains(origin)) return origin;
    }
    final intersection = group.intersection;
    if (intersection != null) return intersection;
    final line = group.lines.reduce((a, b) => b.length > a.length ? b : a);
    return line.cells[line.length ~/ 2];
  }

  /// The cells a power destroys when it goes off.
  ///
  /// [swappedKind] only matters for a colour bomb: it is the kind the bomb was
  /// swapped with. Without one, the bomb falls back to its own kind, which is
  /// what happens when it is caught in someone else's blast.
  static Set<Pos> blastOf(Board board, Pos at, {int? swappedKind}) {
    final tile = board.at(at);
    if (tile == null || !tile.isSpecial) return const {};

    switch (tile.power) {
      case TilePower.none:
        return const {};
      case TilePower.clearRow:
        return {
          for (var col = 0; col < board.cols; col++)
            if (board.atRc(at.row, col) != null) Pos(at.row, col),
        };
      case TilePower.clearColumn:
        return {
          for (var row = 0; row < board.rows; row++)
            if (board.atRc(row, at.col) != null) Pos(row, at.col),
        };
      case TilePower.bomb:
        return {
          for (var row = at.row - 1; row <= at.row + 1; row++)
            for (var col = at.col - 1; col <= at.col + 1; col++)
              if (board.atRc(row, col) != null) Pos(row, col),
        };
      case TilePower.colourBomb:
        final target = swappedKind ?? tile.kind;
        return {
          for (final p in board.positions)
            if (board.kindAt(p) == target) p,
          at,
        };
    }
  }

  /// Expands a set of cleared cells until every power caught in the blast has
  /// gone off too.
  ///
  /// Each tile detonates at most once, so the chain always terminates.
  /// Returns the full set of cells to clear, and the order powers fired in so
  /// the UI can play them back.
  static ({Set<Pos> cells, List<Pos> detonated}) resolveBlasts(
    Board board,
    Set<Pos> initial, {
    Map<Pos, int> swappedKinds = const {},
  }) {
    final cleared = {...initial};
    final detonated = <Pos>[];
    final pending = [...initial];

    while (pending.isNotEmpty) {
      final at = pending.removeLast();
      final tile = board.at(at);
      if (tile == null || !tile.isSpecial) continue;
      if (detonated.contains(at)) continue;
      detonated.add(at);

      for (final hit in blastOf(board, at, swappedKind: swappedKinds[at])) {
        if (cleared.add(hit)) {
          pending.add(hit);
        } else if (!detonated.contains(hit) &&
            (board.at(hit)?.isSpecial ?? false)) {
          // Already-cleared cells can still hold an unfired power.
          pending.add(hit);
        }
      }
    }

    return (cells: cleared, detonated: detonated);
  }
}
