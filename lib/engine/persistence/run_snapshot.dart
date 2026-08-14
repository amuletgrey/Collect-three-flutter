import '../models/board.dart';
import '../models/tile.dart';

/// A run frozen mid-play, complete enough to carry on from.
///
/// The board is stored cell by cell with tile ids and powers, not as a
/// [Board.parse] sketch: the sketch only carries kinds, and resuming with new
/// ids would make the UI cross-fade every tile instead of leaving them be.
///
/// The generator state travels with it, so the tiles that fall after a resume
/// are the ones that would have fallen anyway.
class RunSnapshot {
  const RunSnapshot({
    required this.version,
    required this.modeId,
    required this.rows,
    required this.cols,
    required this.cells,
    required this.seed,
    required this.rngState,
    required this.rngDraws,
    required this.nextTileId,
    required this.score,
    required this.movesMade,
    required this.tilesCollected,
    required this.bestChain,
    required this.longestLine,
    required this.specialsFired,
    this.elapsedSeconds = 0,
    this.hintsRemaining,
    this.hintsEarned = 0,
    this.modeState = const {},
    this.levelNumber,
    this.packId,
  });

  factory RunSnapshot.fromJson(Map<String, Object?> json) => RunSnapshot(
    version: json['version']! as int,
    modeId: json['mode']! as String,
    rows: json['rows']! as int,
    cols: json['cols']! as int,
    cells: [
      for (final cell in json['cells']! as List<Object?>)
        cell == null ? null : (cell as List<Object?>).cast<int>(),
    ],
    seed: json['seed']! as int,
    rngState: json['rngState']! as int,
    rngDraws: json['rngDraws']! as int,
    nextTileId: json['nextTileId']! as int,
    score: json['score']! as int,
    movesMade: json['moves']! as int,
    tilesCollected: json['tiles']! as int,
    bestChain: json['bestChain']! as int,
    longestLine: json['longestLine']! as int,
    specialsFired: json['specialsFired']! as int,
    elapsedSeconds: json['elapsed'] as int? ?? 0,
    hintsRemaining: json['hints'] as int?,
    hintsEarned: json['hintsEarned'] as int? ?? 0,
    modeState: (json['modeState'] as Map<Object?, Object?>? ?? const {}).map(
      (key, value) => MapEntry(key! as String, value),
    ),
    levelNumber: json['level'] as int?,
    packId: json['pack'] as String?,
  );

  /// Bumped whenever this format changes, so an old save is dropped rather
  /// than misread.
  static const int currentVersion = 1;

  final int version;
  final String modeId;
  final int rows;
  final int cols;

  /// Row-major; each entry is `null` or `[id, kind, powerIndex, roleIndex]`.
  /// Saves written before roles existed have three entries and read back as
  /// ordinary tiles.
  final List<List<int>?> cells;

  final int seed;
  final int rngState;
  final int rngDraws;
  final int nextTileId;

  final int score;
  final int movesMade;
  final int tilesCollected;
  final int bestChain;
  final int longestLine;
  final int specialsFired;

  /// Seconds of play so far. Measured by the controller — the engine never
  /// reads a clock — and carried here so a resumed run keeps counting.
  final int elapsedSeconds;

  /// Hints still in hand. Null on a save written before hints were a resource,
  /// which resumes on the mode's starting allowance rather than on nothing.
  final int? hintsRemaining;

  /// How many hints the run has earned by scoring, so a resumed run does not
  /// collect the same milestone twice.
  final int hintsEarned;

  /// Whatever the mode needs to pick up where it left off — Rising Tide keeps
  /// its tide counters here.
  final Map<String, Object?> modeState;

  final int? levelNumber;
  final String? packId;

  bool get isCurrent => version == currentVersion;

  Board toBoard() => Board.fromCells(rows, cols, [
    for (final cell in cells)
      if (cell == null)
        null
      else
        Tile(
          cell[0],
          cell[1],
          power: TilePower.values[cell[2]],
          role: cell.length > 3 ? TileRole.values[cell[3]] : TileRole.normal,
        ),
  ]);

  static List<List<int>?> cellsOf(Board board) => [
    for (final pos in board.positions)
      if (board.at(pos) case final tile?)
        [tile.id, tile.kind, tile.power.index, tile.role.index]
      else
        null,
  ];

  Map<String, Object?> toJson() => {
    'version': version,
    'mode': modeId,
    'rows': rows,
    'cols': cols,
    'cells': cells,
    'seed': seed,
    'rngState': rngState,
    'rngDraws': rngDraws,
    'nextTileId': nextTileId,
    'score': score,
    'moves': movesMade,
    'tiles': tilesCollected,
    'bestChain': bestChain,
    'longestLine': longestLine,
    'specialsFired': specialsFired,
    'elapsed': elapsedSeconds,
    if (hintsRemaining != null) 'hints': hintsRemaining,
    'hintsEarned': hintsEarned,
    'modeState': modeState,
    if (levelNumber != null) 'level': levelNumber,
    if (packId != null) 'pack': packId,
  };

  @override
  String toString() =>
      'RunSnapshot($modeId, ${rows}x$cols, score $score, move $movesMade)';
}
