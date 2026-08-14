import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/engine/engine.dart';

void main() {
  group('GravityRule.down', () {
    test('drops tiles to the bottom of their column', () {
      final outcome = GravityRule.down.apply(
        Board.parse('''
        12.
        .3.
        4..
      '''),
      );

      expect(outcome.board.toSketch(), '...\n12.\n43.');
      expect(outcome.steps, hasLength(1));
      expect(outcome.steps.single, hasLength(3));
    });

    test('keeps tile identity while moving', () {
      final board = Board.parse('1.\n..\n..');
      final tile = board.at(const Pos(0, 0))!;
      final outcome = GravityRule.down.apply(board);

      expect(outcome.board.at(const Pos(2, 0))!.id, tile.id);
      expect(
        outcome.steps.single.single,
        TileMove(tile.id, const Pos(0, 0), const Pos(2, 0)),
      );
    });

    test('reports nothing when the board is already settled', () {
      final outcome = GravityRule.down.apply(Board.parse('..\n12'));

      expect(outcome.movedAnything, isFalse);
      expect(outcome.steps, isEmpty);
    });

    test('never moves a tile sideways', () {
      final outcome = GravityRule.down.apply(
        Board.parse('''
        1.2
        ...
        ...
      '''),
      );

      expect(outcome.board.toSketch(), '...\n...\n1.2');
    });
  });

  group('GravityRule.downThenLeft', () {
    test('slides columns left once a column empties out', () {
      final outcome = GravityRule.downThenLeft.apply(
        Board.parse('''
        1.2
        3.4
        5.6
      '''),
      );

      expect(outcome.board.toSketch(), '12.\n34.\n56.');
      // The fall produced nothing, so the slide is the only batch.
      expect(outcome.steps, hasLength(1));
      expect(outcome.steps.single, hasLength(3));
    });

    test('leaves partially filled columns where they are', () {
      final outcome = GravityRule.downThenLeft.apply(
        Board.parse('''
        1.2
        3.4
        556
      '''),
      );

      expect(outcome.board.toSketch(), '1.2\n3.4\n556');
      expect(outcome.movedAnything, isFalse);
    });

    test('falls first, then slides, as two separate batches', () {
      final outcome = GravityRule.downThenLeft.apply(
        Board.parse('''
        1.2
        ..4
        ..6
      '''),
      );

      // Column 0 settles to the bottom; column 1 is empty so column 2 slides in.
      expect(outcome.board.toSketch(), '.2.\n.4.\n16.');
      expect(outcome.steps, hasLength(2));
      expect(outcome.steps.first, hasLength(1));
      expect(outcome.steps.last, hasLength(3));
    });

    test('collapses several empty columns in order', () {
      final outcome = GravityRule.downThenLeft.apply(
        Board.parse('''
        .1.2
        .3.4
      '''),
      );

      expect(outcome.board.toSketch(), '12..\n34..');
    });
  });
}
