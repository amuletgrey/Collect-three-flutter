import 'package:collect_three/engine/engine.dart';
// flutter_test exports its own MatchFinder (a widget finder); hide it so the
// engine's matcher keeps its domain name.
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;

void main() {
  test('starts full, playable, and scoreless', () {
    final engine = GameEngine(mode: const InfiniteHuntMode(), seed: 1);

    expect(engine.status, GameStatus.playing);
    expect(engine.board.isFull, isTrue);
    expect(engine.score, 0);
    expect(engine.legalMoves, isNotEmpty);
    expect(engine.canUndo, isFalse, reason: 'endless mode does not offer undo');
  });

  test('the board stays full after every move', () {
    final engine = GameEngine(mode: const InfiniteHuntMode(), seed: 7);

    for (var i = 0; i < 60 && !engine.isOver; i++) {
      final hint = engine.hint()!;
      expect(engine.applyMove(hint.a, hint.b).accepted, isTrue);
      expect(engine.board.isFull, isTrue, reason: 'hole left after move $i');
      expect(
        MatchFinder.find(engine.board).isEmpty,
        isTrue,
        reason: 'unresolved match after move $i',
      );
    }
  });

  test('scoring only ever goes up, and moves are counted', () {
    final engine = GameEngine(mode: const InfiniteHuntMode(), seed: 21);
    var previous = 0;

    for (var i = 0; i < 30 && !engine.isOver; i++) {
      final hint = engine.hint()!;
      engine.applyMove(hint.a, hint.b);
      expect(engine.score, greaterThan(previous));
      expect(engine.movesMade, i + 1);
      previous = engine.score;
    }
  });

  test('survives a long seeded run without ever getting stuck', () {
    for (final seed in [1, 2, 3, 99, 12345]) {
      final engine = GameEngine(mode: const InfiniteHuntMode(), seed: seed);
      var moves = 0;

      while (!engine.isOver && moves < 400) {
        final hint = engine.hint()!;
        engine.applyMove(hint.a, hint.b);
        moves++;
      }

      if (engine.isOver) {
        expect(engine.endReason, GameEndReason.noMovesLeft);
        expect(MoveFinder.hasLegalMove(engine.board), isFalse);
      }
    }
  });

  test('a dead board ends the run and refuses further moves', () {
    // A cramped board runs out of moves quickly, which is the whole point of
    // the mode; a full-size one can survive for thousands of moves.
    final engine = GameEngine(
      mode: const InfiniteHuntMode(
        grid: GridConfig(rows: 4, cols: 4, kindCount: 6),
      ),
      seed: 0,
    );

    while (!engine.isOver && engine.movesMade < 500) {
      final hint = engine.hint()!;
      engine.applyMove(hint.a, hint.b);
    }

    expect(engine.isOver, isTrue);
    expect(engine.status, GameStatus.lost);
    expect(engine.endReason, GameEndReason.noMovesLeft);
    expect(MoveFinder.hasLegalMove(engine.board), isFalse);
    expect(engine.hint(), isNull);

    final result = engine.applyMove(const Pos(0, 0), const Pos(0, 1));
    expect(result.accepted, isFalse);
    expect(result.rejection, MoveRejection.gameOver);
  });
}
