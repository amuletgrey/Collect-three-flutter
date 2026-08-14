import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

void main() {
  const solver = ClearBoardSolver();

  test('solves a layout that can be emptied', () {
    // Six 1s and three 0s: two moves clear the lot.
    final outcome = solver.solve(Board.parse('110\n011\n101'));

    expect(outcome.solved, isTrue);
    expect(outcome.moves, hasLength(2));
    expect(outcome.budgetExhausted, isFalse);
  });

  test('the reported solution actually clears the board when replayed', () {
    final level = Board.parse('110\n011\n101');
    final outcome = solver.solve(level);

    final engine = GameEngine(
      mode: ClearBoardMode(
        grid: const GridConfig(rows: 3, cols: 3, kindCount: 3),
        layoutSketch: level.toSketch(),
      ),
      seed: 1,
    );
    for (final move in outcome.moves) {
      expect(
        engine.applyMove(move.a, move.b).accepted,
        isTrue,
        reason: 'solver proposed an illegal move: $move',
      );
    }

    expect(engine.board.isEmpty, isTrue);
    expect(engine.status, GameStatus.won);
  });

  test('reports failure on a board with no moves at all', () {
    final outcome = solver.solve(Board.parse('012\n120\n201'));

    expect(outcome.solved, isFalse);
    expect(outcome.moves, isEmpty);
    expect(outcome.budgetExhausted, isFalse, reason: 'it ran out of moves');
  });

  test('a layout whose counts cannot divide into threes is unsolvable', () {
    // Four 1s and five 0s — no sequence of triples empties that.
    final outcome = solver.solve(Board.parse('110\n010\n001'));

    expect(outcome.solved, isFalse);
  });

  test('stops at the node budget instead of running forever', () {
    const tiny = ClearBoardSolver(nodeBudget: 5);
    final outcome = tiny.solve(
      BoardGenerator.generateBalanced(
        grid: const GridConfig(rows: 7, cols: 6, kindCount: 4),
        rng: SeededRandom(99),
        tiles: TileFactory(),
      ),
    );

    expect(outcome.nodesVisited, lessThanOrEqualTo(5));
    if (!outcome.solved) expect(outcome.budgetExhausted, isTrue);
  });

  test('is deterministic', () {
    final board = BoardGenerator.generateBalanced(
      grid: const GridConfig(rows: 5, cols: 5, kindCount: 3),
      rng: SeededRandom(7),
      tiles: TileFactory(),
    );

    final first = solver.solve(board);
    final second = solver.solve(board);

    expect(first.solved, second.solved);
    expect(first.moveCount, second.moveCount);
    expect(first.nodesVisited, second.nodesVisited);
  });
}
