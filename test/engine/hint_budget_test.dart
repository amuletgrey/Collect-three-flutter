import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

/// Clear the Board with a hint every few points, so one scoring move is enough
/// to cross a milestone. The layout has exactly one legal opening.
class _CheapHints extends ClearBoardMode {
  const _CheapHints()
    : super(
        grid: const GridConfig(rows: 3, cols: 4, kindCount: 3),
        layoutSketch: '1102\n2210\n0021',
      );

  @override
  int get pointsPerHint => 10;
}

const _opening = Move(Pos(0, 2), Pos(1, 2));

GameEngine _engine({GameMode mode = const _CheapHints()}) =>
    GameEngine(mode: mode, seed: 4);

void main() {
  test('a run opens on the mode allowance', () {
    expect(_engine().hintsRemaining, 3);
    expect(InfiniteHuntMode().startingHints, 3);
  });

  test('spending a hint costs one and returns a real move', () {
    final engine = _engine();

    final move = engine.useHint();

    expect(move, isNotNull);
    expect(engine.board.at(move!.a), isNotNull);
    expect(engine.hintsRemaining, 2);
  });

  test('an empty budget hands out nothing and never goes negative', () {
    final engine = _engine();
    for (var i = 0; i < 3; i++) {
      expect(engine.useHint(), isNotNull);
    }

    expect(engine.useHint(), isNull);
    expect(engine.hintsRemaining, 0);
  });

  test('peeking is free — it is what the solver and the tests use', () {
    final engine = _engine();

    engine.hint();
    engine.hint();

    expect(engine.hintsRemaining, 3);
  });

  test('scoring past the milestone earns one back', () {
    final engine = _engine()..useHint();
    expect(engine.hintsRemaining, 2);

    engine.applyMove(_opening.a, _opening.b);

    // 30 points for a line of three, against a 10-point milestone.
    expect(engine.score, greaterThanOrEqualTo(30));
    expect(engine.hintsJustEarned, greaterThanOrEqualTo(3));
    expect(engine.hintsRemaining, 2 + engine.hintsJustEarned);
  });

  test('a milestone already collected is not paid twice', () {
    final engine = _engine()..applyMove(_opening.a, _opening.b);
    final afterFirst = engine.hintsRemaining;

    // Whatever the second move does, it cannot re-award the first move's
    // milestones.
    final next = engine.hint();
    if (next != null) engine.applyMove(next.a, next.b);

    expect(engine.hintsRemaining, greaterThanOrEqualTo(afterFirst));
    expect(engine.hintsRemaining - afterFirst, engine.hintsJustEarned);
  });

  test('a refused swap earns nothing and announces nothing', () {
    final engine = _engine()..applyMove(_opening.a, _opening.b);

    engine.applyMove(const Pos(0, 0), const Pos(0, 1));

    expect(engine.hintsJustEarned, 0);
  });

  test('the countdown to the next hint shrinks as you score', () {
    final engine = _engine(mode: InfiniteHuntMode());
    expect(engine.pointsToNextHint, 1000);

    final move = engine.hint()!;
    engine.applyMove(move.a, move.b);

    expect(engine.pointsToNextHint, 1000 - engine.score);
  });

  test('a saved run resumes with the hints it had, not a fresh handful', () {
    final engine = _engine()..useHint();
    engine.useHint();
    final saved = engine.snapshot();
    expect(saved.hintsRemaining, 1);

    final resumed = GameEngine.restore(
      mode: const _CheapHints(),
      snapshot: RunSnapshot.fromJson(saved.toJson()),
    );

    expect(resumed.hintsRemaining, 1);
  });

  test('a resumed run does not collect milestones it already passed', () {
    final engine = _engine()..applyMove(_opening.a, _opening.b);
    final banked = engine.hintsRemaining;

    final resumed = GameEngine.restore(
      mode: const _CheapHints(),
      snapshot: RunSnapshot.fromJson(engine.snapshot().toJson()),
    );

    expect(resumed.hintsRemaining, banked);
  });

  test('a save from before hints existed resumes on the allowance', () {
    final json = _engine().snapshot().toJson()..remove('hints');

    final resumed = GameEngine.restore(
      mode: const _CheapHints(),
      snapshot: RunSnapshot.fromJson(json),
    );

    expect(resumed.hintsRemaining, 3);
  });
}
