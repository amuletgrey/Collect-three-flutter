import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

GameEngine _engine({int seed = 5, int interval = 3, int cap = 15}) =>
    GameEngine(
      mode: CreepingRotMode(baseInterval: interval, rotCapacity: cap),
      seed: seed,
    );

CreepingRotMode _mode(GameEngine engine) => engine.mode as CreepingRotMode;

/// Plays whatever is legal. Peeking is free, so the hint budget is untouched.
void _play(GameEngine engine, {int moves = 30}) {
  for (var i = 0; i < moves && !engine.isOver; i++) {
    final move = engine.hint();
    if (move == null) return;
    engine.applyMove(move.a, move.b);
  }
}

int _rot(GameEngine engine) => _mode(engine).rotOn(engine.board);

/// Swapping (0,0) with (0,1) lines up three 0s down column 0, clearing rows
/// 0-2 of that column. The spread interval is switched off so nothing else
/// moves while the burn rule is under the microscope.
const _layout = '1002\n0121\n0210\n2101';

/// Directly under the bottom of that line.
const _rotCell = Pos(3, 0);

/// Far from it, in the opposite corner.
const _farCell = Pos(3, 3);

class _Planted extends CreepingRotMode {
  _Planted({this.where = _rotCell})
    : super(
        grid: const GridConfig(rows: 4, cols: 4, kindCount: 3),
        baseInterval: 99,
      );

  final Pos where;

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) {
    final board = Board.parse(_layout, tiles: tiles);
    return board.withTile(where, board.at(where)!.asRot());
  }
}

class _Distant extends _Planted {
  _Distant() : super(where: _farCell);
}

void main() {
  test('a board starts clean', () {
    final engine = _engine();

    expect(_rot(engine), 0);
    expect(_mode(engine).spreads, 0);
    expect(_mode(engine).movesUntilSpread, 3);
  });

  test('rot arrives once the interval is up', () {
    final engine = _engine(interval: 2);

    _play(engine, moves: 2);

    expect(_mode(engine).spreads, greaterThanOrEqualTo(1));
  });

  test('rot never matches and cannot be swapped', () {
    final engine = _engine(interval: 1);
    _play(engine, moves: 4);

    final rotted = [
      for (final pos in engine.board.positions)
        if (engine.board.at(pos)?.isRot ?? false) pos,
    ];
    expect(rotted, isNotEmpty, reason: 'nothing rotted, nothing to check');

    for (final pos in rotted) {
      expect(engine.board.kindAt(pos), isNull, reason: 'rot has no colour');
      for (final neighbour in pos.neighbours) {
        if (!engine.board.contains(neighbour)) continue;
        expect(
          MoveFinder.createsMatch(engine.board, pos, neighbour, specials: true),
          isFalse,
          reason: 'rot at $pos was swappable',
        );
      }
    }
  });

  test('clearing beside rot burns it off and pays for it', () {
    final mode = _Planted();
    final engine = GameEngine(mode: mode, seed: 1);
    expect(engine.board.at(_rotCell)!.isRot, isTrue);

    // Swapping these two drops a vertical line of three down column 0, the
    // bottom of which sits directly on top of the rot.
    final result = engine.applyMove(const Pos(0, 0), const Pos(0, 1));

    expect(result.accepted, isTrue);
    expect(mode.burned, 1);
    expect(mode.rotOn(engine.board), 0, reason: 'the rot should be gone');
    expect(
      result.events.whereType<TilesCleared>().any(
        (event) => event.cause == ClearCause.burned,
      ),
      isTrue,
      reason: 'the burn should be in the event list, so the board can play it',
    );
    expect(engine.score, greaterThan(CreepingRotMode.burnBonus));
  });

  test('a clear nowhere near the rot leaves it alone', () {
    final mode = _Distant();
    final engine = GameEngine(mode: mode, seed: 1);
    expect(mode.rotOn(engine.board), 1);

    engine.applyMove(const Pos(0, 0), const Pos(0, 1));

    expect(mode.burned, 0);
    expect(mode.rotOn(engine.board), 1);
  });

  test('too much rot ends the run', () {
    // A cap of one tile: the first spread is fatal.
    final engine = _engine(interval: 1, cap: 1);

    _play(engine, moves: 8);

    expect(engine.isOver, isTrue);
    expect(engine.endReason, GameEndReason.overrun);
  });

  test('the spread interval tightens as the run goes on', () {
    final mode = CreepingRotMode(
      baseInterval: 4,
      minInterval: 2,
      spreadsPerSpeedUp: 5,
    );

    expect(mode.intervalForSpreads(0), 4);
    expect(mode.intervalForSpreads(4), 4);
    expect(mode.intervalForSpreads(5), 3);
    expect(mode.intervalForSpreads(10), 2);
    // And never below the floor, whatever happens.
    expect(mode.intervalForSpreads(500), 2);
  });

  test('and it starts taking more than one tile at a time', () {
    final mode = CreepingRotMode(tilesPerSpeedUp: 8, maxSpreadSize: 3);

    expect(mode.spreadSizeForSpreads(0), 1);
    expect(mode.spreadSizeForSpreads(7), 1);
    expect(mode.spreadSizeForSpreads(8), 2);
    expect(mode.spreadSizeForSpreads(16), 3);
    // Capped, or a late run would turn the board over in one move.
    expect(mode.spreadSizeForSpreads(400), 3);
  });

  test('rot a blast destroyed is counted and paid for', () {
    // The resolver takes it with the blast, so the mode never sees it on the
    // board — it learns about it from the move summary. See
    // test/engine/resolution/inert_roles_test.dart for the blast rule itself.
    final mode = CreepingRotMode();
    mode.restoreState({'burned': 0});

    final outcome = mode.afterMove(
      ModeContext(
        board: Board.parse(_layout),
        score: 0,
        movesMade: 1,
        rng: SeededRandom(1),
        tiles: TileFactory(50),
        resolver: const Resolver(
          gravity: GravityRule.down,
          refill: RefillRule.fromTop,
          kindCount: 3,
          allowsSpecials: true,
        ),
        move: const MoveSummary(
          tilesCleared: 4,
          clearedByKind: {},
          clearedCells: {},
          cascadeCount: 1,
          longestLine: 3,
          blastCleared: 4,
          rotCleared: 2,
          specialsFired: 1,
          specialsCreated: 0,
        ),
      ),
    );

    expect(mode.burned, 2);
    expect(
      outcome.scoreDelta,
      greaterThanOrEqualTo(2 * CreepingRotMode.burnBonus),
    );
  });

  test('the cap is a count of tiles, which is what the meter shows', () {
    // It used to be a share of the board, which read fine in code and lied on
    // screen: at forty per cent the meter counted to twenty-five while half of
    // all runs strangled themselves around a dozen.
    expect(CreepingRotMode().rotCapacity, 15);
    expect(CreepingRotMode(rotCapacity: 9).rotCapacity, 9);
  });

  test('a run can end either way, and both are the rot doing it', () {
    // Rot is inert, so a board short of the cap can still have no move left.
    // Both endings are real; neither is a bug.
    final engine = _engine(interval: 1);
    _play(engine, moves: 400);

    expect(engine.isOver, isTrue);
    expect(
      engine.endReason,
      anyOf(GameEndReason.overrun, GameEndReason.noMovesLeft),
    );
  });

  test('rot survives a save and resume, tile roles and counters alike', () {
    final engine = _engine(interval: 1);
    _play(engine, moves: 5);
    final rotBefore = _rot(engine);
    expect(rotBefore, greaterThan(0));

    final resumed = GameEngine.restore(
      mode: CreepingRotMode(baseInterval: 1),
      snapshot: RunSnapshot.fromJson(engine.snapshot().toJson()),
    );

    expect(_rot(resumed), rotBefore);
    expect(_mode(resumed).spreads, _mode(engine).spreads);
    expect(_mode(resumed).burned, _mode(engine).burned);
  });

  test('a fresh copy starts the rot over', () {
    final mode = CreepingRotMode(baseInterval: 2);
    final engine = GameEngine(mode: mode, seed: 4);
    _play(engine, moves: 6);

    final restarted = mode.fresh() as CreepingRotMode;

    expect(restarted.spreads, 0);
    expect(restarted.burned, 0);
    expect(restarted.baseInterval, 2);
  });

  test('the mode is registered and reachable by id', () {
    expect(ModeRegistry.ids, contains(ModeRegistry.creepingRotId));
    expect(
      ModeRegistry.create(ModeRegistry.creepingRotId),
      isA<CreepingRotMode>(),
    );
  });
}
