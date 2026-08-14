/// A board coordinate. Row first, always — see AGENTS.md.
class Pos {
  const Pos(this.row, this.col);

  final int row;
  final int col;

  Pos get up => Pos(row - 1, col);
  Pos get down => Pos(row + 1, col);
  Pos get left => Pos(row, col - 1);
  Pos get right => Pos(row, col + 1);

  /// The four orthogonal neighbours. Diagonals are never adjacent in this game.
  List<Pos> get neighbours => [up, down, left, right];

  bool isAdjacentTo(Pos other) =>
      (row - other.row).abs() + (col - other.col).abs() == 1;

  Pos translate(int dRow, int dCol) => Pos(row + dRow, col + dCol);

  @override
  bool operator ==(Object other) =>
      other is Pos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}
