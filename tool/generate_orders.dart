// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:tessera/engine/engine.dart';

/// Builds a Work Order level pack.
///
///     dart run tool/generate_orders.dart --count 30 --out assets/orders/pack_01.json
///
/// An order cannot be *proved* fillable the way a Clear the Board layout can —
/// the board refills at random, so there is no tree to search. So this does the
/// next best thing and plays each candidate with [OrderBot] across a cohort of
/// seeds, keeping only the ones a competent player finishes.
///
/// Each shipped level names one seed, which is the board every player gets. Its
/// `par` is what the bot needed on that exact board; its `budget` is that plus
/// room to be human, tightening as the pack goes on. `fill` records how much of
/// the cohort the bot managed inside the budget — the evidence that the level
/// is not a knife edge.
void main(List<String> args) {
  final options = _Options.parse(args);
  const bot = OrderBot();

  final levels = <OrderLevel>[];
  final started = DateTime.now();

  for (var number = 1; number <= options.count; number++) {
    final tier = _tierFor(number, options.count);
    final level = _buildLevel(
      number: number,
      tier: tier,
      bot: bot,
      cohort: options.cohort,
      firstSeed: options.firstSeed + number * 1000,
    );
    if (level == null) {
      stderr.writeln('Could not settle level $number; easing the tier.');
      exit(1);
    }
    levels.add(level);
    print(
      'level ${number.toString().padLeft(2)}  '
      '${_describe(level).padRight(46)} '
      'par ${level.parMoves.toString().padLeft(2)}  '
      'budget ${level.moveBudget.toString().padLeft(2)}  '
      'fill ${(level.fillRate * 100).round()}%',
    );
  }

  final pack = OrderPack(id: options.packId, version: 1, levels: levels);
  File(options.out)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(pack.toJson()),
    );

  final elapsed = DateTime.now().difference(started);
  print(
    '\nWrote ${levels.length} orders to ${options.out} '
    'in ${elapsed.inSeconds}s',
  );
}

/// What an order at this point in the pack should ask for.
class _Tier {
  const _Tier({
    required this.lineCount,
    required this.collectTarget,
    required this.kindCount,
    this.extra,
    this.extraTarget = 0,
  });

  final int lineCount;
  final int collectTarget;
  final int kindCount;

  /// The line that is not about volume, once the pack starts asking for one.
  final OrderKind? extra;
  final int extraTarget;
}

/// The ramp, in three bands.
///
/// Each band changes one thing, so a level only ever teaches one thing at a
/// time. The third band is the interesting one: it *takes a line away* and adds
/// a colour instead. Seven colours plus three lines plus rising targets was
/// tried first and the bot showed it up — pars in the mid-thirties, which is a
/// grind, not a challenge. A seventh colour makes every line slower, so it has
/// to be paid for somewhere.
_Tier _tierFor(int number, int count) {
  final progress = (number - 1) / (count - 1);

  // Band A — learning the mode: five colours, one line, then two.
  if (progress < 0.3) {
    return _Tier(
      lineCount: progress < 0.15 ? 1 : 2,
      collectTarget: (14 + progress * 10).round(),
      kindCount: 5,
    );
  }

  // Band C — the last third: one fewer line, one more colour, tightest budget.
  if (progress >= 0.7) {
    // Everything here is asked for in smaller quantities than band B asks at
    // six colours. That is not a mistake: a seventh colour slows every line
    // down, so the same numbers would only make the level longer, and the
    // budget is where this band gets its teeth.
    //
    // No blast lines either. Powers come from four-in-a-row, which is markedly
    // rarer on seven colours — the generator kept having to ease those levels
    // until they came out easier than the ones before them, which is the ramp
    // going backwards. Band C alternates a chain line with a second colour.
    return _Tier(
      lineCount: 2,
      collectTarget: (16 + (progress - 0.7) * 10).round(),
      kindCount: 7,
      extra: number.isEven ? OrderKind.cascade : null,
      extraTarget: 3,
    );
  }

  // Band B — the middle: six colours, up to three lines, and the line that is
  // not about volume arrives. The two kinds alternate so neither becomes the
  // one you stop noticing.
  return _Tier(
    lineCount: progress < 0.45 ? 2 : 3,
    collectTarget: (17 + (progress - 0.3) * 12).round(),
    kindCount: 6,
    extra: number.isEven ? OrderKind.cascade : OrderKind.demolish,
    // Chains stay at three however late the level is. Four was tried: on a
    // seven-colour board the bot could not manage it reliably at any budget,
    // which makes it a wait-for-luck requirement rather than a skill one.
    extraTarget: number.isEven ? 3 : (8 + progress * 8).round(),
  );
}

List<OrderLine> _orderFor(_Tier tier, SeededRandom rng) {
  final kinds = [for (var k = 0; k < tier.kindCount; k++) k];
  rng.shuffle(kinds);

  final collectLines = tier.extra == null ? tier.lineCount : tier.lineCount - 1;
  return [
    for (var i = 0; i < collectLines; i++)
      OrderLine(
        kind: OrderKind.collect,
        tileKind: kinds[i],
        target: tier.collectTarget,
      ),
    if (tier.extra case final extra?)
      OrderLine(kind: extra, target: tier.extraTarget),
  ];
}

/// Plays the candidate on a cohort of seeds, then ships the one that behaved
/// most like the middle of that cohort — a level should be typical, not lucky.
OrderLevel? _buildLevel({
  required int number,
  required _Tier tier,
  required OrderBot bot,
  required int cohort,
  required int firstSeed,
}) {
  var order = _orderFor(tier, SeededRandom(firstSeed));

  for (var attempt = 0; attempt < 5; attempt++) {
    WorkOrderMode build(int budget) => WorkOrderMode(
      grid: GridConfig(rows: 8, cols: 8, kindCount: tier.kindCount),
      moveBudget: budget,
      lineCount: order.length,
      fixedOrder: [
        for (final line in order)
          OrderLine(
            kind: line.kind,
            target: line.target,
            tileKind: line.tileKind,
          ),
      ],
    );

    // First pass: an unreasonably generous budget, purely to find out how many
    // moves this order really takes.
    const generous = 90;
    final runs = <(int seed, int moves)>[];
    for (var i = 0; i < cohort; i++) {
      final seed = firstSeed + i;
      final run = bot.play(mode: () => build(generous), seed: seed);
      if (run.filled) runs.add((seed, run.movesUsed));
    }

    if (runs.length < cohort * 0.8) {
      // The bot cannot reliably finish this at any budget: ask for less. Worth
      // shouting about — easing is how a ramp quietly goes backwards, and a
      // level that needs it usually means the tier is wrong, not the numbers.
      stderr.writeln(
        '  level $number eased: only ${runs.length}/$cohort filled at any '
        'budget',
      );
      order = [
        for (final line in order)
          OrderLine(
            kind: line.kind,
            tileKind: line.tileKind,
            target: (line.target * 0.85).round().clamp(3, 99),
          ),
      ];
      continue;
    }

    runs.sort((a, b) => a.$2.compareTo(b.$2));
    final median = runs[runs.length ~/ 2];

    // Slack narrows as the pack goes on: generous while the mode is new,
    // close to the bot's own line by the end.
    final slack = 1.55 - (number / 60);
    var budget = (median.$2 * slack).round() + 1;

    for (var widening = 0; widening < 5; widening++) {
      var filled = 0;
      for (var i = 0; i < cohort; i++) {
        if (bot.play(mode: () => build(budget), seed: firstSeed + i).filled) {
          filled++;
        }
      }
      final fill = filled / cohort;
      if (fill >= 0.7) {
        return OrderLevel(
          number: number,
          lines: order,
          moveBudget: budget,
          kindCount: tier.kindCount,
          parMoves: median.$2,
          seed: median.$1,
          fillRate: fill,
        );
      }
      budget += 2;
    }
  }
  return null;
}

String _describe(OrderLevel level) => level.lines
    .map(
      (line) => switch (line.kind) {
        OrderKind.collect => '${line.target}x colour ${line.tileKind}',
        OrderKind.demolish => '${line.target} blasted',
        OrderKind.cascade => 'chain ${line.target}',
      },
    )
    .join(', ');

class _Options {
  const _Options({
    required this.count,
    required this.out,
    required this.packId,
    required this.cohort,
    required this.firstSeed,
  });

  factory _Options.parse(List<String> args) {
    var count = 30;
    var out = 'assets/orders/pack_01.json';
    var packId = 'orders_01';
    var cohort = 12;
    var firstSeed = 4000;

    for (var i = 0; i < args.length - 1; i += 2) {
      final value = args[i + 1];
      switch (args[i]) {
        case '--count':
          count = int.parse(value);
        case '--out':
          out = value;
        case '--id':
          packId = value;
        case '--cohort':
          cohort = int.parse(value);
        case '--seed':
          firstSeed = int.parse(value);
      }
    }
    return _Options(
      count: count,
      out: out,
      packId: packId,
      cohort: cohort,
      firstSeed: firstSeed,
    );
  }

  final int count;
  final String out;
  final String packId;

  /// How many seeds each candidate is played on.
  final int cohort;
  final int firstSeed;
}
