/// A single playing piece.
///
/// [id] is stable for the whole lifetime of the tile: the UI animates tiles by
/// id, so a tile that merely falls must keep the same id rather than being
/// recreated. [kind] is an index into the active skin's artwork list — the
/// engine never knows what colour or shape a kind looks like.
class Tile {
  const Tile(this.id, this.kind);

  final int id;
  final int kind;

  Tile withKind(int newKind) => Tile(id, newKind);

  @override
  bool operator ==(Object other) =>
      other is Tile && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() => 'Tile#$id(k$kind)';
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
