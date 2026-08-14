import 'grid_config.dart';
import 'position.dart';
import 'tile.dart';

/// The playing field: a row-major grid of cells, each holding a tile or nothing.
///
/// Cells are nullable because holes are a real game state in Clear the Board and
/// Rising Tide. Boards behave as values — every mutating method returns a new
/// board, which is what makes undo and snapshotting trivial. At 8x10 the copies
/// are far too small to be worth optimising away.
class Board {
  Board._(this.rows, this.cols, this._cells);

  factory Board.fromCells(int rows, int cols, List<Tile?> cells) {
    if (cells.length != rows * cols) {
      throw ArgumentError('expected ${rows * cols} cells, got ${cells.length}');
    }
    return Board._(rows, cols, List<Tile?>.of(cells));
  }

  factory Board.empty(int rows, int cols) =>
      Board._(rows, cols, List<Tile?>.filled(rows * cols, null));

  /// Builds a board from a text sketch — digits are kinds, `.` is an empty cell.
  ///
  /// Test fixtures read far better this way than as raw cell lists:
  /// ```
  /// Board.parse('''
  ///   012
  ///   1.1
  ///   201
  /// ''')
  /// ```
  factory Board.parse(String sketch, {TileFactory? tiles}) {
    final factory = tiles ?? TileFactory();
    final lines = sketch
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) throw ArgumentError('empty sketch');
    final cols = lines.first.length;
    if (lines.any((l) => l.length != cols)) {
      throw ArgumentError('all sketch rows must have the same width');
    }
    final cells = <Tile?>[];
    for (final line in lines) {
      for (final char in line.split('')) {
        if (char == '.') {
          cells.add(null);
        } else {
          final kind = int.tryParse(char);
          if (kind == null) throw ArgumentError('bad sketch character "$char"');
          cells.add(factory.create(kind));
        }
      }
    }
    return Board._(lines.length, cols, cells);
  }

  final int rows;
  final int cols;
  final List<Tile?> _cells;

  GridConfig configWith(int kindCount) =>
      GridConfig(rows: rows, cols: cols, kindCount: kindCount);

  bool contains(Pos p) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  int indexOf(Pos p) => p.row * cols + p.col;

  Tile? at(Pos p) => contains(p) ? _cells[indexOf(p)] : null;

  Tile? atRc(int row, int col) => at(Pos(row, col));

  /// Kind at [p], or `null` for an empty or off-board cell.
  ///
  /// A relic also reports `null`: it is cargo, not a colour, and reporting it
  /// this way is what keeps every matcher, generator and power from ever
  /// treating one as part of a line.
  int? kindAt(Pos p) {
    final tile = at(p);
    return tile == null || tile.isRelic ? null : tile.kind;
  }

  bool isEmptyAt(Pos p) => at(p) == null;

  Iterable<Pos> get positions sync* {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        yield Pos(r, c);
      }
    }
  }

  Iterable<Tile> get tiles => _cells.whereType<Tile>();

  int get tileCount => tiles.length;

  bool get isEmpty => tileCount == 0;

  bool get isFull => !_cells.contains(null);

  List<Tile?> toCells() => List<Tile?>.of(_cells);

  Board withTile(Pos p, Tile? tile) {
    if (!contains(p)) throw RangeError('$p is off the board');
    final next = List<Tile?>.of(_cells);
    next[indexOf(p)] = tile;
    return Board._(rows, cols, next);
  }

  Board withCleared(Iterable<Pos> cells) {
    final next = List<Tile?>.of(_cells);
    for (final p in cells) {
      if (contains(p)) next[indexOf(p)] = null;
    }
    return Board._(rows, cols, next);
  }

  Board withSwap(Pos a, Pos b) {
    if (!contains(a) || !contains(b)) throw RangeError('swap off the board');
    final next = List<Tile?>.of(_cells);
    final tmp = next[indexOf(a)];
    next[indexOf(a)] = next[indexOf(b)];
    next[indexOf(b)] = tmp;
    return Board._(rows, cols, next);
  }

  Pos? positionOfTile(int tileId) {
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i]?.id == tileId) return Pos(i ~/ cols, i % cols);
    }
    return null;
  }

  /// Round-trips with [Board.parse]; the readable form in test failures.
  String toSketch() {
    final buffer = StringBuffer();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final tile = atRc(r, c);
        buffer.write(tile == null ? '.' : tile.kind.toString());
      }
      if (r != rows - 1) buffer.write('\n');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (other is! Board || other.rows != rows || other.cols != cols) {
      return false;
    }
    for (var i = 0; i < _cells.length; i++) {
      if (other._cells[i] != _cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(rows, cols, Object.hashAll(_cells));

  @override
  String toString() => 'Board(${rows}x$cols)\n${toSketch()}';
}
