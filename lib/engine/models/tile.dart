/// What a tile does when it is collected.
///
/// Powers are earned by matching more than three — see docs/CONCEPT.md §2.
/// [none] is by far the common case; the rest are created by [SpecialRules].
enum TilePower {
  /// An ordinary tile.
  none,

  /// Clears the whole row it sits in. Made by a horizontal line of four.
  clearRow,

  /// Clears the whole column it sits in. Made by a vertical line of four.
  clearColumn,

  /// Clears the 3x3 block around itself. Made by an L or T shape.
  bomb,

  /// Clears every tile of one kind. Made by a line of five or more, and the
  /// only power that also fires when it is swapped rather than matched.
  colourBomb;

  bool get isLine => this == clearRow || this == clearColumn;
  bool get isSpecial => this != none;
}

/// A single playing piece.
///
/// [id] is stable for the whole lifetime of the tile: the UI animates tiles by
/// id, so a tile that merely falls must keep the same id rather than being
/// recreated. [kind] is an index into the active skin's artwork list — the
/// engine never knows what colour or shape a kind looks like.
class Tile {
  const Tile(this.id, this.kind, {this.power = TilePower.none});

  final int id;
  final int kind;
  final TilePower power;

  bool get isSpecial => power.isSpecial;

  Tile withKind(int newKind) => Tile(id, newKind, power: power);

  /// Keeps the id: earning a power upgrades a tile in place rather than
  /// swapping in a new one, so the UI can animate the change.
  Tile withPower(TilePower newPower) => Tile(id, kind, power: newPower);

  @override
  bool operator ==(Object other) =>
      other is Tile &&
      other.id == id &&
      other.kind == kind &&
      other.power == power;

  @override
  int get hashCode => Object.hash(id, kind, power);

  @override
  String toString() =>
      'Tile#$id(k$kind${power == TilePower.none ? '' : ', ${power.name}'})';
}

/// Hands out unique tile ids for one game session.
///
/// Part of the engine state so that a seeded run reproduces identical ids,
/// which keeps event lists comparable in tests.
class TileFactory {
  TileFactory([int firstId = 0]) : _next = firstId;

  int _next;

  int get nextId => _next;

  Tile create(int kind) => Tile(_next++, kind);

  /// Restores the counter when a move is undone.
  void restore(int nextId) => _next = nextId;
}
