// flutter_test exports its own MatchFinder (a widget finder); hide it so the
// engine's matcher keeps its domain name.
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

RisingTideMode _mode({
  int rows = 10,
  int cols = 8,
  int initialRows = 5,
  int baseInterval = 5,
  int minInterval = 2,
}) => RisingTideMode(
  grid: GridConfig(rows: rows, cols: cols, kindCount: 6),
  initialRows: initialRows,
  baseInterval: baseInterval,
  minInterval: minInterval,
);

void main() {
  test('starts with only the bottom rows stacked', () {
    final mode = _mode();
    final engine = GameEngine(mode: mode, seed: 2);

    expect(engine.board.tileCount, 40);
    expect(engine.board.atRc(0, 0), isNull);
    expect(engine.status, GameStatus.playing);
    expect(mode.movesUntilRise, 5);
  });

  test('the tide rises on schedule and adds exactly one row each time', () {
    final mode = _mode(baseInterval: 2);
    final engine = GameEngine(mode: mode, seed: 3);
    final before = engine.board.tileCount;

    for (var i = 0; i < 2 && !engine.isOver; i++) {
      final hint = engine.hint()!;
      engine.applyMove(hint.a, hint.b);
    }

    expect(mode.rowsRisen, greaterThanOrEqualTo(1));
    // Rises add a full row; clears only ever remove tiles in threes.
    final added = mode.rowsRisen * 8;
    expect((before + added - engine.board.tileCount) % 3, 0);
  });

  test('a rise pushes the whole stack up one row', () {
    final mode = _mode(baseInterval: 1, minInterval: 1);
    final engine = GameEngine(mode: mode, seed: 5);

    final hint = engine.hint()!;
    final result = engine.applyMove(hint.a, hint.b);
    final inserted = result.events.whereType<RowInserted>().first;

    expect(inserted.spawned, hasLength(8));
    for (final spawn in inserted.spawned) {
      expect(spawn.at.row, 9, reason: 'new tiles arrive on the bottom row');
      expect(spawn.from.row, 10, reason: 'and slide in from below the board');
    }
    for (final move in inserted.pushed) {
      expect(move.to.row, move.from.row - 1);
      expect(move.to.col, move.from.col);
    }
  });

  test('the board is never left with an unresolved match', () {
    for (var seed = 0; seed < 25; seed++) {
      final engine = GameEngine(
        mode: _mode(baseInterval: 1, minInterval: 1),
        seed: seed,
      );

      for (var i = 0; i < 6 && !engine.isOver; i++) {
        final hint = engine.hint();
        if (hint == null) break;
        engine.applyMove(hint.a, hint.b);
        expect(
          MatchFinder.find(engine.board).isEmpty,
          isTrue,
          reason: 'seed $seed left an unresolved match',
        );
      }
    }
  });

  test('a stalled board is re-fed rather than ended', () {
    final mode = _mode(rows: 6, cols: 5, initialRows: 3, baseInterval: 99);
    final engine = GameEngine(mode: mode, seed: 8);

    var moves = 0;
    while (!engine.isOver && moves < 60) {
      final hint = engine.hint();
      expect(
        hint,
        isNotNull,
        reason: 'the run may never present a board with no moves',
      );
      engine.applyMove(hint!.a, hint.b);
      moves++;
    }

    // The interval is 99, so every rise here was forced by a stall.
    expect(mode.rowsRisen, greaterThan(0));
    if (engine.isOver) {
      expect(engine.endReason, GameEndReason.overflow);
    }
  });

  test('a stack pushed past the top row drowns', () {
    final mode = _mode(
      rows: 5,
      cols: 5,
      initialRows: 5,
      baseInterval: 1,
      minInterval: 1,
    );
    final engine = GameEngine(mode: mode, seed: 4);

    final hint = engine.hint()!;
    final result = engine.applyMove(hint.a, hint.b);

    expect(engine.status, GameStatus.lost);
    expect(engine.endReason, GameEndReason.overflow);
    expect(result.events.last, isA<GameEnded>());
    expect(mode.overflowed, isTrue);
  });

  test('the tide speeds up as rows pile on, down to a floor', () {
    final mode = _mode(baseInterval: 5);

    expect(mode.intervalForRows(0), 5);
    expect(mode.intervalForRows(7), 5);
    expect(mode.intervalForRows(8), 4, reason: 'one faster every 8 rows');
    expect(mode.intervalForRows(16), 3);
    expect(mode.intervalForRows(200), mode.minInterval);
  });

  test('never runs long without ending or staying playable', () {
    for (final seed in [1, 17, 404]) {
      final mode = _mode(baseInterval: 3);
      final engine = GameEngine(mode: mode, seed: seed);
      var moves = 0;

      while (!engine.isOver && moves < 200) {
        final hint = engine.hint();
        expect(hint, isNotNull, reason: 'seed $seed stalled');
        engine.applyMove(hint!.a, hint.b);
        moves++;
        expect(engine.board.tileCount, lessThanOrEqualTo(80));
      }

      if (engine.isOver) {
        expect(engine.status, GameStatus.lost);
        expect(engine.endReason, GameEndReason.overflow);
      }
    }
  });

  test('does not offer undo', () {
    final engine = GameEngine(mode: _mode(), seed: 1);

    expect(engine.canUndo, isFalse);
    expect(engine.undo(), isFalse);
  });
}
