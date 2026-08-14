import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessera/app_settings.dart';
import 'package:tessera/engine/engine.dart';
import 'package:tessera/services/storage_service.dart';
import 'package:tessera/ui/screens/game_screen.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.open();
  return AppSettingsScope(
    notifier: AppSettings(storage),
    child: MaterialApp(home: GameScreen(modeId: ModeRegistry.infiniteHuntId)),
  );
}

/// Pumped by hand rather than settled: a shown hint breathes forever, so
/// `pumpAndSettle` would sit there until it timed out.
Future<void> _tapHint(WidgetTester tester) async {
  await tester.tap(find.textContaining('Hint'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('the button shows how many hints are left', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.text('Hint 3'), findsOneWidget);
  });

  testWidgets('each hint spent comes off the count', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await _tapHint(tester);
    expect(find.text('Hint 2'), findsOneWidget);

    await _tapHint(tester);
    expect(find.text('Hint 1'), findsOneWidget);
  });

  testWidgets('an exhausted budget disables the button', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await _tapHint(tester);
    }
    expect(find.text('Hint 0'), findsOneWidget);

    // Tapping again must not go negative — the button is inert, not a debt.
    await _tapHint(tester);
    expect(find.text('Hint 0'), findsOneWidget);
  });
}
