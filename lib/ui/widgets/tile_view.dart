import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:tessera/engine/models/tile.dart';

import '../../skins/skin.dart';
import '../../skins/tile_painter.dart';

/// One tile, drawn by the active skin.
///
/// The collect animation lives here rather than in the controller: the
/// controller says *that* a tile is being collected, this decides how the pop
/// looks.
class TileView extends StatelessWidget {
  const TileView({
    required this.art,
    required this.size,
    this.selected = false,
    this.hinted = false,
    this.clearing = false,
    this.rejected = false,
    this.power = TilePower.none,
    this.firing = false,
    this.hintPulse = 0,
    this.hintColour,
    this.showSymbols = false,
    this.lowSpec = false,
    this.clearDuration = const Duration(milliseconds: 240),
    super.key,
  });

  final TileArt art;
  final double size;
  final bool selected;
  final bool hinted;
  final bool clearing;
  final bool rejected;
  final TilePower power;
  final bool firing;
  final double hintPulse;
  final Color? hintColour;
  final bool showSymbols;
  final bool lowSpec;
  final Duration clearDuration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // A couple of quick sideways swings: unmistakably "no", and short enough
      // not to slow the player down.
      tween: Tween<double>(begin: 0, end: rejected ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      builder: (context, wiggle, child) => Transform.translate(
        offset: Offset(
          math.sin(wiggle * math.pi * 3) * size * 0.08 * (1 - wiggle),
          0,
        ),
        child: child,
      ),
      child: _paintedTile(),
    );
  }

  Widget _paintedTile() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: clearing ? 1 : 0),
      duration: clearDuration,
      curve: Curves.easeOut,
      builder: (context, progress, _) => CustomPaint(
        size: Size.square(size),
        painter: TilePainter(
          art: art,
          state: TileVisualState(
            selected: selected,
            hinted: hinted,
            clearProgress: progress,
            showSymbols: showSymbols,
            lowSpec: lowSpec,
            power: power,
            firing: firing,
            hintPulse: hintPulse,
            hintColour: hintColour,
          ),
        ),
      ),
    );
  }
}
