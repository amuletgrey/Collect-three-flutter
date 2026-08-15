import 'package:flutter/widgets.dart';

import '../engine/models/tile.dart';

/// Which painter family draws a tile. The family decides the lighting and
/// decoration; [TileShape] decides the silhouette.
enum TileFamily { sphere, gem, candy }

enum TileShape {
  // Classic Arcade
  sphere,
  // Treasure Hunt
  roundBrilliant,
  emeraldCut,
  marquise,
  trillion,
  pear,
  heart,
  kite,
  cabochon,
  starCut,
  // Candy Shop
  lollipop,
  wrapped,
  jellyBean,
  gumdrop,
  peppermint,
  chocolate,
  liquorice,
  candyCane,
  citrusSlice,
}

/// Optional accessibility stamp, used by skins whose kinds share a silhouette.
enum TileSymbol {
  none,
  dot,
  cross,
  triangle,
  star,
  square,
  ring,
  diamond,
  hexagon,
  chevron,
}

/// Artwork for one tile kind.
class TileArt {
  const TileArt({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.family,
    required this.shape,
    this.symbol = TileSymbol.none,
  });

  /// Spoken by screen readers and shown in the skin gallery.
  final String name;
  final Color primary;
  final Color secondary;
  final TileFamily family;
  final TileShape shape;
  final TileSymbol symbol;
}

/// Everything a skin colours besides the tiles themselves.
class SkinPalette {
  const SkinPalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.boardFrame,
    required this.boardCell,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.danger,
    required this.hint,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color boardFrame;
  final Color boardCell;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  /// Tint for the Rising Tide danger rows and for losing states.
  final Color danger;

  /// The hint ring. Needs its own colour rather than borrowing the accent:
  /// on a pale skin a white ring vanishes into white tiles, which is exactly
  /// what happened on Candy Shop.
  final Color hint;
}

/// How a tile should be drawn right now.
class TileVisualState {
  const TileVisualState({
    this.selected = false,
    this.hinted = false,
    this.clearProgress = 0,
    this.showSymbols = false,
    this.lowSpec = false,
    this.power = TilePower.none,
    this.firing = false,
    this.hintPulse = 0,
    this.hintColour,
    this.isRelic = false,
  });

  final bool selected;
  final bool hinted;

  /// 0 = untouched, 1 = fully collected. Drives the pop-and-fade.
  final double clearProgress;

  /// Accessibility setting: stamp glyphs on kinds that share a silhouette.
  final bool showSymbols;

  /// Performance mode: drop the blurred shadow and highlight. Blur mask filters
  /// are the most expensive thing on the board and the first thing to go on an
  /// older GPU.
  final bool lowSpec;

  /// The power this tile carries, drawn as a marker over the skin's artwork.
  final TilePower power;

  /// True for the instant a power is going off.
  final bool firing;

  /// 0..1, cycled by the board so the hint breathes instead of sitting still.
  final double hintPulse;

  /// Supplied by the skin; the painter has no palette of its own.
  final Color? hintColour;

  /// Cargo in Relic Dig. Drawn as one artefact across every skin, because it is
  /// a game object rather than a colour the player matches.
  final bool isRelic;

  /// Swells briefly, then shrinks away — the collect "pop".
  double get scale {
    if (clearProgress <= 0) return 1;
    if (clearProgress < 0.4) return 1 + 0.15 * (clearProgress / 0.4);
    return 1.15 - 0.75 * ((clearProgress - 0.4) / 0.6);
  }

  double get opacity =>
      clearProgress < 0.4 ? 1 : 1 - (clearProgress - 0.4) / 0.6;
}

/// A complete look for the game. Skins never change the rules — see
/// docs/SKINS.md for the contract and the accessibility requirements.
class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.tagline,
    required this.palette,
    required this.kinds,
    this.supportsSymbols = false,
  });

  final String id;
  final String name;
  final String tagline;
  final SkinPalette palette;

  /// Index matches the engine's tile kind. Must cover 9 kinds — the skin
  /// contract test enforces it, since a const constructor cannot.
  final List<TileArt> kinds;

  /// True when kinds share a silhouette and need glyphs to stay distinct.
  final bool supportsSymbols;

  TileArt art(int kind) => kinds[kind % kinds.length];
}
