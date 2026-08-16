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

    for (final mode in [
      'Infinite Hunt',
      'Clear the Board',
      'Rising Tide',
      'Relic Dig',
      'Work Order',
      'Creeping Rot',
    ]) {
      expect(await _revealMode(tester, mode), findsOneWidget);
    }

    // The skins may be below the fold on a short screen.
    for (final skin in ['Classic Arcade', 'Treasure Hunt', 'Candy Shop']) {
      await tester.scrollUntilVisible(
        find.text(skin),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(skin), findsOneWidget);
    }
  });

  testWidgets('every skin renders the home screen without crashing', (
    tester,
  ) async {
    await _launch(tester);

    for (final skin in ['Treasure Hunt', 'Candy Shop', 'Classic Arcade']) {
      // On a short screen — a phone on its side — the skin rows are below the
      // fold, so reach them the way a player would.
      await tester.scrollUntilVisible(
        find.text(skin),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(skin));
      await tester.pumpAndSettle();

      // The title has scrolled away by now, so check what is actually on
      // screen: the list is still alive and the skin row survived its repaint.
      expect(find.text(skin), findsOneWidget, reason: 'after picking $skin');
      expect(tester.takeException(), isNull, reason: 'after picking $skin');
    }
  });

  for (final mode in [
    'Infinite Hunt',
    'Clear the Board',
    'Rising Tide',
    'Relic Dig',
    'Work Order',
    'Creeping Rot',
  ]) {
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

  testWidgets('Work Order shows the job it wants doing', (tester) async {
    await _launch(tester);
    await _openMode(tester, 'Work Order');

    final controller = _controller(tester);
    final goals = controller.mode.goals;
    expect(goals, isNotEmpty);

    // One chip per line, each with its own counter — or "done" once the line
    // is filled, which an earlier test in this run may already have managed.
    for (final goal in goals) {
      expect(
        find.text(goal.isDone ? 'done' : '${goal.progress}/${goal.target}'),
        findsWidgets,
        reason: 'no readout for "${goal.label}"',
      );
    }
    expect(find.text('MOVES LEFT'), findsOneWidget);
  });

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

    // Not necessarily zero: a saved run may have been resumed.
    final scoreBefore = controller.score;
    final movesBefore = controller.movesMade;

    await _tapCell(tester, dud!.a);
    await tester.pump(const Duration(milliseconds: 120));
    await _tapCell(tester, dud.b);
    await _waitForIdle(tester, controller);

    expect(controller.score, scoreBefore);
    expect(controller.movesMade, movesBefore);
  });

  testWidgets('hints are spent, and the button says how many are left', (
    tester,
  ) async {
    await _launch(tester);
    await tester.tap(find.text('Infinite Hunt'));
    await tester.pumpAndSettle();

    final controller = _controller(tester);
    final before = controller.hintsRemaining;
    expect(find.text('Hint $before'), findsOneWidget);

    // Not settled: a shown hint breathes for as long as it is on screen.
    await tester.tap(find.text('Hint $before'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(controller.hintsRemaining, before - 1);
    expect(controller.hint, isNotNull);
    expect(find.text('Hint ${before - 1}'), findsOneWidget);
  });

  testWidgets('pause covers the board and lets go again', (tester) async {
    await _launch(tester);
    await tester.tap(find.text('Infinite Hunt'));
    await tester.pumpAndSettle();

    final controller = _controller(tester);
    await _playHintedMove(tester, controller);
    final score = controller.score;

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsNothing);
    expect(_controller(tester).score, score, reason: 'the run is untouched');
  });

  testWidgets('settings live on their own screen', (tester) async {
    await _launch(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Reduced motion'), findsOneWidget);
    expect(find.text('Performance mode'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Infinite Hunt'), findsOneWidget);
  });

  testWidgets('the results screen reports the run', (tester) async {
    await _launch(tester);
    await _openMode(tester, 'Clear the Board');

    final controller = _controller(tester);
    // Level 1 is a 3x3 cleared in two moves, so the banner is a few taps away.
    for (var i = 0; i < 6 && !controller.isOver; i++) {
      if (!await _playHintedMove(tester, controller)) break;
    }
    // The banner waits for the board to settle, then half a second more.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('BEST CHAIN'), findsOneWidget);
    expect(find.text('LONGEST LINE'), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('MOVES'), findsOneWidget);
    // Clear the Board has no powers, so it must not claim any.
    expect(find.text('POWERS'), findsNothing);
  });

  testWidgets('a run survives leaving the game and coming back', (
    tester,
  ) async {
    await _launch(tester);
    await tester.tap(find.text('Infinite Hunt'));
    await tester.pumpAndSettle();

    final controller = _controller(tester);
    await _playHintedMove(tester, controller);
    final score = controller.score;
    final moves = controller.movesMade;
    final board = controller.board.toSketch();
    expect(moves, greaterThan(0));

    // Back to the home screen: the card should offer to carry on.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Continue'), findsWidgets);

    await tester.tap(find.text('Infinite Hunt'));
    await tester.pumpAndSettle();

    final resumed = _controller(tester);
    expect(resumed.score, score);
    expect(resumed.movesMade, moves);
    expect(
      resumed.board.toSketch(),
      board,
      reason: 'the same board should come back, tile for tile',
    );
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
/// Brings a mode card into view before touching it.
///
/// The home list is a lazy `ListView`, so a mode below the fold is not in the
/// widget tree at all — and with six modes on the menu, two of them start there
/// on a phone-shaped screen.
Future<Finder> _revealMode(WidgetTester tester, String mode) async {
  final card = find.text(mode);
  if (card.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      card,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
  return card;
}

Future<void> _openMode(WidgetTester tester, String mode) async {
  await tester.tap(await _revealMode(tester, mode));
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
