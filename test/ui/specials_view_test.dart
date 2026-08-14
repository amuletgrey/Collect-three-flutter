import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/engine/engine.dart';
import 'package:tessera/game/game_controller.dart';
import 'package:tessera/game/motion.dart';
import 'package:tessera/skins/skin_registry.dart';
import 'package:tessera/ui/widgets/board_view.dart';
import 'package:tessera/ui/widgets/tile_view.dart';

const double _cell = 100;

/// A fixed 3x5 layout with powers on, so the board can be driven over tiles we
/// placed rather than whatever a generator produced.
class _Bench extends GameMode {
  const _Bench(this.sketch, this.powers);

  final String sketch;
  final Map<Pos, TilePower> powers;

  @override
  String get id => 'bench';
  @override
  String get name => 'Bench';
  @override
  String get tagline => 'test fixture';
  @override
  GridConfig get grid => const GridConfig(rows: 3, cols: 5, kindCount: 3);
  @override
  GravityRule get gravity => GravityRule.down;
  @override
  RefillRule get refill => RefillRule.none;
  @override
  bool get allowsSpecials => true;

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) {
    var board = Board.parse(sketch, tiles: tiles);
    powers.forEach((pos, power) {
      board = board.withTile(pos, board.at(pos)!.withPower(power));
    });
    return board;
  }

  @override
  ModeEvaluation evaluate(ModeContext ctx) => const ModeEvaluation.playing();

  @override
  GameMode fresh() => this;
}

GameController _controller(Map<Pos, TilePower> powers) => GameController(
  mode: _Bench('01201\n12012\n20120', powers),
  seed: 1,
  motion: const Motion(reduced: true),
);

Future<void> _pumpBoard(WidgetTester tester, GameController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: _cell * 5,
          height: _cell * 3,
          child: BoardView(
            controller: controller,
            skin: SkinRegistry.classicArcade,
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Offset _centreOf(WidgetTester tester, Pos pos) {
  final grid = tester.getRect(find.byKey(BoardView.gridKey));
  return grid.topLeft +
      Offset((pos.col + 0.5) * _cell, (pos.row + 0.5) * _cell);
}

void main() {
  testWidgets('every power reaches its tile widget', (tester) async {
    final controller = _controller({
      const Pos(0, 0): TilePower.clearRow,
      const Pos(0, 1): TilePower.clearColumn,
      const Pos(0, 2): TilePower.bomb,
      const Pos(0, 3): TilePower.colourBomb,
    });
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller);

    final powers = tester
        .widgetList<TileView>(find.byType(TileView))
        .map((view) => view.power)
        .toSet();

    expect(powers, containsAll(TilePower.values));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a colour bomb onto a neighbour fires it', (
    tester,
  ) async {
    final controller = _controller({const Pos(0, 0): TilePower.colourBomb});
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller);

    await tester.tapAt(_centreOf(tester, const Pos(0, 0)));
    await tester.pump();
    await tester.tapAt(_centreOf(tester, const Pos(0, 1)));
    await _settle(tester);

    expect(controller.movesMade, 1);
    expect(controller.score, greaterThan(0));
    expect(
      controller.board.tiles.any((t) => t.kind == 1),
      isFalse,
      reason: 'the bomb took the kind it was swapped with',
    );
  });

  testWidgets('a four-line leaves a power on the board', (tester) async {
    final controller = GameController(
      mode: const _Bench('11212\n20102\n02020', {}),
      seed: 1,
      motion: const Motion(reduced: true),
    );
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller);

    // Swapping (0,2) with (1,2) brings a 1 up to complete 1,1,1,1 on row 0.
    await tester.tapAt(_centreOf(tester, const Pos(0, 2)));
    await tester.pump();
    await tester.tapAt(_centreOf(tester, const Pos(1, 2)));
    await _settle(tester);

    expect(controller.movesMade, 1);
    final specials = controller.board.tiles.where((t) => t.isSpecial);
    expect(specials, hasLength(1));
    expect(specials.single.power, TilePower.clearRow);
  });
}
