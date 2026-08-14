// flutter_test exports its own MatchFinder (a widget finder); hide it so the
// engine's matcher keeps its domain name.
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

/// Two 1s sit at the top left with a third one directly below the gap, so
/// swapping (0,2) with (1,2) completes the row.
final _board = Board.parse('''
  1102
  2210
  0021
''');

void main() {
  group('MoveFinder.createsMatch', () {
    test('the board itself starts clean', () {
      expect(MatchFinder.find(_board).isEmpty, isTrue);
    });

    test('accepts a swap that forms a line', () {
      expect(
        MoveFinder.createsMatch(_board, const Pos(0, 2), const Pos(1, 2)),
        isTrue,
      );
    });

    test('rejects a swap that forms nothing', () {
      expect(
        MoveFinder.createsMatch(_board, const Pos(1, 0), const Pos(2, 0)),
        isFalse,
      );
    });

    test('rejects diagonal and distant pairs', () {
      expect(
        MoveFinder.createsMatch(_board, const Pos(0, 2), const Pos(1, 3)),
        isFalse,
      );
      expect(
        MoveFinder.createsMatch(_board, const Pos(0, 2), const Pos(2, 2)),
        isFalse,
      );
    });

    test('rejects swapping a tile into a hole', () {
      final holed = Board.parse('''
        110.
        2210
        0021
      ''');

      expect(
        MoveFinder.createsMatch(holed, const Pos(0, 2), const Pos(0, 3)),
        isFalse,
      );
    });

    test('rejects swapping two tiles of the same kind', () {
      expect(
        MoveFinder.createsMatch(_board, const Pos(0, 0), const Pos(0, 1)),
        isFalse,
      );
    });
  });

  group('legal move enumeration', () {
    test('reports each adjacent pair once, and only legal ones', () {
      final moves = MoveFinder.legalMoves(_board);

      expect(moves, isNotEmpty);
      expect(moves.toSet(), hasLength(moves.length));
      for (final move in moves) {
        expect(move.isAdjacent, isTrue);
        expect(MoveFinder.createsMatch(_board, move.a, move.b), isTrue);
      }
    });

    test('a dead board has no moves and no hint', () {
      // kind = (row + col) % 3 — no swap in this pattern can line up three.
      final dead = Board.parse('''
        0120
        1201
        2012
        0120
      ''');

      expect(MatchFinder.find(dead).isEmpty, isTrue);
      expect(MoveFinder.hasLegalMove(dead), isFalse);
      expect(MoveFinder.firstLegalMove(dead), isNull);
      expect(MoveFinder.legalMoves(dead), isEmpty);
    });

    test('the hint is always a legal move', () {
      final hint = MoveFinder.firstLegalMove(_board)!;

      expect(MoveFinder.createsMatch(_board, hint.a, hint.b), isTrue);
      expect(MoveFinder.legalMoves(_board), contains(hint));
    });
  });
}
