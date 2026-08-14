import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessera/app_settings.dart';
import 'package:tessera/engine/engine.dart';
import 'package:tessera/services/storage_service.dart';
import 'package:tessera/ui/screens/game_screen.dart';
import 'package:tessera/ui/widgets/board_view.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.open();
  return AppSettingsScope(
    notifier: AppSettings(storage),
    child: MaterialApp(home: GameScreen(modeId: ModeRegistry.infiniteHuntId)),
  );
}

/// The board should get the space; the chrome should get out of its way.
double _boardSide(WidgetTester tester) {
  final grid = tester.getRect(find.byKey(BoardView.gridKey));
  return grid.width;
}

void main() {
  testWidgets('a tall screen stacks the chrome above and below', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(BoardView.gridKey));
    final hud = tester.getRect(find.text('SCORE'));
    expect(hud.bottom, lessThan(board.top), reason: 'readouts sit above');
    expect(find.text('Hint'), findsOneWidget);
  });

  testWidgets('a wide screen puts readouts left and controls right', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(BoardView.gridKey));
    final score = tester.getRect(find.text('SCORE'));
    final hint = tester.getRect(find.text('Hint'));

    expect(score.right, lessThanOrEqualTo(board.left));
    expect(hint.left, greaterThanOrEqualTo(board.right));
    // Pause and skins move into the right-hand column with no top bar.
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Skin'), findsOneWidget);
  });

  testWidgets('the board is bigger in landscape than it was before', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(2400, 1080);
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();
    final wide = _boardSide(tester);

    // Half the height would be left for the board if the chrome still sat
    // above and below it; the side layout must beat that comfortably.
    expect(wide, greaterThan(1080 / 2 / 2));
  });
}
