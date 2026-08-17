import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/skins/skin_registry.dart';
import 'package:tessera/ui/widgets/tile_view.dart';

/// Renders every kind of every skin, each on its own board colour.
///
/// The last two of the nine only appear deep into an Infinite Hunt run, so
/// they are the ones least likely to be looked at by accident — this is where
/// you look at them. As with the other previews, the golden comparison is
/// opt-in because goldens depend on the host rasterizer:
///
///     flutter test --update-goldens --dart-define=preview_art=true \
///       test/skins/palette_preview_test.dart
const bool _writeReference = bool.fromEnvironment('preview_art');

void main() {
  testWidgets('every kind paints on every skin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final skin in SkinRegistry.all)
              ColoredBox(
                color: skin.palette.backgroundBottom,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var kind = 0; kind < skin.kinds.length; kind++)
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: skin.palette.boardCell,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: TileView(art: skin.art(kind), size: 56),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byType(TileView),
      findsNWidgets(
        [
          for (final skin in SkinRegistry.all) skin.kinds.length,
        ].reduce((a, b) => a + b),
      ),
    );

    if (_writeReference) {
      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('../../docs/images/palette.png'),
      );
    }
  });
}
