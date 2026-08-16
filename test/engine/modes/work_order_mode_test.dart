import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

GameEngine _engine({int budget = 25, int lines = 3, int seed = 5}) =>
    GameEngine(
      mode: WorkOrderMode(moveBudget: budget, lineCount: lines),
      seed: seed,
    );

WorkOrderMode _mode(GameEngine engine) => engine.mode as WorkOrderMode;

/// Plays whatever is legal until the run ends or [moves] have been made.
/// Peeking is free, so this leaves the hint budget alone.
void _play(GameEngine engine, {int moves = 100}) {
  for (var i = 0; i < moves && !engine.isOver; i++) {
    final move = engine.hint();
    if (move == null) return;
    engine.applyMove(move.a, move.b);
  }
}

void main() {
  test('an order is drawn at the start and shown as goals', () {
    final engine = _engine();

    expect(_mode(engine).order, hasLength(3));
    expect(engine.mode.goals, hasLength(3));
    expect(engine.mode.goals.every((goal) => goal.progress == 0), isTrue);
  });

  test('the same seed sets the same job', () {
    final a = _mode(_engine(seed: 42)).order;
    final b = _mode(_engine(seed: 42)).order;

    expect(a.map((line) => line.kind).toList(), b.map((l) => l.kind).toList());
    expect(a.map((line) => line.target).toList(), b.map((l) => l.target).toList());
    expect(
      a.map((line) => line.tileKind).toList(),
      b.map((line) => line.tileKind).toList(),
    );
  });

  test('no two collection lines ask for the same colour', () {
    for (var seed = 0; seed < 40; seed++) {
      final collects = _mode(_engine(seed: seed))
          .order
          .where((line) => line.kind == OrderKind.collect)
          .map((line) => line.tileKind)
          .toList();

      expect(
        collects.toSet(),
        hasLength(collects.length),
        reason: 'seed $seed asked for one colour twice',
      );
    }
  });

  test('collecting a colour moves its line along', () {
    final engine = _engine();
    final line = _mode(
      engine,
    ).order.firstWhere((line) => line.kind == OrderKind.collect);

    _play(engine, moves: 12);

    // Something of that colour has to have gone out over twelve moves.
    expect(line.progress, greaterThan(0));
    expect(line.progress, lessThanOrEqualTo(line.target));
  });

  test('a line stops at its target rather than overshooting', () {
    final line = OrderLine(kind: OrderKind.collect, target: 5)
      ..record(
        const MoveSummary(
          tilesCleared: 9,
          clearedByKind: {0: 9},
          clearedCells: {},
          cascadeCount: 1,
          longestLine: 3,
          blastCleared: 0,
          specialsFired: 0,
          specialsCreated: 0,
        ),
      );

    expect(line.progress, 5);
    expect(line.isDone, isTrue);
  });

  test('a chain line records the best chain, not the total', () {
    MoveSummary chain(int depth) => MoveSummary(
      tilesCleared: 3,
      clearedByKind: const {},
      clearedCells: const {},
      cascadeCount: depth,
      longestLine: 3,
      blastCleared: 0,
      specialsFired: 0,
      specialsCreated: 0,
    );
    final line = OrderLine(kind: OrderKind.cascade, target: 4)
      ..record(chain(2))
      ..record(chain(3))
      ..record(chain(1));

    expect(line.progress, 3, reason: 'three separate chains are not a chain');

    line.record(chain(4));
    expect(line.isDone, isTrue);
  });

  test('a blast line only counts what a power took', () {
    final line = OrderLine(kind: OrderKind.demolish, target: 10)
      ..record(
        const MoveSummary(
          tilesCleared: 14,
          clearedByKind: {},
          clearedCells: {},
          cascadeCount: 1,
          longestLine: 4,
          blastCleared: 6,
          specialsFired: 1,
          specialsCreated: 0,
        ),
      );

    expect(line.progress, 6, reason: 'the line of four is not demolition');
  });

  test('filling the order wins the run and pays for it', () {
    // One easy line, so a short run can actually finish it.
    final engine = GameEngine(
      mode: WorkOrderMode(lineCount: 1, moveBudget: 60),
      seed: 3,
    );
    _play(engine, moves: 60);

    if (_mode(engine).isFilled) {
      expect(engine.status, GameStatus.won);
      expect(engine.endReason, GameEndReason.orderFilled);
      expect(
        engine.score,
        greaterThan(WorkOrderMode.lineBonus),
        reason: 'the completion bonus should be in there',
      );
    } else {
      expect(engine.isOver, isTrue, reason: 'ran out of moves instead');
      expect(engine.endReason, GameEndReason.outOfMoves);
    }
  });

  test('running the budget out ends the run', () {
    final engine = _engine(budget: 4);

    _play(engine, moves: 10);

    expect(engine.movesMade, lessThanOrEqualTo(4));
    expect(engine.isOver, isTrue);
    expect(engine.endReason, GameEndReason.outOfMoves);
  });

  test('the budget is what the HUD counts down', () {
    final engine = _engine(budget: 6);

    expect(engine.movesRemaining, 6);
    _play(engine, moves: 2);

    expect(engine.movesRemaining, 6 - engine.movesMade);
  });

  test('the order and its progress survive a save and resume', () {
    final engine = _engine();
    _play(engine, moves: 6);
    final before = [
      for (final line in _mode(engine).order) (line.kind, line.progress),
    ];

    final resumed = GameEngine.restore(
      mode: WorkOrderMode(),
      snapshot: RunSnapshot.fromJson(engine.snapshot().toJson()),
    );

    expect(
      [for (final line in _mode(resumed).order) (line.kind, line.progress)],
      before,
    );
  });

  test('a fresh copy has no order until it deals a board', () {
    final mode = WorkOrderMode().fresh() as WorkOrderMode;

    expect(mode.order, isEmpty);
    expect(mode.isFilled, isFalse, reason: 'an empty list is not a win');
  });

  test('the mode is registered and reachable by id', () {
    expect(ModeRegistry.ids, contains(ModeRegistry.workOrderId));
    expect(
      ModeRegistry.create(ModeRegistry.workOrderId),
      isA<WorkOrderMode>(),
    );
  });
}
