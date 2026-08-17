import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

/// Read from disk rather than through the asset bundle: this is a test of what
/// the generator wrote, not of Flutter's asset loading.
OrderPack _shipped() => OrderPack.fromJson(
  jsonDecode(File('assets/orders/pack_01.json').readAsStringSync())
      as Map<String, Object?>,
);

void main() {
  group('the shipped order pack', () {
    final pack = _shipped();

    test('is numbered from one with no gaps', () {
      expect(pack.levels, hasLength(30));
      expect(
        [for (final level in pack.levels) level.number],
        [for (var i = 1; i <= pack.length; i++) i],
      );
    });

    test('never asks for something a run cannot deliver', () {
      for (final level in pack.levels) {
        expect(level.lines, isNotEmpty, reason: 'level ${level.number}');
        expect(
          level.moveBudget,
          greaterThanOrEqualTo(level.parMoves),
          reason: 'level ${level.number} budgets less than its own par',
        );
        for (final line in level.lines) {
          expect(line.target, greaterThan(0));
          expect(line.progress, 0, reason: 'a shipped line starts empty');
          if (line.kind == OrderKind.collect) {
            expect(
              line.tileKind,
              lessThan(level.kindCount),
              reason: 'level ${level.number} wants a colour it never deals',
            );
          }
        }
      }
    });

    test('no level asks twice for the same colour', () {
      for (final level in pack.levels) {
        final wanted = [
          for (final line in level.lines)
            if (line.kind == OrderKind.collect) line.tileKind,
        ];
        expect(
          wanted.toSet(),
          hasLength(wanted.length),
          reason: 'level ${level.number} asked for one colour twice',
        );
      }
    });

    test('every level was actually filled by the bot it was measured with', () {
      for (final level in pack.levels) {
        expect(
          level.fillRate,
          greaterThanOrEqualTo(0.7),
          reason: 'level ${level.number} shipped on thin evidence',
        );
      }
    });

    test('the pack gets harder overall, whatever it does level to level', () {
      // Board to board this wobbles — each level is a different random board,
      // so par is not monotonic and pretending otherwise would be a brittle
      // test. The trend is what matters.
      double meanPar(Iterable<OrderLevel> levels) =>
          levels.map((level) => level.parMoves).reduce((a, b) => a + b) /
          levels.length;

      final third = pack.length ~/ 3;
      final opening = meanPar(pack.levels.take(third));
      final closing = meanPar(pack.levels.skip(pack.length - third));

      expect(closing, greaterThan(opening * 2));
    });

    test('it opens gently and ends tight', () {
      final first = pack.levels.first;
      expect(first.lines, hasLength(1), reason: 'one thing to learn at a time');
      expect(first.kindCount, 5);

      // Slack is budget over par: how much room there is to be human.
      double slack(OrderLevel level) => level.moveBudget / level.parMoves;
      expect(slack(pack.levels.first), greaterThan(slack(pack.levels.last)));
    });

    test('a level round-trips through JSON', () {
      final level = pack.levels[12];
      final copy = OrderLevel.fromJson(
        jsonDecode(jsonEncode(level.toJson())) as Map<String, Object?>,
      );

      expect(copy.number, level.number);
      expect(copy.moveBudget, level.moveBudget);
      expect(copy.parMoves, level.parMoves);
      expect(copy.seed, level.seed);
      expect(
        [
          for (final line in copy.lines)
            (line.kind, line.target, line.tileKind),
        ],
        [
          for (final line in level.lines)
            (line.kind, line.target, line.tileKind),
        ],
      );
    });
  });

  group('a level becomes a run', () {
    test('the mode takes its order and budget from the level', () {
      final level = _shipped().levels[5];
      final mode = WorkOrderMode.fromLevel(level);
      GameEngine(mode: mode, seed: level.seed);

      expect(mode.moveBudget, level.moveBudget);
      expect(mode.grid.kindCount, level.kindCount);
      expect(
        [for (final line in mode.order) (line.kind, line.target)],
        [for (final line in level.lines) (line.kind, line.target)],
      );
    });

    test('playing a level twice starts from zero both times', () {
      final level = _shipped().levels.first;
      final mode = WorkOrderMode.fromLevel(level);
      final engine = GameEngine(mode: mode, seed: level.seed);

      for (var i = 0; i < 3; i++) {
        final move = engine.hint();
        if (move == null) break;
        engine.applyMove(move.a, move.b);
      }
      expect(mode.order.first.progress, greaterThan(0));

      final again = mode.fresh() as WorkOrderMode;
      GameEngine(mode: again, seed: level.seed);

      expect(again.order.first.progress, 0);
    });

    test('stars follow the par the bot set', () {
      final level = _shipped().levels.first;

      expect(level.starsFor(level.parMoves), 3);
      expect(level.starsFor(level.parMoves + 1), 2);
      expect(level.starsFor(level.parMoves + 9), 1);
    });

    test('the shipped seed really is fillable inside the budget', () {
      // The strongest claim the pack makes, checked against the pack itself:
      // the bot plays the exact board a player will get and finishes it.
      const bot = OrderBot();
      final pack = _shipped();

      for (final level in [pack.levels[0], pack.levels[9], pack.levels[19]]) {
        final run = bot.play(
          mode: () => WorkOrderMode.fromLevel(level),
          seed: level.seed,
        );
        expect(
          run.filled,
          isTrue,
          reason: 'level ${level.number} could not be filled on its own seed',
        );
        expect(run.movesUsed, lessThanOrEqualTo(level.moveBudget));
      }
    });
  });
}
