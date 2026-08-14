import 'package:collect_three/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;

/// A mode that plays a fixed layout with powers on, so the engine can be driven
/// over a board we designed rather than a generated one.
class _Bench extends GameMode {
  const _Bench(this.sketch, {this.powers = const {}});

  final String sketch;
  final Map<Pos, TilePower> powers;

  @override
  String get id => 'bench';
  @override
  String get name => 'Bench';
  @override
  String get tagline => 'test fixture';
  @override
  GridConfig get grid => const GridConfig(rows: 3, cols: 5, kindCount: 3);
  @override
  GravityRule get gravity => GravityRule.down;
  @override
  RefillRule get refill => RefillRule.none;
  @override
  bool get allowsSpecials => true;

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) {
    var board = Board.parse(sketch, tiles: tiles);
    powers.forEach((pos, power) {
      board = board.withTile(pos, board.at(pos)!.withPower(power));
    });
    return board;
  }

  @override
  ModeEvaluation evaluate(ModeContext ctx) => const ModeEvaluation.playing();

  @override
  GameMode fresh() => this;
}

Resolver _resolver({bool specials = true}) => Resolver(
  gravity: GravityRule.down,
  refill: RefillRule.none,
  kindCount: 3,
  allowsSpecials: specials,
);

void main() {
  group('the resolver', () {
    test('keeps the tile that earned a power and clears the rest', () {
      final outcome = _resolver().resolve(
        board: Board.parse('11112\n20200\n02020'),
        rng: SeededRandom(1),
        tiles: TileFactory(100),
        origin: const Pos(0, 3),
      );

      final survivor = outcome.board.at(const Pos(0, 3));
      expect(survivor, isNotNull, reason: 'the power must stay on the board');
      expect(survivor!.power, TilePower.clearRow);
      expect(outcome.specialsCreated, 1);
      expect(outcome.board.at(const Pos(0, 0)), isNull);
      expect(
        outcome.score,
        80,
        reason: 'the line of four, nothing blasted yet',
      );
    });

    test('creates nothing when the mode has powers switched off', () {
      final outcome = _resolver(specials: false).resolve(
        board: Board.parse('11112\n20200\n02020'),
        rng: SeededRandom(1),
        tiles: TileFactory(100),
        origin: const Pos(0, 3),
      );

      expect(outcome.specialsCreated, 0);
      expect(outcome.board.at(const Pos(0, 3)), isNull, reason: 'all four go');
      expect(outcome.board.tiles.every((t) => !t.isSpecial), isTrue);
      expect(outcome.score, 80);
    });

    test('pays more for tiles taken out by a blast', () {
      var board = Board.parse('01201\n12012\n20120');
      board = board.withTile(
        const Pos(1, 2),
        board.at(const Pos(1, 2))!.withPower(TilePower.clearRow),
      );

      final outcome = _resolver().resolve(
        board: board,
        rng: SeededRandom(1),
        tiles: TileFactory(100),
        primed: {const Pos(1, 2)},
      );

      expect(outcome.specialsFired, 1);
      // Five tiles in the row at 20 each, with no line score involved.
      expect(outcome.score, greaterThanOrEqualTo(100));
      for (var col = 0; col < 5; col++) {
        expect(
          outcome.board.atRc(2, col),
          isNotNull,
          reason: 'bottom survives',
        );
      }
    });
  });

  group('the engine', () {
    test('a colour bomb fires when swapped, with no line involved', () {
      final engine = GameEngine(
        mode: _Bench(
          '01201\n12012\n20120',
          powers: {Pos(0, 0): TilePower.colourBomb},
        ),
        seed: 1,
      );

      final result = engine.applyMove(const Pos(0, 0), const Pos(0, 1));

      expect(result.accepted, isTrue, reason: 'legal despite forming no line');
      expect(result.specialsFired, 1);
      expect(
        engine.board.tiles.any((t) => t.kind == 1),
        isFalse,
        reason: 'every tile of the kind it touched is gone',
      );
      expect(engine.movesMade, 1);
    });

    test('swapping two powers sets off both', () {
      final engine = GameEngine(
        mode: _Bench(
          '01201\n12012\n20120',
          powers: {
            Pos(1, 0): TilePower.clearRow,
            Pos(1, 1): TilePower.clearColumn,
          },
        ),
        seed: 1,
      );

      final result = engine.applyMove(const Pos(1, 0), const Pos(1, 1));

      expect(result.accepted, isTrue);
      expect(result.specialsFired, 2);
      expect(result.tilesCleared, greaterThan(5));
    });

    test('a swap that only moves a plain tile still needs a line', () {
      final engine = GameEngine(
        mode: _Bench(
          '01201\n12012\n20120',
          powers: {Pos(1, 0): TilePower.clearRow},
        ),
        seed: 1,
      );

      // Row clears do not go off on contact — only colour bombs do.
      final result = engine.applyMove(const Pos(1, 0), const Pos(0, 0));

      expect(result.accepted, isFalse);
      expect(result.rejection, MoveRejection.noMatch);
    });

    test('a colour bomb keeps a dead board alive', () {
      // kind = (row + col) % 3 has no legal swap at all.
      const dead = '0120\n1201\n2012\n0120';
      final plain = Board.parse(dead);
      expect(MoveFinder.hasLegalMove(plain), isFalse);

      final withBomb = plain.withTile(
        const Pos(0, 0),
        plain.at(const Pos(0, 0))!.withPower(TilePower.colourBomb),
      );

      expect(MoveFinder.hasLegalMove(withBomb, specials: true), isTrue);
      expect(
        MoveFinder.hasLegalMove(withBomb),
        isFalse,
        reason: 'modes without powers must not see that move',
      );
    });
  });

  group('Clear the Board is unaffected', () {
    test('the mode keeps powers switched off', () {
      expect(const ClearBoardMode().allowsSpecials, isFalse);
      expect(const InfiniteHuntMode().allowsSpecials, isTrue);
      expect(RisingTideMode().allowsSpecials, isTrue);
    });

    test('a level never grows a power, even on a four-line', () {
      // Four in a row would earn a power in any other mode.
      final engine = GameEngine(
        mode: const ClearBoardMode(
          grid: GridConfig(rows: 3, cols: 5, kindCount: 3),
          layoutSketch: '11112\n20200\n02020',
        ),
        seed: 1,
      );

      expect(engine.board.tiles.every((t) => !t.isSpecial), isTrue);
      expect(
        engine.legalMoves.length,
        MoveFinder.legalMoves(engine.board).length,
        reason: 'no extra colour-bomb moves appear',
      );
    });
  });
}
