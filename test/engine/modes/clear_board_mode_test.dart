import 'package:collect_three/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Six 1s and three 0s: solvable in two moves, and small enough to reason
/// about by hand.
const _level = '''
110
011
101
''';

GameEngine _engine({
  String layout = _level,
  int? moveLimit,
  GridConfig grid = const GridConfig(rows: 3, cols: 3, kindCount: 3),
}) => GameEngine(
  mode: ClearBoardMode(grid: grid, layoutSketch: layout, moveLimit: moveLimit),
  seed: 1,
);

void main() {
  test('loads the level exactly as authored', () {
    final engine = _engine();

    expect(engine.board.toSketch(), '110\n011\n101');
    expect(engine.status, GameStatus.playing);
    expect(engine.undosRemaining, 3);
  });

  test('clearing the last tile wins the level', () {
    final engine = _engine();

    expect(
      engine.applyMove(const Pos(0, 2), const Pos(1, 2)).accepted,
      isTrue,
      reason: 'completing the top row',
    );
    expect(engine.board.isEmpty, isFalse);

    expect(
      engine.applyMove(const Pos(1, 1), const Pos(2, 1)).accepted,
      isTrue,
      reason: 'both remaining rows line up at once',
    );

    expect(engine.board.isEmpty, isTrue);
    expect(engine.status, GameStatus.won);
    expect(engine.endReason, GameEndReason.boardCleared);
  });

  test('no tiles are ever added back', () {
    final engine = _engine();
    final before = engine.board.tileCount;

    engine.applyMove(const Pos(0, 2), const Pos(1, 2));

    expect(engine.board.tileCount, lessThan(before));
    expect(
      engine.board.tiles.map((t) => t.id).toSet().length,
      engine.board.tileCount,
    );
  });

  test('undo restores the board, the score and the move count', () {
    final engine = _engine();
    final board = engine.board;

    engine.applyMove(const Pos(0, 2), const Pos(1, 2));
    expect(engine.score, greaterThan(0));

    expect(engine.undo(), isTrue);
    expect(engine.board, equals(board));
    expect(engine.score, 0);
    expect(engine.movesMade, 0);
    expect(engine.undosRemaining, 2);
  });

  test('undo stops when there is nothing left to take back', () {
    final engine = _engine();

    engine.applyMove(const Pos(0, 2), const Pos(1, 2));
    expect(engine.undo(), isTrue);
    expect(engine.undo(), isFalse);
    expect(engine.canUndo, isFalse);
  });

  test('a stranded board is a loss, not a stalemate', () {
    // Three kinds left, none of them adjacent enough to line up.
    final engine = _engine(layout: '012\n120\n201');

    expect(engine.status, GameStatus.lost);
    expect(engine.endReason, GameEndReason.noMovesLeft);
  });

  test('running out of moves loses the level', () {
    final engine = _engine(moveLimit: 1);

    engine.applyMove(const Pos(0, 2), const Pos(1, 2));

    expect(engine.status, GameStatus.lost);
    expect(engine.endReason, GameEndReason.outOfMoves);
    expect(engine.movesRemaining, 0);
  });

  test('emptying a column slides the rest left, which can start a chain', () {
    // Swapping (2,1) with (2,2) completes the middle column. Clearing it leaves
    // column 1 empty, columns 2 and 3 slide left, and the top row lands on a
    // second match it could not have made on its own.
    final engine = _engine(
      layout: '0100\n2110\n2012',
      grid: const GridConfig(rows: 3, cols: 4, kindCount: 3),
    );

    final result = engine.applyMove(const Pos(2, 1), const Pos(2, 2));

    expect(result.accepted, isTrue);
    expect(result.cascadeCount, 2, reason: 'the slide caused a second match');
    expect(result.tilesCleared, 6);
    expect(engine.score, 30 + 60);
    expect(engine.board.toSketch(), '....\n210.\n202.');
  });
}
