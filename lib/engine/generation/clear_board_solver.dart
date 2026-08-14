import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/move.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';
import '../resolution/resolver.dart';

class SolveOutcome {
  const SolveOutcome({
    required this.solved,
    required this.moves,
    required this.nodesVisited,
    required this.budgetExhausted,
  });

  final bool solved;

  /// The winning move sequence, in order. Empty when [solved] is false.
  final List<Move> moves;
  final int nodesVisited;

  /// True when the search ran out of budget — the layout might still be
  /// solvable, we just did not prove it.
  final bool budgetExhausted;

  int get moveCount => moves.length;

  @override
  String toString() => solved
      ? 'SolveOutcome(solved in ${moves.length} moves, $nodesVisited nodes)'
      : 'SolveOutcome(unsolved, $nodesVisited nodes'
            '${budgetExhausted ? ', budget exhausted' : ''})';
}

/// Proves whether a Clear the Board layout can actually be emptied.
///
/// This is what makes the mode fair: a random layout is almost never solvable,
/// so `tool/generate_levels.dart` throws candidates at this and only ships the
/// ones it beat. Nothing at runtime needs to solve anything.
///
/// The search is a depth-first dive that tries the biggest clears first. With
/// no refill, every accepted move removes at least three tiles, so the tree is
/// never deeper than `tiles / 3` — the cost is breadth, not depth, which is
/// what the visited set and the node budget are for.
class ClearBoardSolver {
  const ClearBoardSolver({this.nodeBudget = 150000});

  /// Board states to expand before giving up.
  final int nodeBudget;

  SolveOutcome solve(Board start) {
    // Refill is off, so the resolver never draws from the rng and the tile ids
    // it hands out are irrelevant — only the layout of kinds matters.
    const resolver = Resolver(
      gravity: GravityRule.downThenLeft,
      refill: RefillRule.none,
      kindCount: 7,
    );
    final rng = SeededRandom(0);
    final visited = <String>{};
    final path = <Move>[];
    var nodes = 0;

    bool dive(Board board) {
      if (board.isEmpty) return true;
      if (nodes >= nodeBudget) return false;
      nodes++;
      if (!visited.add(board.toSketch())) return false;

      final candidates = <({Move move, Board next, int cleared})>[];
      for (final move in MoveFinder.legalMoves(board)) {
        final outcome = resolver.resolve(
          board: board.withSwap(move.a, move.b),
          rng: rng,
          tiles: TileFactory(),
        );
        candidates.add((
          move: move,
          next: outcome.board,
          cleared: outcome.tilesCleared,
        ));
      }
      // Biggest clears first: cascades tend to open the board up, and a greedy
      // dive finds a winning line quickly on layouts that have one.
      candidates.sort((a, b) => b.cleared.compareTo(a.cleared));

      for (final candidate in candidates) {
        path.add(candidate.move);
        if (dive(candidate.next)) return true;
        path.removeLast();
        if (nodes >= nodeBudget) return false;
      }
      return false;
    }

    final solved = dive(start);
    return SolveOutcome(
      solved: solved,
      moves: solved ? List.unmodifiable(path) : const [],
      nodesVisited: nodes,
      budgetExhausted: !solved && nodes >= nodeBudget,
    );
  }
}
