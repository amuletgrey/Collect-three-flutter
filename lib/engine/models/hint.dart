import 'move.dart';

/// How much a mode was able to promise about the move it suggested.
///
/// Most modes cannot promise anything beyond "this is legal": Infinite Hunt has
/// no winning position to steer towards, and Rising Tide's board is about to
/// change underneath the player anyway. Clear the Board is different — it has a
/// solver, so it can say whether the move is actually on a line that empties
/// the board.
enum HintKind {
  /// A legal move, and nothing more is claimed.
  legalMove,

  /// The first step of a sequence that clears the board.
  winningLine,

  /// A legal move, but the level is provably no longer winnable. Worth telling
  /// the player: it means undo or restart, not keep going.
  deadEnd,
}

/// A move to show the player, and what the mode knows about it.
class Hint {
  const Hint(this.move, {this.kind = HintKind.legalMove});

  final Move move;
  final HintKind kind;

  bool get leadsToWin => kind == HintKind.winningLine;
  bool get isDeadEnd => kind == HintKind.deadEnd;

  @override
  String toString() => 'Hint($move, ${kind.name})';
}
