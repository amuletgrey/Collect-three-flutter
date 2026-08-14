import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/engine/engine.dart';
import 'package:tessera/game/game_controller.dart';
import 'package:tessera/game/motion.dart';
import 'package:tessera/skins/skin_registry.dart';
import 'package:tessera/ui/widgets/board_view.dart';

/// 3 rows x 4 cols. Swapping (0,2) with (1,2) completes the top row of 1s.
const _layout = '1102\n2210\n0021';

const double _cell = 100;

GameController _controller() => GameController(
  mode: const ClearBoardMode(
    grid: GridConfig(rows: 3, cols: 4, kindCount: 3),
    layoutSketch: _layout,
  ),
  seed: 1,
  motion: const Motion(reduced: true),
);

Future<void> _pumpBoard(WidgetTester tester, GameController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: _cell * 4,
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

/// Runs out every pending animation *and* the controller's own timers, which
/// outlive the last scheduled frame.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Offset _centreOf(WidgetTester tester, Pos pos) {
  final origin = tester.getTopLeft(find.byType(BoardView));
  return origin +
      Offset(pos.col * _cell + _cell / 2, pos.row * _cell + _cell / 2);
}

void main() {
  testWidgets('tap-tap on neighbouring tiles plays the move', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller);

    await tester.tapAt(_centreOf(tester, const Pos(0, 2)));
    await tester.pump();
    expect(controller.selected, const Pos(0, 2));

    await tester.tapAt(_centreOf(tester, const Pos(1, 2)));
    await _settle(tester);

    expect(controller.score, 30);
    expect(controller.movesMade, 1);
    expect(controller.selected, isNull);
  });

  testWidgets('tapping a distant tile moves the selection instead', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller);

    await tester.tapAt(_centreOf(tester, const Pos(0, 0)));
    await tester.pump();
    await tester.tapAt(_centreOf(tester, const Pos(2, 3)));
    await tester.pump();

    expect(controller.selected, const Pos(2, 3));
    expect(controller.movesMade, 0);
  });

  testWidgets('dragging a tile towards its neighbour plays the move', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller);

    await tester.dragFrom(
      _centreOf(tester, const Pos(0, 2)),
      const Offset(0, _cell),
    );
    await _settle(tester);

    expect(controller.movesMade, 1);
    expect(controller.score, 30);
  });

  testWidgets('a swap that forms nothing costs neither a move nor a score', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller);

    await tester.dragFrom(
      _centreOf(tester, const Pos(1, 0)),
      const Offset(0, _cell),
    );
    await _settle(tester);

    expect(controller.movesMade, 0);
    expect(controller.score, 0);
    expect(controller.board.toSketch(), _layout);
  });

  testWidgets('input is ignored while the board is animating', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller);

    await tester.tapAt(_centreOf(tester, const Pos(0, 2)));
    await tester.pump();
    await tester.tapAt(_centreOf(tester, const Pos(1, 2)));
    await tester.pump(const Duration(milliseconds: 10));

    expect(controller.busy, isTrue);
    await tester.tapAt(_centreOf(tester, const Pos(2, 0)));
    await tester.pump();
    expect(controller.selected, isNull, reason: 'taps must not queue up');

    await _settle(tester);
    expect(controller.busy, isFalse);
    expect(controller.movesMade, 1);
  });

  testWidgets('renders one tile widget per tile on the board', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller);

    expect(find.byType(BoardView), findsOneWidget);
    expect(controller.tileIds.length, controller.board.tileCount);
  });
}
