import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:integration_test/integration_test.dart';
import 'package:tessera/engine/engine.dart';
import 'package:tessera/game/game_controller.dart';
import 'package:tessera/game/motion.dart';
import 'package:tessera/main.dart' as app;
import 'package:tessera/skins/skin_registry.dart';
import 'package:tessera/ui/widgets/board_view.dart';

/// End-to-end tests that drive the real app with real gestures.
///
/// Run them on whatever you have plugged in:
///   flutter test integration_test -d windows
///   flutter test integration_test -d `android-device-id`
///
/// These are the only tests that exercise the actual rendering backend, which
/// is the thing that differs between a modern phone and an old one.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home screen offers every mode and skin', (tester) async {
    await _launch(tester);

    expect(find.text('Infinite Hunt'), findsOneWidget);
    expect(find.text('Clear the Board'), findsOneWidget);
    expect(find.text('Rising Tide'), findsOneWidget);

    expect(find.text('Classic Arcade'), findsOneWidget);
    expect(find.text('Treasure Hunt'), findsOneWidget);
    expect(find.text('Candy Shop'), findsOneWidget);
  });

  testWidgets('every skin renders the home screen without crashing', (
    tester,
  ) async {
    await _launch(tester);

    for (final skin in ['Treasure Hunt', 'Candy Shop', 'Classic Arcade']) {
      await tester.tap(find.text(skin));
      await tester.pumpAndSettle();
      expect(
        find.text('TESSERA'),
        findsOneWidget,
        reason: 'after picking $skin',
      );
    }
  });

  for (final mode in ['Infinite Hunt', 'Clear the Board', 'Rising Tide']) {
    testWidgets('$mode plays real moves and scores', (tester) async {
      await _launch(tester);
      await _openMode(tester, mode);

      final controller = _controller(tester);
      expect(controller.board.tileCount, greaterThan(0));

      var played = 0;
      for (var i = 0; i < 6 && !controller.isOver; i++) {
        if (await _playHintedMove(tester, controller)) played++;
      }

      expect(played, greaterThan(0), reason: 'no move could be played');
      expect(controller.score, greaterThan(0));
      expect(
        MatchFinder.find(controller.board).isEmpty,
        isTrue,
        reason: 'the board was left with an unresolved match',
      );
    });
  }

  testWidgets('switching skin mid-game keeps the run going', (tester) async {
    await _launch(tester);
    await tester.tap(find.text('Infinite Hunt'));
    await tester.pumpAndSettle();

    final controller = _controller(tester);
    await _playHintedMove(tester, controller);
    final scoreBefore = controller.score;
    final tilesBefore = controller.board.toSketch();

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Candy Shop'));
    await tester.pumpAndSettle();

    // Picking a skin closes the sheet and drops us straight back on the board.
    expect(find.byType(BoardView), findsOneWidget);
    expect(_controller(tester).score, scoreBefore);
    expect(_controller(tester).board.toSketch(), tilesBefore);
  });

  testWidgets('the level picker opens a real, provably solvable level', (
    tester,
  ) async {
    await _launch(tester);
    await tester.tap(find.text('Clear the Board'));
    await tester.pumpAndSettle();

    // Level 1 is unlocked, the rest of the pack is gated behind it.
    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    final controller = _controller(tester);
    expect(find.text('MOVES / PAR'), findsOneWidget);
    expect(controller.board.tileCount % 3, 0);
    expect(
      const ClearBoardSolver().solve(controller.board).solved,
      isTrue,
      reason: 'the shipped level must be clearable',
    );
  });

  // Powers are luck-dependent in a real run, so this pumps a board that has one
  // of each. It is the only check that the new artwork survives the device's
  // actual rasterizer.
  testWidgets('every power paints on this device', (tester) async {
    final controller = GameController(
      mode: const _PowerBench(),
      seed: 1,
      motion: const Motion(reduced: true),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 180,
            child: BoardView(
              controller: controller,
              skin: SkinRegistry.treasureHunt,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.board.tiles.where((t) => t.isSpecial), hasLength(4));
  });

  testWidgets('a rejected swap costs nothing', (tester) async {
    await _launch(tester);
    await tester.tap(find.text('Infinite Hunt'));
    await tester.pumpAndSettle();

    final controller = _controller(tester);
    final board = controller.board;

    // Find two neighbours whose swap the engine refuses.
    Move? dud;
    for (final p in board.positions) {
      final q = p.right;
      if (!board.contains(q)) continue;
      if (!MoveFinder.createsMatch(board, p, q)) {
        dud = Move(p, q);
        break;
      }
    }
    expect(dud, isNotNull);

    await _tapCell(tester, dud!.a);
    await tester.pump(const Duration(milliseconds: 120));
    await _tapCell(tester, dud.b);
    await _waitForIdle(tester, controller);

    expect(controller.score, 0);
    expect(controller.movesMade, 0);
  });
}

/// A fixed board carrying one of every power.
class _PowerBench extends GameMode {
  const _PowerBench();

  @override
  String get id => 'power_bench';
  @override
  String get name => 'Power bench';
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
    var board = Board.parse('01201\n12012\n20120', tiles: tiles);
    final powers = <Pos, TilePower>{
      const Pos(0, 0): TilePower.clearRow,
      const Pos(0, 1): TilePower.clearColumn,
      const Pos(0, 2): TilePower.bomb,
      const Pos(0, 3): TilePower.colourBomb,
    };
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

Future<void> _launch(WidgetTester tester) async {
  unawaited(app.main());
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}

/// Clear the Board goes through the level picker; the endless modes start
/// straight from the home card.
Future<void> _openMode(WidgetTester tester, String mode) async {
  await tester.tap(find.text(mode));
  await tester.pumpAndSettle();
  if (mode == 'Clear the Board') {
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
  }
}

GameController _controller(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView)).controller;

/// Asks the engine where a legal move is, then plays it with real taps.
Future<bool> _playHintedMove(
  WidgetTester tester,
  GameController controller,
) async {
  final hint = controller.engine.hint();
  if (hint == null) return false;
  final before = controller.movesMade;

  await _tapCell(tester, hint.a);
  await tester.pump(const Duration(milliseconds: 120));
  await _tapCell(tester, hint.b);
  await _waitForIdle(tester, controller);

  return controller.movesMade > before;
}

Future<void> _tapCell(WidgetTester tester, Pos pos) async {
  final grid = tester.getRect(find.byKey(BoardView.gridKey));
  final controller = _controller(tester);
  final cell = math.min(
    grid.width / controller.board.cols,
    grid.height / controller.board.rows,
  );
  await tester.tapAt(
    grid.topLeft + Offset((pos.col + 0.5) * cell, (pos.row + 0.5) * cell),
  );
}

/// Real devices run real timers, so waiting on the controller's own idle flag
/// is more reliable here than pumpAndSettle.
Future<void> _waitForIdle(
  WidgetTester tester,
  GameController controller,
) async {
  for (var i = 0; i < 200 && controller.busy; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}
