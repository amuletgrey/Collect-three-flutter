import 'position.dart';
import 'tile.dart';

/// One tile travelling from one cell to another. The UI animates by [tileId].
class TileMove {
  const TileMove(this.tileId, this.from, this.to);

  final int tileId;
  final Pos from;
  final Pos to;

  int get rowsTravelled => (to.row - from.row).abs();
  int get colsTravelled => (to.col - from.col).abs();

  @override
  bool operator ==(Object other) =>
      other is TileMove &&
      other.tileId == tileId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(tileId, from, to);

  @override
  String toString() => 'TileMove(#$tileId $from -> $to)';
}

/// A newly created tile and where it should animate in from.
///
/// [from] is deliberately allowed to sit outside the board (negative rows for
/// top refills, `rows` for a rising bottom row) so the UI can slide it in from
/// off-screen without inventing coordinates of its own.
class SpawnedTile {
  const SpawnedTile(this.tile, this.at, this.from);

  final Tile tile;
  final Pos at;
  final Pos from;

  @override
  bool operator ==(Object other) =>
      other is SpawnedTile &&
      other.tile == tile &&
      other.at == at &&
      other.from == from;

  @override
  int get hashCode => Object.hash(tile, at, from);

  @override
  String toString() => 'SpawnedTile(${tile.id} k${tile.kind} at $at)';
}

/// A tile that earned a power and stays where it is.
///
/// The id is unchanged on purpose: the tile is upgraded in place rather than
/// replaced, so the board can animate the change instead of popping a new tile
/// into existence.
class UpgradedTile {
  const UpgradedTile(this.tile, this.at);

  final Tile tile;
  final Pos at;

  @override
  bool operator ==(Object other) =>
      other is UpgradedTile && other.tile == tile && other.at == at;

  @override
  int get hashCode => Object.hash(tile, at);

  @override
  String toString() => 'UpgradedTile(${tile.power.name} at $at)';
}
