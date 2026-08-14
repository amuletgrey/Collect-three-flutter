import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/engine/models/tile.dart';
import 'package:tessera/skins/skin_registry.dart';
import 'package:tessera/ui/widgets/tile_view.dart';

/// Renders every power on every skin.
///
/// By default this just proves the markers paint. Golden images depend on the
/// host's rasterizer and fonts, so the comparison is opt-in — it would fail on
/// any machine but the one that generated it, CI included. To refresh the
/// reference picture in docs/images/powers.png:
///
///     flutter test --update-goldens --dart-define=preview_art=true \
///       test/skins/power_preview_test.dart
const bool _writeReference = bool.fromEnvironment('preview_art');

void main() {
  testWidgets('every power paints on every skin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ColoredBox(
          color: const Color(0xFF10131F),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final skin in SkinRegistry.all)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final power in TilePower.values)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: TileView(
                          art: skin.art(TilePower.values.indexOf(power)),
                          size: 72,
                          power: power,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TileView), findsNWidgets(3 * TilePower.values.length));

    if (_writeReference) {
      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('../../docs/images/powers.png'),
      );
    }
  });
}
