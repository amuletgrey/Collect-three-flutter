import '../models/board.dart';
import '../models/move.dart';
import '../models/position.dart';
import 'match_finder.dart';

/// Enumerates the swaps a player is actually allowed to make.
///
/// "No legal move left" is a real game state in every mode — it ends an Infinite
/// Hunt run, fails a Clear the Board level, and forces the tide up in Rising
/// Tide — so this has to be exact.
class MoveFinder {
  const MoveFinder._();

  /// Every legal swap on the board. Each pair is reported once: only the
  /// right and down neighbours are tried, which covers all adjacent pairs.
  static List<Move> legalMoves(Board board) {
    final moves = <Move>[];
    for (final p in board.positions) {
      for (final q in [p.right, p.down]) {
        if (!board.contains(q)) continue;
        if (createsMatch(board, p, q)) moves.add(Move(p, q));
      }
    }
    return moves;
  }

  static bool hasLegalMove(Board board) => firstLegalMove(board) != null;

  /// Short-circuiting version of [legalMoves] — also serves as the hint.
  static Move? firstLegalMove(Board board) {
    for (final p in board.positions) {
      for (final q in [p.right, p.down]) {
        if (!board.contains(q)) continue;
        if (createsMatch(board, p, q)) return Move(p, q);
      }
    }
    return null;
  }

  /// Whether swapping [a] and [b] produces at least one line of 3+.
  ///
  /// Both cells must hold tiles: you cannot slide a tile into a hole, and
  /// swapping two tiles of the same kind cannot change anything.
  static bool createsMatch(Board board, Pos a, Pos b) {
    if (!a.isAdjacentTo(b)) return false;
    final tileA = board.at(a);
    final tileB = board.at(b);
    if (tileA == null || tileB == null) return false;
    if (tileA.kind == tileB.kind) return false;
    final swapped = board.withSwap(a, b);
    return MatchFinder.hasMatchThrough(swapped, a) ||
        MatchFinder.hasMatchThrough(swapped, b);
  }
}
