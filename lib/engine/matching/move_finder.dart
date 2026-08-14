import '../models/board.dart';
import '../models/move.dart';
import '../models/position.dart';
import '../models/tile.dart';
import 'match_finder.dart';

/// Enumerates the swaps a player is actually allowed to make.
///
/// "No legal move left" is a real game state in every mode — it ends an Infinite
/// Hunt run, fails a Clear the Board level, and forces the tide up in Rising
/// Tide — so this has to be exact. That includes the swaps that are legal
/// *without* forming a line, which is how a colour bomb is played.
class MoveFinder {
  const MoveFinder._();

  /// Every legal swap on the board. Each pair is reported once: only the
  /// right and down neighbours are tried, which covers all adjacent pairs.
  static List<Move> legalMoves(Board board, {bool specials = false}) {
    final moves = <Move>[];
    for (final p in board.positions) {
      for (final q in [p.right, p.down]) {
        if (!board.contains(q)) continue;
        if (createsMatch(board, p, q, specials: specials)) {
          moves.add(Move(p, q));
        }
      }
    }
    return moves;
  }

  static bool hasLegalMove(Board board, {bool specials = false}) =>
      firstLegalMove(board, specials: specials) != null;

  /// Short-circuiting version of [legalMoves] — also serves as the hint.
  static Move? firstLegalMove(Board board, {bool specials = false}) {
    for (final p in board.positions) {
      for (final q in [p.right, p.down]) {
        if (!board.contains(q)) continue;
        if (createsMatch(board, p, q, specials: specials)) return Move(p, q);
      }
    }
    return null;
  }

  /// Whether swapping [a] and [b] is a move the player may make.
  ///
  /// Normally that means producing a line of 3+. With [specials] on, a swap
  /// involving a colour bomb is always allowed — it fires on contact rather
  /// than by matching — as is swapping two powers together.
  static bool createsMatch(Board board, Pos a, Pos b, {bool specials = false}) {
    if (!a.isAdjacentTo(b)) return false;
    final tileA = board.at(a);
    final tileB = board.at(b);
    if (tileA == null || tileB == null) return false;

    if (specials && firesOnSwap(tileA, tileB)) return true;
    if (tileA.kind == tileB.kind) return false;

    final swapped = board.withSwap(a, b);
    return MatchFinder.hasMatchThrough(swapped, a) ||
        MatchFinder.hasMatchThrough(swapped, b);
  }

  /// A swap that goes off on its own, with no line involved.
  static bool firesOnSwap(Tile a, Tile b) =>
      a.power == TilePower.colourBomb ||
      b.power == TilePower.colourBomb ||
      (a.isSpecial && b.isSpecial);
}
