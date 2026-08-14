import 'package:collect_three/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Board.parse', () {
    test('reads digits as kinds and dots as holes', () {
      final board = Board.parse('''
        012
        1.1
        201
      ''');

      expect(board.rows, 3);
      expect(board.cols, 3);
      expect(board.kindAt(const Pos(0, 0)), 0);
      expect(board.kindAt(const Pos(0, 2)), 2);
      expect(board.isEmptyAt(const Pos(1, 1)), isTrue);
      expect(board.tileCount, 8);
    });

    test('round-trips through toSketch', () {
      const sketch = '012\n1.1\n201';
      expect(Board.parse(sketch).toSketch(), sketch);
    });

    test('rejects ragged sketches', () {
      expect(() => Board.parse('012\n01'), throwsArgumentError);
    });

    test('assigns every tile a unique id', () {
      final board = Board.parse('012\n345\n012');
      final ids = board.tiles.map((t) => t.id).toSet();
      expect(ids.length, board.tileCount);
    });
  });

  group('mutation returns new boards', () {
    test('withSwap leaves the original untouched', () {
      final original = Board.parse('01\n23');
      final swapped = original.withSwap(const Pos(0, 0), const Pos(0, 1));

      expect(original.toSketch(), '01\n23');
      expect(swapped.toSketch(), '10\n23');
    });

    test('withCleared empties the given cells only', () {
      final board = Board.parse('012\n345');
      final cleared = board.withCleared([const Pos(0, 1), const Pos(1, 2)]);

      expect(cleared.toSketch(), '0.2\n34.');
      expect(cleared.tileCount, 4);
    });

    test('withTile rejects off-board positions', () {
      final board = Board.parse('01\n23');
      expect(() => board.withTile(const Pos(5, 5), null), throwsRangeError);
    });
  });

  test('positionOfTile finds a tile by id after it moves', () {
    final board = Board.parse('01\n23');
    final tile = board.at(const Pos(0, 0))!;
    final moved = board.withSwap(const Pos(0, 0), const Pos(1, 1));

    expect(moved.positionOfTile(tile.id), const Pos(1, 1));
    expect(moved.positionOfTile(999), isNull);
  });

  test('equality compares contents, not identity', () {
    expect(Board.parse('01\n23'), equals(Board.parse('01\n23')));
    expect(Board.parse('01\n23'), isNot(equals(Board.parse('01\n32'))));
  });

  group('Pos', () {
    test('adjacency is orthogonal only', () {
      expect(const Pos(1, 1).isAdjacentTo(const Pos(1, 2)), isTrue);
      expect(const Pos(1, 1).isAdjacentTo(const Pos(0, 1)), isTrue);
      expect(const Pos(1, 1).isAdjacentTo(const Pos(2, 2)), isFalse);
      expect(const Pos(1, 1).isAdjacentTo(const Pos(1, 1)), isFalse);
      expect(const Pos(1, 1).isAdjacentTo(const Pos(1, 3)), isFalse);
    });
  });

  test('Move equality ignores order', () {
    expect(
      const Move(Pos(0, 0), Pos(0, 1)),
      equals(const Move(Pos(0, 1), Pos(0, 0))),
    );
    expect(
      const Move(Pos(0, 0), Pos(0, 1)).hashCode,
      const Move(Pos(0, 1), Pos(0, 0)).hashCode,
    );
  });

  test('SeededRandom is reproducible and counts draws', () {
    final a = SeededRandom(42);
    final b = SeededRandom(42);
    final drawsA = List.generate(20, (_) => a.nextInt(100));
    final drawsB = List.generate(20, (_) => b.nextInt(100));

    expect(drawsA, drawsB);
    expect(a.drawCount, 20);
  });
}
