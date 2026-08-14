import 'package:collect_three/engine/engine.dart';
// flutter_test exports its own MatchFinder (a widget finder); hide it so the
// engine's matcher keeps its domain name.
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;

void main() {
  group('MatchFinder.find', () {
    test('finds nothing on a clean board', () {
      final result = MatchFinder.find(
        Board.parse('''
        0120
        1201
        2012
      '''),
      );

      expect(result.isEmpty, isTrue);
      expect(result.cells, isEmpty);
    });

    test('finds a horizontal triple', () {
      final result = MatchFinder.find(
        Board.parse('''
        0120
        1112
        2010
      '''),
      );

      expect(result.lines, hasLength(1));
      expect(result.lines.single.kind, 1);
      expect(result.lines.single.orientation, MatchOrientation.horizontal);
      expect(result.cells, {const Pos(1, 0), const Pos(1, 1), const Pos(1, 2)});
    });

    test('finds a vertical triple', () {
      final result = MatchFinder.find(
        Board.parse('''
        0120
        0211
        0102
        1021
      '''),
      );

      expect(result.lines, hasLength(1));
      expect(result.lines.single.orientation, MatchOrientation.vertical);
      expect(result.lines.single.length, 3);
    });

    test('a run of five is one line, not three', () {
      final result = MatchFinder.find(
        Board.parse('''
        11111
        20202
        01010
      '''),
      );

      expect(result.lines, hasLength(1));
      expect(result.lines.single.length, 5);
      expect(result.cells, hasLength(5));
      expect(result.longestLine, 5);
    });

    test('an L shape yields two lines sharing a corner', () {
      final result = MatchFinder.find(
        Board.parse('''
        1110
        1021
        1200
      '''),
      );

      expect(result.lines, hasLength(2));
      // Five distinct tiles, because the corner belongs to both lines.
      expect(result.cells, hasLength(5));
      expect(result.lines.map((l) => l.orientation).toSet(), {
        MatchOrientation.horizontal,
        MatchOrientation.vertical,
      });
    });

    test('empty cells never match', () {
      final result = MatchFinder.find(
        Board.parse('''
        ...
        ...
        012
      '''),
      );

      expect(result.isEmpty, isTrue);
    });

    test('runs that end at the board edge are still found', () {
      final result = MatchFinder.find(
        Board.parse('''
        0111
        1020
        2100
      '''),
      );

      expect(result.lines, hasLength(1));
      expect(result.lines.single.cells.last, const Pos(0, 3));
    });
  });

  group('MatchFinder.hasMatchThrough', () {
    final board = Board.parse('''
      0120
      1112
      2010
    ''');

    test('is true for a cell inside a run', () {
      expect(MatchFinder.hasMatchThrough(board, const Pos(1, 1)), isTrue);
    });

    test('is false for a cell outside every run', () {
      expect(MatchFinder.hasMatchThrough(board, const Pos(0, 0)), isFalse);
    });

    test('is false for a hole and for off-board cells', () {
      final holed = board.withCleared([const Pos(1, 1)]);
      expect(MatchFinder.hasMatchThrough(holed, const Pos(1, 1)), isFalse);
      expect(MatchFinder.hasMatchThrough(board, const Pos(9, 9)), isFalse);
    });
  });
}
