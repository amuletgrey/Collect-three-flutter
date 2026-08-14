import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/engine/engine.dart';

Resolver _resolver({
  GravityRule gravity = GravityRule.down,
  RefillRule refill = RefillRule.none,
  int kindCount = 4,
}) => Resolver(gravity: gravity, refill: refill, kindCount: kindCount);

void main() {
  test('a stable board resolves to nothing', () {
    final board = Board.parse('''
      012
      120
      201
    ''');
    final outcome = _resolver().resolve(
      board: board,
      rng: SeededRandom(1),
      tiles: TileFactory(100),
    );

    expect(outcome.clearedAnything, isFalse);
    expect(outcome.events, isEmpty);
    expect(outcome.board, board);
  });

  test('clears a line, settles the board, and scores it', () {
    final outcome = _resolver().resolve(
      board: Board.parse('''
        2..
        1..
        000
      '''),
      rng: SeededRandom(1),
      tiles: TileFactory(100),
    );

    expect(outcome.cascadeCount, 1);
    expect(outcome.tilesCleared, 3);
    expect(outcome.score, 30);
    expect(outcome.board.toSketch(), '...\n2..\n1..');

    expect(outcome.events, hasLength(2));
    final cleared = outcome.events.first as TilesCleared;
    expect(cleared.cascadeStep, 1);
    expect(cleared.multiplier, 1);
    expect(cleared.cells, hasLength(3));
    expect(outcome.events.last, isA<TilesMoved>());
  });

  test('chains: removing a blocker joins the tiles above and below it', () {
    // Clearing the row of 0s lets the two 1s on top drop onto the third one.
    final outcome = _resolver().resolve(
      board: Board.parse('''
        1..
        1..
        000
        1..
        2..
      '''),
      rng: SeededRandom(1),
      tiles: TileFactory(100),
    );

    expect(outcome.cascadeCount, 2);
    expect(outcome.tilesCleared, 6);
    // 30 at x1, then the chained triple at x2.
    expect(outcome.score, 30 + 60);
    expect(outcome.board.toSketch(), '...\n...\n...\n...\n2..');

    final clears = outcome.events.whereType<TilesCleared>().toList();
    expect(clears, hasLength(2));
    expect(clears[1].cascadeStep, 2);
    expect(clears[1].multiplier, 2);
  });

  test('an L shape scores both of its lines in one step', () {
    final outcome = _resolver().resolve(
      board: Board.parse('''
        1110
        1021
        1200
      '''),
      rng: SeededRandom(1),
      tiles: TileFactory(100),
    );

    final cleared = outcome.events.whereType<TilesCleared>().first;
    expect(cleared.lines, hasLength(2));
    expect(cleared.cells, hasLength(5));
    expect(cleared.scoreDelta, 60);
  });

  test('refilling from the top fills every hole', () {
    final outcome = _resolver(refill: RefillRule.fromTop).resolve(
      board: Board.parse('''
        213
        123
        000
      '''),
      rng: SeededRandom(7),
      tiles: TileFactory(100),
    );

    expect(outcome.board.isFull, isTrue);
    expect(outcome.board.tileCount, 9);
    expect(outcome.events.whereType<TilesSpawned>(), isNotEmpty);
  });

  test('spawned tiles enter from above the top edge', () {
    final outcome = _resolver(refill: RefillRule.fromTop, kindCount: 3).resolve(
      board: Board.parse('''
        213
        123
        000
      '''),
      rng: SeededRandom(3),
      tiles: TileFactory(100),
    );

    for (final spawn in outcome.events.whereType<TilesSpawned>().first.tiles) {
      expect(spawn.from.row, lessThan(0));
      expect(spawn.from.col, spawn.at.col);
      expect(spawn.tile.kind, lessThan(3));
    }
  });

  test('clear-the-board gravity slides emptied columns left', () {
    final outcome = _resolver(gravity: GravityRule.downThenLeft).resolve(
      board: Board.parse('''
        1.2
        1.2
        1.2
      '''),
      rng: SeededRandom(1),
      tiles: TileFactory(100),
    );

    // Both columns match at once and the board empties completely.
    expect(outcome.board.isEmpty, isTrue);
    expect(outcome.tilesCleared, 6);
  });

  test('tile ids survive a cascade', () {
    final board = Board.parse('''
      2..
      1..
      000
    ''');
    final survivor = board.at(const Pos(0, 0))!;
    final outcome = _resolver().resolve(
      board: board,
      rng: SeededRandom(1),
      tiles: TileFactory(100),
    );

    expect(outcome.board.positionOfTile(survivor.id), const Pos(1, 0));
  });
}
