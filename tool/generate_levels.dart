// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:tessera/engine/engine.dart';

/// Builds a Clear the Board level pack.
///
///     dart run tool/generate_levels.dart --count 30 --out assets/levels/pack_01.json
///
/// Candidate layouts are generated with balanced kind counts, then handed to
/// [ClearBoardSolver]. Only layouts the solver actually beat are written out,
/// and each level's par is the length of that proven solution. A layout that
/// exhausts the node budget is discarded rather than shipped on a hunch.
void main(List<String> args) {
  final options = _Options.parse(args);
  final tiers = _tiersFor(options.count);
  final solver = ClearBoardSolver(nodeBudget: options.budget);

  final levels = <Level>[];
  var seed = options.firstSeed;
  var attempts = 0;
  final started = DateTime.now();

  for (var number = 1; number <= options.count; number++) {
    final tier = tiers[number - 1];
    Level? level;

    while (level == null) {
      if (attempts++ > options.maxAttempts) {
        stderr.writeln(
          'Gave up on level $number after $attempts candidates. '
          'Try a bigger --budget or an easier tier.',
        );
        exit(1);
      }

      final candidate = BoardGenerator.generateBalanced(
        grid: tier,
        rng: SeededRandom(seed),
        tiles: TileFactory(),
      );
      final outcome = solver.solve(candidate);
      if (outcome.solved) {
        level = Level(
          number: number,
          sketch: candidate.toSketch(),
          kindCount: tier.kindCount,
          parMoves: outcome.moveCount,
          seed: seed,
        );
        print(
          'level $number  ${tier.rows}x${tier.cols}  ${tier.kindCount} kinds  '
          'par ${outcome.moveCount}  (seed $seed, ${outcome.nodesVisited} nodes)',
        );
      }
      seed++;
    }

    levels.add(level);
  }

  final pack = LevelPack(id: options.packId, version: 1, levels: levels);
  final file = File(options.output)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(pack.toJson())}\n',
    );

  final elapsed = DateTime.now().difference(started);
  print(
    '\nWrote ${levels.length} levels to ${file.path} '
    'from $attempts candidates in ${elapsed.inSeconds}s.',
  );
}

/// Difficulty ramp: the board grows and gains a colour as the pack goes on.
///
/// The first two levels are a 3x3 with three colours — nine tiles, three
/// triples, over in a few moves. They exist to teach the one idea that makes
/// this mode different (nothing refills, so every tile has to go) before the
/// board is big enough to get lost on.
///
/// `upTo` is the cumulative fraction of the pack a tier reaches, so the shape
/// of the ramp survives a different `--count`.
List<GridConfig> _tiersFor(int count) {
  const ramp = <({double upTo, GridConfig grid})>[
    (upTo: 0.10, grid: GridConfig(rows: 3, cols: 3, kindCount: 3)),
    (upTo: 0.20, grid: GridConfig(rows: 4, cols: 4, kindCount: 3)),
    (upTo: 0.37, grid: GridConfig(rows: 5, cols: 5, kindCount: 3)),
    (upTo: 0.67, grid: GridConfig(rows: 6, cols: 6, kindCount: 4)),
    (upTo: 1.00, grid: GridConfig(rows: 7, cols: 6, kindCount: 4)),
  ];

  return [
    for (var i = 0; i < count; i++)
      ramp
          .firstWhere(
            (tier) => i < (tier.upTo * count).ceil(),
            orElse: () => ramp.last,
          )
          .grid,
  ];
}

class _Options {
  const _Options({
    required this.count,
    required this.output,
    required this.budget,
    required this.firstSeed,
    required this.maxAttempts,
    required this.packId,
  });

  factory _Options.parse(List<String> args) {
    String? valueOf(String name) {
      final index = args.indexOf('--$name');
      return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
    }

    return _Options(
      count: int.parse(valueOf('count') ?? '30'),
      output: valueOf('out') ?? 'assets/levels/pack_01.json',
      budget: int.parse(valueOf('budget') ?? '200000'),
      firstSeed: int.parse(valueOf('seed') ?? '1'),
      maxAttempts: int.parse(valueOf('max-attempts') ?? '4000'),
      packId: valueOf('pack-id') ?? 'pack_01',
    );
  }

  final int count;
  final String output;
  final int budget;
  final int firstSeed;
  final int maxAttempts;
  final String packId;
}
