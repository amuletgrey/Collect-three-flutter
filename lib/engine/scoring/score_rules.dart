import '../matching/match_line.dart';

/// Scoring, as specified in docs/CONCEPT.md §2.
class ScoreRules {
  const ScoreRules._();

  static const int maxCascadeMultiplier = 8;

  /// Per tile removed by a power rather than by a line. Worth more than a tile
  /// in a plain three, which is what makes firing powers deliberately pay.
  static const int blastScorePerTile = 20;

  /// 3 -> 30, 4 -> 80, 5 -> 150, 6 -> 240. Longer lines are worth
  /// disproportionately more, which is what makes setting them up worthwhile.
  static int lineScore(int length) {
    if (length < 3) return 0;
    return 10 * length * (length - 2);
  }

  /// First resolution of a move scores x1, the cascade after it x2, and so on.
  /// The multiplier resets at the start of every player move.
  static int cascadeMultiplier(int step) => step.clamp(1, maxCascadeMultiplier);

  /// [blastTiles] counts tiles removed by a power that were not already part of
  /// a matched line, so nothing is paid for twice.
  static int stepScore(
    Iterable<MatchLine> lines,
    int step, {
    int blastTiles = 0,
  }) {
    final base = lines.fold<int>(
      0,
      (sum, line) => sum + lineScore(line.length),
    );
    return (base + blastTiles * blastScorePerTile) * cascadeMultiplier(step);
  }
}
