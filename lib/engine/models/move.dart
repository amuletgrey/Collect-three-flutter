import 'dart:math' as math;

import 'position.dart';

/// A candidate swap of two cells. Adjacency is validated by the engine when the
/// move is applied, not by this value type.
class Move {
  const Move(this.a, this.b);

  final Pos a;
  final Pos b;

  bool get isAdjacent => a.isAdjacentTo(b);

  Move get reversed => Move(b, a);

  int get _keyA => a.row * 1000 + a.col;
  int get _keyB => b.row * 1000 + b.col;

  /// Order-independent: swapping a with b is the same move as swapping b with a.
  @override
  bool operator ==(Object other) =>
      other is Move &&
      ((other.a == a && other.b == b) || (other.a == b && other.b == a));

  @override
  int get hashCode =>
      Object.hash(math.min(_keyA, _keyB), math.max(_keyA, _keyB));

  @override
  String toString() => 'Move($a <-> $b)';
}
