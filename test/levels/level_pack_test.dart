import 'package:collect_three/engine/engine.dart';
import 'package:collect_three/services/level_repository.dart';
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;

/// The promise Clear the Board makes is that every shipped level can actually
/// be cleared. This re-proves it for the whole pack, so a regenerated or
/// hand-edited pack can never ship a level that traps the player.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LevelPack pack;

  setUpAll(() async {
    pack = await LevelRepository().load();
  });

  test('the pack loads and is the advertised size', () {
    expect(pack.id, 'pack_01');
    expect(pack.levels, hasLength(30));
    expect(
      pack.levels.map((l) => l.number).toList(),
      List.generate(30, (i) => i + 1),
    );
  });

  test('every level starts clean and playable', () {
    for (final level in pack.levels) {
      final board = Board.parse(level.sketch);

      expect(
        MatchFinder.find(board).isEmpty,
        isTrue,
        reason: 'level ${level.number} starts with a free match',
      );
      expect(
        MoveFinder.hasLegalMove(board),
        isTrue,
        reason: 'level ${level.number} starts dead',
      );
      expect(
        board.tileCount % 3,
        0,
        reason: 'level ${level.number} cannot divide into triples',
      );
      expect(
        GravityRule.downThenLeft.apply(board).movedAnything,
        isFalse,
        reason: 'level ${level.number} has floating tiles',
      );
    }
  });

  test('every level is provably solvable, and par is that solution', () {
    const solver = ClearBoardSolver();

    for (final level in pack.levels) {
      final outcome = solver.solve(Board.parse(level.sketch));

      expect(
        outcome.solved,
        isTrue,
        reason: 'level ${level.number} could not be solved',
      );
      expect(
        outcome.moveCount,
        level.parMoves,
        reason: 'level ${level.number} par disagrees with the solver',
      );
    }
  });

  test('replaying a solution through the real engine wins the level', () {
    const solver = ClearBoardSolver();

    // Spot-check across the difficulty tiers rather than all 30, which would
    // just be the solver test again.
    for (final number in [1, 12, 30]) {
      final level = pack.byNumber(number);
      final engine = GameEngine(mode: ClearBoardMode.fromLevel(level), seed: 1);

      for (final move in solver.solve(Board.parse(level.sketch)).moves) {
        expect(
          engine.applyMove(move.a, move.b).accepted,
          isTrue,
          reason: 'level $number rejected a solver move',
        );
      }

      expect(engine.status, GameStatus.won, reason: 'level $number');
      expect(engine.movesMade, level.parMoves);
      expect(level.starsFor(engine.movesMade), 3);
    }
  });

  test('difficulty ramps across the pack', () {
    final first = pack.byNumber(1);
    final last = pack.byNumber(30);

    expect(last.tileCount, greaterThan(first.tileCount));
    expect(last.kindCount, greaterThanOrEqualTo(first.kindCount));
  });

  test('stars follow the par band', () {
    final level = pack.byNumber(1);

    expect(level.starsFor(level.parMoves), 3);
    expect(level.starsFor(level.parMoves + 1), 2);
    expect(level.starsFor(level.parMoves + 3), 2);
    expect(level.starsFor(level.parMoves + 4), 1);
  });

  test('levels round-trip through JSON', () {
    final restored = LevelPack.fromJson(pack.toJson());

    expect(restored.length, pack.length);
    expect(restored.byNumber(7).sketch, pack.byNumber(7).sketch);
    expect(restored.byNumber(7).parMoves, pack.byNumber(7).parMoves);
  });
}
