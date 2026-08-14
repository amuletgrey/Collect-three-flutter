import 'package:collect_three/engine/engine.dart';
import 'package:collect_three/engine/specials/special_rules.dart';
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;

/// Board.parse knows nothing about powers, so tests stamp them on afterwards.
Board withPowers(String sketch, Map<Pos, TilePower> powers) {
  var board = Board.parse(sketch);
  powers.forEach((pos, power) {
    board = board.withTile(pos, board.at(pos)!.withPower(power));
  });
  return board;
}

SpecialSpawn? spawnOf(Board board, {Pos? origin}) {
  final matches = MatchFinder.find(board);
  final spawns = SpecialRules.spawnsFor(matches, origin: origin);
  return spawns.isEmpty ? null : spawns.single;
}

void main() {
  group('what a match creates', () {
    test('three in a row earns nothing', () {
      expect(spawnOf(Board.parse('1110\n2021\n0202')), isNull);
    });

    test('four in a row earns a row clear', () {
      final spawn = spawnOf(Board.parse('11112\n20200\n02020'))!;

      expect(spawn.power, TilePower.clearRow);
      expect(spawn.kind, 1);
      expect(spawn.at.row, 0);
    });

    test('four in a column earns a column clear', () {
      final spawn = spawnOf(Board.parse('120\n102\n120\n102\n012'))!;

      expect(spawn.power, TilePower.clearColumn);
      expect(spawn.at.col, 0);
    });

    test('five in a line earns a colour bomb', () {
      final spawn = spawnOf(Board.parse('11111\n20202\n02020'))!;

      expect(spawn.power, TilePower.colourBomb);
    });

    test('an L shape earns a bomb, placed on the corner', () {
      final spawn = spawnOf(Board.parse('1110\n1021\n1200'))!;

      expect(spawn.power, TilePower.bomb);
      expect(spawn.at, const Pos(0, 0), reason: 'the two lines cross there');
    });

    test('the power lands under the tile the player moved', () {
      final board = Board.parse('11112\n20200\n02020');

      expect(spawnOf(board, origin: const Pos(0, 3))!.at, const Pos(0, 3));
      expect(
        spawnOf(board, origin: const Pos(2, 2))!.at,
        isNot(const Pos(2, 2)),
        reason: 'an origin outside the shape is ignored',
      );
    });

    test('only one power per shape', () {
      final matches = MatchFinder.find(Board.parse('1110\n1021\n1200'));

      expect(matches.lines, hasLength(2));
      expect(matches.groups, hasLength(1), reason: 'the lines touch');
      expect(SpecialRules.spawnsFor(matches), hasLength(1));
    });

    test('separate shapes each earn their own power', () {
      // Two independent runs of four, far apart.
      final matches = MatchFinder.find(
        Board.parse('111120\n202001\n020102\n111120\n202001'),
      );

      expect(matches.groups.length, greaterThanOrEqualTo(2));
      expect(
        SpecialRules.spawnsFor(matches).length,
        matches.groups.where((g) => g.longestLine >= 4).length,
      );
    });
  });

  group('what a power destroys', () {
    test('a row clear takes the whole row', () {
      final board = withPowers('01201\n12012\n20120', {
        const Pos(1, 2): TilePower.clearRow,
      });

      expect(SpecialRules.blastOf(board, const Pos(1, 2)), {
        const Pos(1, 0),
        const Pos(1, 1),
        const Pos(1, 2),
        const Pos(1, 3),
        const Pos(1, 4),
      });
    });

    test('a column clear takes the whole column', () {
      final board = withPowers('01201\n12012\n20120', {
        const Pos(0, 3): TilePower.clearColumn,
      });

      expect(SpecialRules.blastOf(board, const Pos(0, 3)), {
        const Pos(0, 3),
        const Pos(1, 3),
        const Pos(2, 3),
      });
    });

    test('a bomb takes the 3x3 around it, clipped at the edge', () {
      final board = withPowers('01201\n12012\n20120', {
        const Pos(0, 0): TilePower.bomb,
      });

      expect(SpecialRules.blastOf(board, const Pos(0, 0)), {
        const Pos(0, 0),
        const Pos(0, 1),
        const Pos(1, 0),
        const Pos(1, 1),
      });
    });

    test('a colour bomb takes every tile of the kind it touched', () {
      final board = withPowers('01201\n12012\n20120', {
        const Pos(0, 0): TilePower.colourBomb,
      });

      final blast = SpecialRules.blastOf(
        board,
        const Pos(0, 0),
        swappedKind: 2,
      );

      expect(blast, contains(const Pos(0, 2)));
      expect(blast, contains(const Pos(1, 1)));
      expect(blast, contains(const Pos(2, 0)));
      expect(blast, contains(const Pos(0, 0)), reason: 'it goes too');
      expect(
        blast,
        isNot(contains(const Pos(0, 1))),
        reason: 'kind 1 survives',
      );
    });

    test('an ordinary tile destroys nothing', () {
      final board = Board.parse('01201\n12012\n20120');

      expect(SpecialRules.blastOf(board, const Pos(0, 0)), isEmpty);
    });
  });

  group('chains', () {
    test('a blast sets off the powers it sweeps through', () {
      // A row clear on row 1 sweeps a column clear sitting in the same row.
      final board = withPowers('01201\n12012\n20120', {
        const Pos(1, 0): TilePower.clearRow,
        const Pos(1, 3): TilePower.clearColumn,
      });

      final outcome = SpecialRules.resolveBlasts(board, {const Pos(1, 0)});

      expect(outcome.detonated, contains(const Pos(1, 0)));
      expect(
        outcome.detonated,
        contains(const Pos(1, 3)),
        reason: 'the row clear caught the column clear',
      );
      // Row 1 plus the whole of column 3.
      expect(outcome.cells, contains(const Pos(0, 3)));
      expect(outcome.cells, contains(const Pos(2, 3)));
    });

    test('every power fires at most once, so a chain terminates', () {
      // Two row clears in the same row would set each other off forever.
      final board = withPowers('01201\n12012\n20120', {
        const Pos(1, 0): TilePower.clearRow,
        const Pos(1, 4): TilePower.clearRow,
      });

      final outcome = SpecialRules.resolveBlasts(board, {const Pos(1, 0)});

      expect(outcome.detonated, hasLength(2));
      expect(outcome.cells, hasLength(5));
    });

    test('a lone plain clear detonates nothing', () {
      final board = Board.parse('01201\n12012\n20120');
      final outcome = SpecialRules.resolveBlasts(board, {const Pos(0, 0)});

      expect(outcome.detonated, isEmpty);
      expect(outcome.cells, {const Pos(0, 0)});
    });
  });
}
