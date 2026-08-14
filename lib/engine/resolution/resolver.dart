import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/match_finder.dart';
import '../models/board.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';
import '../scoring/score_rules.dart';
import 'board_event.dart';

class ResolutionOutcome {
  const ResolutionOutcome({
    required this.board,
    required this.events,
    required this.score,
    required this.cascadeCount,
    required this.tilesCleared,
    required this.longestLine,
  });

  final Board board;
  final List<BoardEvent> events;
  final int score;

  /// Number of resolution steps that actually cleared something.
  final int cascadeCount;
  final int tilesCleared;
  final int longestLine;

  bool get clearedAnything => cascadeCount > 0;
}

/// Runs the clear → settle → refill loop until the board is stable.
///
/// The whole cascade is computed synchronously; the caller replays the emitted
/// events as animation afterwards. Gravity and refill are injected, which is the
/// only difference between the three game modes at this level.
class Resolver {
  const Resolver({
    required this.gravity,
    required this.refill,
    required this.kindCount,
  });

  final GravityRule gravity;
  final RefillRule refill;
  final int kindCount;

  /// Safety net: a rule bug that keeps producing matches should fail loudly in
  /// tests rather than hang the game loop.
  static const int _maxCascades = 200;

  ResolutionOutcome resolve({
    required Board board,
    required SeededRandom rng,
    required TileFactory tiles,
    int startStep = 1,
  }) {
    final events = <BoardEvent>[];
    var current = board;
    var score = 0;
    var cleared = 0;
    var longest = 0;
    var step = startStep;

    while (true) {
      final matches = MatchFinder.find(current);
      if (matches.isEmpty) break;
      if (step - startStep >= _maxCascades) {
        throw StateError('cascade did not terminate after $_maxCascades steps');
      }

      final stepScore = ScoreRules.stepScore(matches.lines, step);
      score += stepScore;
      cleared += matches.cells.length;
      if (matches.longestLine > longest) longest = matches.longestLine;

      events.add(
        TilesCleared(
          cells: matches.cells.toList(),
          lines: matches.lines,
          scoreDelta: stepScore,
          cascadeStep: step,
          multiplier: ScoreRules.cascadeMultiplier(step),
        ),
      );
      current = current.withCleared(matches.cells);

      final settled = gravity.apply(current);
      current = settled.board;
      for (final batch in settled.steps) {
        if (batch.isNotEmpty) events.add(TilesMoved(batch));
      }

      final refilled = refill.apply(
        board: current,
        rng: rng,
        tiles: tiles,
        kindCount: kindCount,
      );
      current = refilled.board;
      if (refilled.spawnedAnything) {
        events.add(TilesSpawned(refilled.spawned));
      }

      step++;
    }

    return ResolutionOutcome(
      board: current,
      events: events,
      score: score,
      cascadeCount: step - startStep,
      tilesCleared: cleared,
      longestLine: longest,
    );
  }
}
