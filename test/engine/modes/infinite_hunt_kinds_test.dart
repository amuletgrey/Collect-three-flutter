import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

/// A palette that widens almost immediately, so a handful of moves is enough
/// to reach the second colour instead of the twelve thousand points a real run
/// needs.
InfiniteHuntMode _quick({int maxKinds = 9}) =>
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

  test('the shipped ramp is 6, then 7, 8 and 9 at 12k, 24k and 36k', () {
    final mode = InfiniteHuntMode();

    expect(mode.kindCountAt(0), 6);
    expect(mode.kindCountAt(11999), 6);
    expect(mode.kindCountAt(12000), 7);
    expect(mode.kindCountAt(23999), 7);
    expect(mode.kindCountAt(24000), 8);
    expect(mode.kindCountAt(36000), 9);
    // The ceiling holds however long the run goes on.
    expect(mode.kindCountAt(250000), 9);
  });

  test('the countdown points at the next colour, then stops', () {
    final mode = InfiniteHuntMode();

    expect(mode.pointsToNextKind(9000), 3000);

    mode.restoreState({'kindsUnlocked': 1});
    expect(mode.activeKindCount, 7);
    expect(mode.pointsToNextKind(12500), 11500);

    mode.restoreState({'kindsUnlocked': 3});
    expect(mode.activeKindCount, 9);
    expect(mode.pointsToNextKind(40000), isNull);
  });

  test('scoring past the threshold widens the palette', () {
    final mode = _quick();
    final engine = GameEngine(mode: mode, seed: 7);

    _playTo(engine, 60);

    expect(engine.score, greaterThanOrEqualTo(60));
    expect(mode.kindsUnlocked, greaterThanOrEqualTo(1));
    expect(mode.activeKindCount, 7);
  });

  test('the palette stops at the nine colours a skin can draw', () {
    final mode = _quick();
    final engine = GameEngine(mode: mode, seed: 11);

    _playTo(engine, 6000);

    expect(mode.activeKindCount, 9);
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

  test('the new colours actually reach the board', () {
    // Several seeds, because greedy play on a nine-colour board dies fast —
    // which is rather the point of the ramp. Fixed seeds keep it deterministic.
    final seen = <int>{};
    for (final seed in [7, 11, 13, 17, 23]) {
      final engine = GameEngine(mode: _quick(), seed: seed);
      for (var guard = 0; guard < 300 && !engine.isOver; guard++) {
        for (final pos in engine.board.positions) {
          if (engine.board.at(pos) case final tile?) seen.add(tile.kind);
        }
        final move = engine.hint();
        if (move == null) break;
        engine.applyMove(move.a, move.b);
      }
    }

    // Refills draw from the widened palette, so the new kinds turn up as tiles
    // are replaced — and nothing beyond the ninth ever does.
    expect(seen, containsAll(<int>[6, 7, 8]));
    expect(seen.every((kind) => kind < 9), isTrue);
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

    expect(
      (resumed.mode as InfiniteHuntMode).activeKindCount,
      mode.activeKindCount,
    );
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
