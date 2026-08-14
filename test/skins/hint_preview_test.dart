import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/skins/skin_registry.dart';
import 'package:tessera/ui/widgets/tile_view.dart';

/// Renders the hint ring on every skin, at both ends of its pulse.
///
/// Same deal as power_preview_test: the comparison is opt-in because goldens
/// depend on the host rasterizer. To refresh docs/images/hints.png:
///
///     flutter test --update-goldens --dart-define=preview_art=true \
///       test/skins/hint_preview_test.dart
const bool _writeReference = bool.fromEnvironment('preview_art');

void main() {
  testWidgets('the hint ring paints on every skin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final skin in SkinRegistry.all)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    skin.palette.boardCell,
                    skin.palette.backgroundBottom,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The lightest and darkest kind in each skin, which is
                    // where a single-colour ring would fail.
                    for (final kind in [0, 4, 5, 6])
                      for (final pulse in [0.0, 0.5])
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TileView(
                            art: skin.art(kind),
                            size: 64,
                            hinted: true,
                            hintPulse: pulse,
                            hintColour: skin.palette.hint,
                          ),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    if (_writeReference) {
      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('../../docs/images/hints.png'),
      );
    }
  });
}
