import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

/// A palette that widens almost immediately, so a handful of moves is enough
/// to reach the second colour instead of the twelve thousand points a real run
/// needs.
InfiniteHuntMode _quick({int maxKinds = 7}) =>
    InfiniteHuntMode(pointsPerKind: 60, maxKinds: maxKinds);

/// Plays legal moves until the score passes [target] or the board dies.
/// Peeking is free, so this does not touch the hint budget.
void _playTo(GameEngine engine, int target) {
  for (var guard = 0; guard < 400 && engine.score < target; guard++) {
    final move = engine.hint();
    if (move == null || engine.isOver) return;
    engine.applyMove(move.a, move.b);
  }
}

void main() {
  test('a run starts on the grid palette', () {
    final mode = InfiniteHuntMode();

    expect(mode.activeKindCount, 6);
    expect(mode.kindsUnlocked, 0);
    expect(mode.pointsToNextKind(0), 12000);
  });

  test('scoring past the threshold widens the palette', () {
    final mode = _quick();
    final engine = GameEngine(mode: mode, seed: 7);

    _playTo(engine, 60);

    expect(engine.score, greaterThanOrEqualTo(60));
    expect(mode.kindsUnlocked, greaterThanOrEqualTo(1));
    expect(mode.activeKindCount, 7);
  });

  test('the palette stops at the seven colours a skin can draw', () {
    final mode = _quick();
    final engine = GameEngine(mode: mode, seed: 11);

    _playTo(engine, 6000);

    expect(mode.activeKindCount, 7);
    expect(mode.pointsToNextKind(engine.score), isNull);
  });

  test('a mode capped at its starting width never widens', () {
    final mode = _quick(maxKinds: 6);
    final engine = GameEngine(mode: mode, seed: 3);

    _playTo(engine, 3000);

    expect(mode.activeKindCount, 6);
    expect(mode.announcement, isNull);
  });

  test('the unlock is announced on the move that earns it, and only then', () {
    final mode = _quick();
    final engine = GameEngine(mode: mode, seed: 7);

    _playTo(engine, 60);
    expect(mode.announcement, contains('New colour'));

    // The next move, whatever it does, is not the same announcement again.
    final next = engine.hint();
    if (next != null) engine.applyMove(next.a, next.b);
    if (mode.kindsUnlocked < 2) expect(mode.announcement, isNull);
  });

  test('the seventh colour actually reaches the board', () {
    final mode = _quick();
    final engine = GameEngine(mode: mode, seed: 7);

    _playTo(engine, 60);
    expect(mode.activeKindCount, 7);

    // Refills draw from the widened palette, so the new kind turns up once
    // enough tiles have been replaced.
    _playTo(engine, 4000);

    final kinds = {
      for (final pos in engine.board.positions)
        if (engine.board.at(pos) case final tile?) tile.kind,
    };
    expect(kinds, contains(6));
  });

  test('a widened palette survives a save and resume', () {
    final mode = _quick();
    final engine = GameEngine(mode: mode, seed: 7);
    _playTo(engine, 60);
    expect(mode.kindsUnlocked, greaterThanOrEqualTo(1));

    final resumed = GameEngine.restore(
      mode: _quick(),
      snapshot: RunSnapshot.fromJson(engine.snapshot().toJson()),
    );

    expect((resumed.mode as InfiniteHuntMode).activeKindCount, 7);
  });

  test('a fresh copy of the mode starts over at six', () {
    final mode = _quick();
    final engine = GameEngine(mode: mode, seed: 7);
    _playTo(engine, 60);

    final restarted = mode.fresh() as InfiniteHuntMode;

    expect(restarted.activeKindCount, 6);
    expect(restarted.pointsPerKind, 60);
  });
}
