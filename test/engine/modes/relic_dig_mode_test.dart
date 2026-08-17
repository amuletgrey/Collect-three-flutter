import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

RelicDigMode _mode({int relicCount = 3, int rows = 8, int cols = 8}) =>
    RelicDigMode(
      grid: GridConfig(rows: rows, cols: cols, kindCount: 6),
      relicCount: relicCount,
    );

List<Pos> _relicsOn(Board board) => [
  for (final pos in board.positions)
    if (board.at(pos)?.isRelic ?? false) pos,
];

/// Plays the deepest available move.
///
/// `hint()` returns the top-most legal move, which in this mode is precisely
/// the wrong idea — clearing high just refills from the top and the cargo never
/// sinks. Digging from underneath is the strategy the mode is built around, so
/// that is what the tests play.
Move? _dig(GameEngine engine) {
  final moves = engine.legalMoves;
  if (moves.isEmpty) return null;
  int depth(Move m) => m.a.row > m.b.row ? m.a.row : m.b.row;
  moves.sort((a, b) => depth(b).compareTo(depth(a)));
  return moves.first;
}

int _playUntilDelivered(GameEngine engine, RelicDigMode mode, {int cap = 300}) {
  var moves = 0;
  while (!engine.isOver && mode.delivered == 0 && moves < cap) {
    final move = _dig(engine);
    if (move == null) break;
    engine.applyMove(move.a, move.b);
    moves++;
  }
  return moves;
}

/// Two relics stacked in column 0, with a match waiting on the bottom row
/// underneath them. Clearing it drops the lower relic onto the delivery row and
/// leaves the second one directly above.
const _stacked = '1201\n2012\n0120\n0201\n0012';

class _Stacked extends RelicDigMode {
  _Stacked()
    : super(
        grid: const GridConfig(rows: 5, cols: 4, kindCount: 3),
        relicCount: 2,
      );

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) {
    var board = Board.parse(_stacked, tiles: tiles);
    for (final at in const [Pos(2, 0), Pos(3, 0)]) {
      board = board.withTile(at, board.at(at)!.asRelic());
    }
    return board;
  }
}

void main() {
  group('a stack of cargo', () {
    test('delivers every relic that reaches the floor, not just the first', () {
      final mode = _Stacked();
      final engine = GameEngine(mode: mode, seed: 1);
      expect(_relicsOn(engine.board), hasLength(2));

      // Clears the bottom row under the stack.
      final result = engine.applyMove(const Pos(4, 2), const Pos(3, 2));

      expect(result.accepted, isTrue);
      expect(
        mode.delivered,
        2,
        reason: 'the second relic landed on the floor in the same move',
      );
      expect(_relicsOn(engine.board), isEmpty);
    });

    test('and pays for both, in two announced deliveries', () {
      final mode = _Stacked();
      final engine = GameEngine(mode: mode, seed: 1);

      final result = engine.applyMove(const Pos(4, 2), const Pos(3, 2));

      final deliveries = result.events
          .whereType<TilesCleared>()
          .where((event) => event.cause == ClearCause.delivered)
          .toList();
      expect(deliveries, hasLength(2), reason: 'each arrival is its own event');
      expect(
        engine.score,
        greaterThanOrEqualTo(2 * RelicDigMode.deliveryBonus),
      );
    });

    test('the run is won as soon as the last one is out', () {
      final mode = _Stacked();
      final engine = GameEngine(mode: mode, seed: 1);

      engine.applyMove(const Pos(4, 2), const Pos(3, 2));

      expect(mode.remaining, 0);
      expect(engine.status, GameStatus.won);
      expect(engine.endReason, GameEndReason.relicsDelivered);
    });
  });

  group('the dig starts', () {
    test('with the relics buried near the top, in separate columns', () {
      final mode = _mode();
      final engine = GameEngine(mode: mode, seed: 5);
      final relics = _relicsOn(engine.board);

      expect(relics, hasLength(3));
      expect(relics.every((p) => p.row < 2), isTrue, reason: 'buried up high');
      expect(
        relics.map((p) => p.col).toSet(),
        hasLength(3),
        reason: 'one shaft each',
      );
      expect(engine.status, GameStatus.playing);
      expect(mode.remaining, 3);
    });

    test('with a board that is otherwise ordinary', () {
      final engine = GameEngine(mode: _mode(), seed: 9);

      expect(MatchFinder.find(engine.board).isEmpty, isTrue);
      expect(MoveFinder.hasLegalMove(engine.board, specials: true), isTrue);
      expect(engine.board.isFull, isTrue);
    });
  });

  group('cargo behaves like cargo', () {
    test('a relic never counts towards a line', () {
      var board = Board.parse('111\n202\n020');
      // Turn the middle of the three into cargo: the line must stop existing.
      expect(MatchFinder.find(board).isNotEmpty, isTrue);
      board = board.withTile(
        const Pos(0, 1),
        board.at(const Pos(0, 1))!.asRelic(),
      );

      expect(MatchFinder.find(board).isEmpty, isTrue);
      expect(board.kindAt(const Pos(0, 1)), isNull);
    });

    test('a relic cannot be swapped, even into a match', () {
      var board = Board.parse('1102\n2210\n0021');
      board = board.withTile(
        const Pos(0, 2),
        board.at(const Pos(0, 2))!.asRelic(),
      );

      expect(
        MoveFinder.createsMatch(board, const Pos(0, 2), const Pos(1, 2)),
        isFalse,
      );
      expect(
        MoveFinder.legalMoves(
          board,
        ).every((m) => !(board.at(m.a)!.isRelic || board.at(m.b)!.isRelic)),
        isTrue,
      );
    });

    test('a blast sweeps around a relic rather than through it', () {
      var board = Board.parse('01201\n12012\n20120');
      board = board
          .withTile(
            const Pos(1, 0),
            board.at(const Pos(1, 0))!.withPower(TilePower.clearRow),
          )
          .withTile(const Pos(1, 3), board.at(const Pos(1, 3))!.asRelic());

      const resolver = Resolver(
        gravity: GravityRule.down,
        refill: RefillRule.none,
        kindCount: 3,
        allowsSpecials: true,
      );
      final outcome = resolver.resolve(
        board: board,
        rng: SeededRandom(1),
        tiles: TileFactory(100),
        primed: {const Pos(1, 0)},
      );

      expect(
        outcome.board.tiles.where((t) => t.isRelic),
        hasLength(1),
        reason: 'the row clear must not take the cargo with it',
      );
    });

    test('a relic sinks as the tiles under it go', () {
      final mode = _mode(relicCount: 1);
      final engine = GameEngine(mode: mode, seed: 3);
      final startRow = _relicsOn(engine.board).single.row;

      var moves = 0;
      while (!engine.isOver && moves < 40 && mode.delivered == 0) {
        final move = _dig(engine);
        if (move == null) break;
        engine.applyMove(move.a, move.b);
        moves++;
      }

      final relics = _relicsOn(engine.board);
      final sank =
          mode.delivered > 0 ||
          (relics.isNotEmpty && relics.single.row > startRow);
      expect(sank, isTrue, reason: 'cargo should sink as you dig under it');
    });

    test('digging beats clearing greedily from the top', () {
      // The same board, played two ways. This is the mode's whole thesis.
      RelicDigMode play({required bool dig}) {
        final mode = _mode(relicCount: 1);
        final engine = GameEngine(mode: mode, seed: 12);
        var moves = 0;
        while (!engine.isOver && moves < 120 && mode.delivered == 0) {
          final move = dig ? _dig(engine) : engine.hint();
          if (move == null) break;
          engine.applyMove(move.a, move.b);
          moves++;
        }
        return mode;
      }

      expect(play(dig: true).delivered, 1);
      expect(
        play(dig: false).delivered,
        0,
        reason: 'clearing from the top never uncovers the cargo',
      );
    });
  });

  group('delivery', () {
    test('a relic on the bottom row is collected and paid for', () {
      final mode = _mode(relicCount: 1);
      final engine = GameEngine(mode: mode, seed: 12);

      _playUntilDelivered(engine, mode);

      expect(mode.delivered, 1, reason: 'a single relic should get out');
      expect(engine.status, GameStatus.won);
      expect(engine.endReason, GameEndReason.relicsDelivered);
      expect(
        engine.score,
        greaterThanOrEqualTo(RelicDigMode.deliveryBonus),
        reason: 'the bonus dwarfs the matching',
      );
      expect(_relicsOn(engine.board), isEmpty);
    });

    test('the board refills the hole the cargo left', () {
      final mode = _mode(relicCount: 1);
      final engine = GameEngine(mode: mode, seed: 12);

      _playUntilDelivered(engine, mode);

      expect(engine.board.isFull, isTrue);
      expect(MatchFinder.find(engine.board).isEmpty, isTrue);
    });
  });

  test('progress survives a save and resume', () {
    final mode = _mode(relicCount: 3);
    final engine = GameEngine(mode: mode, seed: 21);
    for (var i = 0; i < 12 && !engine.isOver; i++) {
      final move = _dig(engine);
      if (move == null) break;
      engine.applyMove(move.a, move.b);
    }

    final resumedMode = _mode(relicCount: 3);
    final resumed = GameEngine.restore(
      mode: resumedMode,
      snapshot: engine.snapshot(),
    );

    expect(resumedMode.delivered, mode.delivered);
    expect(resumed.board, engine.board);
    expect(
      _relicsOn(resumed.board),
      _relicsOn(engine.board),
      reason: 'cargo must survive the round trip',
    );
  });

  test('a finished dig invites another one', () {
    // The results screen asks the mode what to call the go-again button, so a
    // dig offers more digging rather than a "replay" of a run that has no
    // levels to replay.
    expect(RelicDigMode().replayLabel, 'Dig more');
    expect(InfiniteHuntMode().replayLabel, 'Replay');
  });

  test('the mode is registered and reachable by id', () {
    expect(ModeRegistry.ids, contains(ModeRegistry.relicDigId));
    expect(ModeRegistry.create(ModeRegistry.relicDigId), isA<RelicDigMode>());
    // Counted against the registry rather than a literal, so adding a mode is
    // one edit rather than two.
    expect(ModeRegistry.createAll(), hasLength(ModeRegistry.ids.length));
  });
}
