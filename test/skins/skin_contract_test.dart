import 'dart:math' as math;
import 'dart:ui';

import 'package:collect_three/engine/models/tile.dart';
import 'package:collect_three/skins/skin.dart';
import 'package:collect_three/skins/skin_registry.dart';
import 'package:collect_three/skins/tile_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Relative luminance, WCAG style.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('every registered skin', () {
    for (final skin in SkinRegistry.all) {
      group(skin.name, () {
        test('covers seven kinds with unique names', () {
          expect(skin.kinds.length, greaterThanOrEqualTo(7));
          expect(
            skin.kinds.map((k) => k.name).toSet(),
            hasLength(skin.kinds.length),
          );
        });

        test('is readable without colour', () {
          final shapes = skin.kinds.map((k) => k.shape).toSet();
          final symbols = skin.kinds.map((k) => k.symbol).toSet();
          expect(
            shapes.length >= skin.kinds.length ||
                (skin.supportsSymbols && symbols.length >= skin.kinds.length),
            isTrue,
            reason: 'kinds must differ by silhouette or by symbol',
          );
        });

        test('separates tiles from the cells they sit on', () {
          // Tiles are drawn on board cells, not on the raw background, so the
          // cell tint is composited before measuring.
          final cell = Color.alphaBlend(
            skin.palette.boardCell,
            skin.palette.backgroundBottom,
          );
          for (final art in skin.kinds) {
            expect(
              _contrast(art.primary, cell),
              greaterThanOrEqualTo(1.5),
              reason: '${art.name} disappears into the board',
            );
          }
        });

        test('keeps every pair of kinds visibly different', () {
          for (var a = 0; a < skin.kinds.length; a++) {
            for (var b = a + 1; b < skin.kinds.length; b++) {
              final first = skin.kinds[a];
              final second = skin.kinds[b];
              final distance = math.sqrt(
                math.pow((first.primary.r - second.primary.r) * 255, 2) +
                    math.pow((first.primary.g - second.primary.g) * 255, 2) +
                    math.pow((first.primary.b - second.primary.b) * 255, 2),
              );
              expect(
                distance,
                greaterThanOrEqualTo(60),
                reason: '${first.name} and ${second.name} look alike',
              );
            }
          }
        });

        test('spreads its kinds across the luminance range', () {
          final luminances =
              skin.kinds.map((k) => _luminance(k.primary)).toList()..sort();
          expect(
            luminances.last - luminances.first,
            greaterThan(0.12),
            reason: 'a greyscale screenshot must stay playable',
          );
        });

        test('paints every kind and state without throwing', () {
          for (var kind = 0; kind < skin.kinds.length; kind++) {
            for (final state in const [
              TileVisualState(),
              TileVisualState(selected: true),
              TileVisualState(hinted: true),
              TileVisualState(clearProgress: 0.5, showSymbols: true),
              TileVisualState(clearProgress: 1),
              TileVisualState(power: TilePower.clearRow),
              TileVisualState(power: TilePower.clearColumn),
              TileVisualState(power: TilePower.bomb),
              TileVisualState(power: TilePower.colourBomb),
              TileVisualState(power: TilePower.bomb, firing: true),
              TileVisualState(power: TilePower.colourBomb, lowSpec: true),
            ]) {
              for (final size in const [Size(24, 24), Size(64, 64)]) {
                final recorder = PictureRecorder();
                TilePainter(
                  art: skin.art(kind),
                  state: state,
                ).paint(Canvas(recorder), size);
                recorder.endRecording().dispose();
              }
            }
          }
        });
      });
    }
  });

  test('unknown skin ids fall back to the default', () {
    expect(SkinRegistry.byId('nope').id, SkinRegistry.defaultSkin.id);
    expect(
      SkinRegistry.byId(SkinRegistry.candyShopId).id,
      SkinRegistry.candyShopId,
    );
  });
}
