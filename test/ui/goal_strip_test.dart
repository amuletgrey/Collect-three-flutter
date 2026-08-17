import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessera/app_settings.dart';
import 'package:tessera/engine/engine.dart';
import 'package:tessera/services/storage_service.dart';
import 'package:tessera/ui/screens/game_screen.dart';
import 'package:tessera/ui/widgets/hud.dart';

Future<Widget> _app(String modeId) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.open();
  return AppSettingsScope(
    notifier: AppSettings(storage),
    child: MaterialApp(home: GameScreen(modeId: modeId)),
  );
}

void main() {
  testWidgets('Work Order draws a chip per line of the order', (tester) async {
    await tester.pumpWidget(await _app(ModeRegistry.workOrderId));
    await tester.pumpAndSettle();

    final mode = ModeRegistry.create(ModeRegistry.workOrderId) as WorkOrderMode;
    // Every order is the same shape, whatever the seed rolled.
    expect(find.textContaining('/'), findsWidgets);
    expect(find.text('MOVES LEFT'), findsOneWidget);
    expect(mode.goals, isEmpty, reason: 'a mode deals its order with a board');
  });

  testWidgets('a run with nothing to tick off draws no chips', (tester) async {
    await tester.pumpWidget(await _app(ModeRegistry.infiniteHuntId));
    await tester.pumpAndSettle();

    // The strip is in the tree for every mode; with no goals it renders
    // nothing, so the board keeps the space.
    expect(find.byType(GoalStrip), findsWidgets);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('Creeping Rot counts the rot against its limit', (tester) async {
    await tester.pumpWidget(await _app(ModeRegistry.creepingRotId));
    await tester.pumpAndSettle();

    final mode =
        ModeRegistry.create(ModeRegistry.creepingRotId) as CreepingRotMode;
    expect(find.text('ROT'), findsOneWidget);
    expect(find.text('0 / ${mode.rotCapacity}'), findsOneWidget);
  });
}
