import 'package:collect_three/engine/engine.dart';
// flutter_test exports its own MatchFinder (a widget finder); hide it so the
// engine's matcher keeps its domain name.
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;

void main() {
  group('BoardGenerator.generate', () {
    const grid = GridConfig(rows: 8, cols: 8, kindCount: 6);

    test('honours the board invariants across many seeds', () {
      for (var seed = 0; seed < 200; seed++) {
        final board = BoardGenerator.generate(
          grid: grid,
          rng: SeededRandom(seed),
          tiles: TileFactory(),
        );

        expect(
          MatchFinder.find(board).isEmpty,
          isTrue,
          reason: 'seed $seed started with a free match:\n${board.toSketch()}',
        );
        expect(
          MoveFinder.hasLegalMove(board),
          isTrue,
          reason: 'seed $seed started dead:\n${board.toSketch()}',
        );
        expect(board.isFull, isTrue, reason: 'seed $seed left holes');
      }
    });

    test('is reproducible from its seed', () {
      Board build() => BoardGenerator.generate(
        grid: grid,
        rng: SeededRandom(1234),
        tiles: TileFactory(),
      );

      expect(build(), equals(build()));
    });

    test('stays within the configured kind count', () {
      final board = BoardGenerator.generate(
        grid: const GridConfig(rows: 6, cols: 6, kindCount: 4),
        rng: SeededRandom(9),
        tiles: TileFactory(),
      );

      expect(board.tiles.every((t) => t.kind >= 0 && t.kind < 4), isTrue);
    });

    test('filledRows leaves the rest of the board empty', () {
      final board = BoardGenerator.generate(
        grid: const GridConfig(rows: 10, cols: 8, kindCount: 6),
        rng: SeededRandom(5),
        tiles: TileFactory(),
        filledRows: 5,
      );

      expect(board.tileCount, 40);
      for (var row = 0; row < 5; row++) {
        for (var col = 0; col < 8; col++) {
          expect(board.atRc(row, col), isNull);
        }
      }
      expect(MatchFinder.find(board).isEmpty, isTrue);
      expect(MoveFinder.hasLegalMove(board), isTrue);
    });
  });

  group('BoardGenerator.generateBalanced', () {
    const grid = GridConfig(rows: 6, cols: 6, kindCount: 4);

    test('gives every kind a count divisible by three', () {
      for (var seed = 0; seed < 50; seed++) {
        final board = BoardGenerator.generateBalanced(
          grid: grid,
          rng: SeededRandom(seed),
          tiles: TileFactory(),
        );

        final counts = <int, int>{};
        for (final tile in board.tiles) {
          counts[tile.kind] = (counts[tile.kind] ?? 0) + 1;
        }
        for (final entry in counts.entries) {
          expect(
            entry.value % 3,
            0,
            reason:
                'seed $seed: kind ${entry.key} appears ${entry.value} times',
          );
        }
        expect(MatchFinder.find(board).isEmpty, isTrue, reason: 'seed $seed');
        expect(MoveFinder.hasLegalMove(board), isTrue, reason: 'seed $seed');
      }
    });

    test('leaves no tile floating above a hole', () {
      final board = BoardGenerator.generateBalanced(
        grid: grid,
        rng: SeededRandom(11),
        tiles: TileFactory(),
      );

      expect(GravityRule.down.apply(board).movedAnything, isFalse);
    });

    test('rounds an odd tile count down to a multiple of three', () {
      final board = BoardGenerator.generateBalanced(
        grid: grid,
        rng: SeededRandom(3),
        tiles: TileFactory(),
        tileCount: 20,
      );

      expect(board.tileCount, 18);
    });
  });
}
