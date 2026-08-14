import 'dart:convert';

import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

void main() {
  group('the generator can be picked up mid-sequence', () {
    test('the same seed still gives the same sequence', () {
      final a = SeededRandom(42);
      final b = SeededRandom(42);

      expect(
        List.generate(20, (_) => a.nextInt(100)),
        List.generate(20, (_) => b.nextInt(100)),
      );
    });

    test('restoring the state continues rather than restarting', () {
      final original = SeededRandom(7);
      final firstTen = List.generate(10, (_) => original.nextInt(1000));

      final resumed = SeededRandom(
        7,
        state: original.state,
        drawCount: original.drawCount,
      );
      final continued = List.generate(10, (_) => resumed.nextInt(1000));
      final wouldHaveBeen = List.generate(10, (_) => original.nextInt(1000));

      expect(continued, wouldHaveBeen, reason: 'the stream carries on');
      expect(resumed.drawCount, 20);
      expect(continued, isNot(firstTen));
    });

    test('never gets stuck, whatever the seed', () {
      for (final seed in [0, 1, -1, 0xFFFFFFFF, 123456789]) {
        final rng = SeededRandom(seed);
        final draws = List.generate(50, (_) => rng.nextInt(6));
        expect(draws.toSet().length, greaterThan(1), reason: 'seed $seed');
      }
    });
  });

  group('a saved run', () {
    test('round-trips through JSON with tiles, powers and ids intact', () {
      final engine = GameEngine(
        mode: const InfiniteHuntMode(
          grid: GridConfig(rows: 5, cols: 5, kindCount: 5),
        ),
        seed: 99,
      );
      for (var i = 0; i < 5 && !engine.isOver; i++) {
        final hint = engine.hint()!;
        engine.applyMove(hint.a, hint.b);
      }

      final json = jsonEncode(engine.snapshot().toJson());
      final restored = RunSnapshot.fromJson(
        jsonDecode(json) as Map<String, Object?>,
      );

      expect(restored.toBoard(), engine.board);
      expect(restored.score, engine.score);
      expect(restored.movesMade, engine.movesMade);
      expect(restored.isCurrent, isTrue);
    });

    test('resumes into an engine that plays on identically', () {
      GameEngine fresh() => GameEngine(
        mode: const InfiniteHuntMode(
          grid: GridConfig(rows: 6, cols: 6, kindCount: 5),
        ),
        seed: 4242,
      );

      final original = fresh();
      for (var i = 0; i < 6 && !original.isOver; i++) {
        final hint = original.hint()!;
        original.applyMove(hint.a, hint.b);
      }

      final resumed = GameEngine.restore(
        mode: const InfiniteHuntMode(
          grid: GridConfig(rows: 6, cols: 6, kindCount: 5),
        ),
        snapshot: original.snapshot(),
      );

      expect(resumed.board, original.board);
      expect(resumed.score, original.score);
      expect(resumed.movesMade, original.movesMade);
      expect(resumed.bestChain, original.bestChain);

      // Play the same moves on both and they must stay in lockstep, which is
      // what the stored generator state buys us.
      for (var i = 0; i < 8 && !original.isOver; i++) {
        final hint = original.hint()!;
        original.applyMove(hint.a, hint.b);
        resumed.applyMove(hint.a, hint.b);
        expect(resumed.board, original.board, reason: 'diverged on move $i');
        expect(resumed.score, original.score);
      }
    });

    test('keeps a power that was on the board', () {
      final mode = const InfiniteHuntMode(
        grid: GridConfig(rows: 5, cols: 5, kindCount: 5),
      );
      final engine = GameEngine(mode: mode, seed: 3);
      final board = engine.board;
      final upgraded = board.withTile(
        const Pos(2, 2),
        board.at(const Pos(2, 2))!.withPower(TilePower.colourBomb),
      );

      final snapshot = RunSnapshot(
        version: RunSnapshot.currentVersion,
        modeId: mode.id,
        rows: upgraded.rows,
        cols: upgraded.cols,
        cells: RunSnapshot.cellsOf(upgraded),
        seed: 3,
        rngState: 12345,
        rngDraws: 0,
        nextTileId: 500,
        score: 120,
        movesMade: 4,
        tilesCollected: 12,
        bestChain: 2,
        longestLine: 4,
        specialsFired: 1,
      );

      final resumed = GameEngine.restore(mode: mode, snapshot: snapshot);

      expect(resumed.board.at(const Pos(2, 2))!.power, TilePower.colourBomb);
      expect(
        resumed.board.at(const Pos(2, 2))!.id,
        upgraded.at(const Pos(2, 2))!.id,
      );
      expect(resumed.score, 120);
    });

    test('carries Rising Tide state so the tide does not reset', () {
      final mode = RisingTideMode(baseInterval: 2);
      final engine = GameEngine(mode: mode, seed: 11);
      for (var i = 0; i < 5 && !engine.isOver; i++) {
        final hint = engine.hint()!;
        engine.applyMove(hint.a, hint.b);
      }
      expect(mode.rowsRisen, greaterThan(0));

      final resumedMode = RisingTideMode(baseInterval: 2);
      GameEngine.restore(mode: resumedMode, snapshot: engine.snapshot());

      expect(resumedMode.rowsRisen, mode.rowsRisen);
      expect(resumedMode.movesUntilRise, mode.movesUntilRise);
    });

    test('a snapshot from a future format is rejected, not misread', () {
      final json = {
        ...GameEngine(
          mode: const InfiniteHuntMode(),
          seed: 1,
        ).snapshot().toJson(),
        'version': RunSnapshot.currentVersion + 1,
      };

      expect(RunSnapshot.fromJson(json).isCurrent, isFalse);
    });
  });
}
