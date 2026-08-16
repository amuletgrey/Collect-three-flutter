/// What every shipped level has in common, whichever pack it came from.
///
/// The picker and the game screen work through this, so adding a pack for a
/// new mode does not mean another branch in either of them.
abstract interface class PackLevel {
  int get number;

  /// The move count the generator proved (or measured) as a good line.
  int get parMoves;

  int starsFor(int movesUsed);
}

/// One Clear the Board level, as shipped in a pack.
///
/// The layout is stored in the same text form [Board.parse] reads, which keeps
/// the pack files legible and diffable. [parMoves] is the length of the
/// solution the generator actually found, so a player matching it has matched a
/// proven line.
class Level implements PackLevel {
  const Level({
    required this.number,
    required this.sketch,
    required this.kindCount,
    required this.parMoves,
    required this.seed,
  });

  factory Level.fromJson(Map<String, Object?> json) => Level(
    number: json['number']! as int,
    sketch: json['sketch']! as String,
    kindCount: json['kinds']! as int,
    parMoves: json['par']! as int,
    seed: json['seed']! as int,
  );

  @override
  final int number;

  final String sketch;
  final int kindCount;

  @override
  final int parMoves;

  /// The generator seed that produced this layout — enough to rebuild it.
  final int seed;

  int get rows => sketch.split('\n').length;
  int get cols => sketch.split('\n').first.length;
  int get tileCount => sketch.replaceAll('\n', '').replaceAll('.', '').length;

  /// 3 stars for par, 2 for a little over, 1 for finishing at all.
  @override
  int starsFor(int movesUsed) {
    if (movesUsed <= parMoves) return 3;
    if (movesUsed <= parMoves + 3) return 2;
    return 1;
  }

  Map<String, Object?> toJson() => {
    'number': number,
    'sketch': sketch,
    'kinds': kindCount,
    'par': parMoves,
    'seed': seed,
  };
}

/// A numbered set of levels, loaded from `assets/levels/`.
class LevelPack {
  const LevelPack({
    required this.id,
    required this.version,
    required this.levels,
  });

  factory LevelPack.fromJson(Map<String, Object?> json) => LevelPack(
    id: json['id']! as String,
    version: json['version']! as int,
    levels: [
      for (final entry in json['levels']! as List<Object?>)
        Level.fromJson(entry! as Map<String, Object?>),
    ],
  );

  final String id;
  final int version;
  final List<Level> levels;

  int get length => levels.length;

  Level byNumber(int number) =>
      levels.firstWhere((level) => level.number == number);

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'levels': [for (final level in levels) level.toJson()],
  };
}
