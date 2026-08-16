import '../game_engine.dart';
import '../models/move.dart';
import '../modes/game_mode.dart';
import '../modes/work_order_mode.dart';

/// What one bot run came to.
class OrderRun {
  const OrderRun({
    required this.filled,
    required this.movesUsed,
    required this.score,
  });

  final bool filled;
  final int movesUsed;
  final int score;
}

/// Plays a Work Order the way a competent player would, so a level can be
/// judged before it ships.
///
/// This is the counterpart to [ClearBoardSolver], and it exists for the same
/// reason: a level nobody has beaten is not a level, it is a guess. The
/// difference is that an order cannot be *proved* fillable — the board refills
/// at random, so there is no tree to search. What can be done is play it, many
/// times, and ship the ones a decent player finishes.
///
/// The bot picks moves by cloning the engine and actually playing each
/// candidate. That is slower than a heuristic, but it is the real game rather
/// than a second implementation of it that could quietly disagree — and this
/// runs offline, where correctness is worth far more than speed.
class OrderBot {
  const OrderBot();

  OrderRun play({
    required WorkOrderMode Function() mode,
    required int seed,
  }) {
    final engine = GameEngine(mode: mode(), seed: seed);
    // The move budget ends the run, so this only guards against a rule bug
    // leaving the game unable to finish.
    for (var guard = 0; guard < 500 && !engine.isOver; guard++) {
      final move = bestMove(engine, mode);
      if (move == null) break;
      engine.applyMove(move.a, move.b);
    }
    return OrderRun(
      filled: engine.status == GameStatus.won,
      movesUsed: engine.movesMade,
      score: engine.score,
    );
  }

  /// The legal move that advances the order most, ties broken by score.
  ///
  /// Progress is measured against the lines that are still open: a move that
  /// collects forty of a colour already ticked off is worth nothing here, which
  /// is exactly how a player would see it.
  Move? bestMove(GameEngine engine, WorkOrderMode Function() mode) {
    final before = _remaining(engine.mode as WorkOrderMode);
    Move? best;
    var bestGain = -1.0;
    var bestScore = -1;

    for (final move in engine.legalMoves) {
      final clone = GameEngine.restore(mode: mode(), snapshot: engine.snapshot());
      final result = clone.applyMove(move.a, move.b);
      if (!result.accepted) continue;

      final gain = before - _remaining(clone.mode as WorkOrderMode);
      final score = result.scoreDelta;
      if (gain > bestGain || (gain == bestGain && score > bestScore)) {
        best = move;
        bestGain = gain;
        bestScore = score;
      }
    }
    return best;
  }

  /// How much of the order is still outstanding, as a share of each line
  /// rather than a count of tiles.
  ///
  /// Counting raw units let a collect line worth thirty tiles drown out a chain
  /// line worth four, so the bot never went hunting for the chain — it just
  /// matched and hoped. A player does not think that way: a line is a line, and
  /// the one you are furthest from is the one you work on.
  double _remaining(WorkOrderMode mode) {
    var total = 0.0;
    for (final line in mode.order) {
      if (line.target == 0) continue;
      total += (line.target - line.progress) / line.target;
    }
    return total;
  }
}
