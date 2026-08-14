import 'package:collect_three/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

GameEngine _engine({
  String layout = '1102\n2210\n0021',
  GridConfig grid = const GridConfig(rows: 3, cols: 4, kindCount: 3),
}) => GameEngine(
  mode: ClearBoardMode(grid: grid, layoutSketch: layout),
  seed: 1,
);

void main() {
  group('rejected swaps change nothing', () {
    test('non-adjacent cells', () {
      final engine = _engine();
      final result = engine.applyMove(const Pos(0, 0), const Pos(2, 2));

      expect(result.rejection, MoveRejection.notAdjacent);
      expect(result.events, isEmpty);
      expect(engine.movesMade, 0);
    });

    test('a hole', () {
      final engine = _engine(layout: '110.\n2210\n0021');
      final result = engine.applyMove(const Pos(0, 2), const Pos(0, 3));

      expect(result.rejection, MoveRejection.emptyCell);
      expect(engine.movesMade, 0);
    });

    test('two tiles of the same kind', () {
      final engine = _engine();
      final result = engine.applyMove(const Pos(0, 0), const Pos(0, 1));

      expect(result.rejection, MoveRejection.sameKind);
      expect(engine.movesMade, 0);
    });
  });

  test('a swap that forms nothing is shown and taken back', () {
    final engine = _engine();
    final before = engine.board;

    final result = engine.applyMove(const Pos(1, 0), const Pos(2, 0));

    expect(result.accepted, isFalse);
    expect(result.rejection, MoveRejection.noMatch);
    expect(result.events, [isA<SwapPerformed>(), isA<SwapReverted>()]);
    expect(engine.board, equals(before), reason: 'the board must be unchanged');
    expect(engine.movesMade, 0, reason: 'a reverted swap is free');
    expect(engine.score, 0);
  });

  test('an accepted move leads with the swap and updates the run', () {
    final engine = _engine();

    final result = engine.applyMove(const Pos(0, 2), const Pos(1, 2));

    expect(result.accepted, isTrue);
    expect(result.events.first, isA<SwapPerformed>());
    expect(result.events.whereType<SwapReverted>(), isEmpty);
    expect(result.scoreDelta, 30);
    expect(result.tilesCleared, 3);
    expect(result.longestLine, 3);
    expect(engine.score, 30);
    expect(engine.movesMade, 1);
    expect(engine.tilesCollected, 3);
    expect(engine.bestChain, 1);
  });

  test('the same seed and the same moves give the same run', () {
    List<String> play(int seed) {
      final engine = GameEngine(mode: const InfiniteHuntMode(), seed: seed);
      final log = <String>[];
      for (var i = 0; i < 25 && !engine.isOver; i++) {
        final hint = engine.hint()!;
        engine.applyMove(hint.a, hint.b);
        log.add('${engine.score}|${engine.board.toSketch()}');
      }
      return log;
    }

    expect(play(42), play(42));
    expect(play(42), isNot(play(43)));
  });

  test('tracks the best chain of the run', () {
    // Completing the middle row of 0s drops two columns onto themselves, so
    // one move resolves in two steps.
    final engine = _engine(
      layout: '122\n121\n001\n120\n212',
      grid: const GridConfig(rows: 5, cols: 3, kindCount: 3),
    );

    final result = engine.applyMove(const Pos(2, 2), const Pos(3, 2));

    expect(result.accepted, isTrue);
    expect(result.cascadeCount, 2);
    expect(result.tilesCleared, 9);
    expect(engine.bestChain, 2);
    // 30 for the row, then two chained triples at x2.
    expect(engine.score, 30 + 120);
  });

  test('a finished run refuses further moves', () {
    final engine = _engine(
      layout: '012\n120\n201',
      grid: const GridConfig(rows: 3, cols: 3, kindCount: 3),
    );

    expect(engine.status, GameStatus.lost);
    final result = engine.applyMove(const Pos(0, 0), const Pos(0, 1));
    expect(result.rejection, MoveRejection.gameOver);
  });

  test('modes without an undo budget never expose undo', () {
    final engine = GameEngine(mode: const InfiniteHuntMode(), seed: 3);
    final hint = engine.hint()!;
    engine.applyMove(hint.a, hint.b);

    expect(engine.canUndo, isFalse);
    expect(engine.undo(), isFalse);
  });

  test('the hint is always playable while the run is alive', () {
    final engine = GameEngine(mode: const InfiniteHuntMode(), seed: 11);

    for (var i = 0; i < 20 && !engine.isOver; i++) {
      final hint = engine.hint()!;
      expect(engine.applyMove(hint.a, hint.b).accepted, isTrue);
    }
  });
}
