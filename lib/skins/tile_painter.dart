import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../engine/models/tile.dart';
import 'skin.dart';
import 'tile_shapes.dart';

/// Draws one tile for any skin.
///
/// A single painter covers all three skins because they differ in silhouette,
/// palette and lighting, not in structure. Adding a skin is therefore data plus
/// (at most) a new shape, never a new painter class.
class TilePainter extends CustomPainter {
  const TilePainter({required this.art, required this.state});

  final TileArt art;
  final TileVisualState state;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    ).deflate(side * 0.06);

    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..scale(state.scale)
      ..translate(-rect.center.dx, -rect.center.dy);

    final opacity = state.opacity.clamp(0.0, 1.0);
    if (state.selected) _paintSelection(canvas, rect);
    if (state.hinted && !state.selected) _paintHint(canvas, rect);

    _paintShadow(canvas, rect, opacity);
    if (state.isRelic) {
      _paintRelic(canvas, rect, opacity);
      canvas.restore();
      return;
    }
    switch (art.family) {
      case TileFamily.sphere:
        _paintSphere(canvas, rect, opacity);
      case TileFamily.gem:
        _paintGem(canvas, rect, opacity);
      case TileFamily.candy:
        _paintCandy(canvas, rect, opacity);
    }
    if (state.power != TilePower.none) {
      _paintPower(canvas, rect, opacity);
    }
    if (state.firing) {
      canvas.drawCircle(
        rect.center,
        rect.width * 0.62,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75),
      );
    }
    if (state.showSymbols && art.symbol != TileSymbol.none) {
      canvas.drawPath(
        TileShapes.symbol(art.symbol, rect),
        Paint()
          ..color = const Color(0xFF101020).withValues(alpha: 0.55 * opacity),
      );
    }

    canvas.restore();
  }

  void _paintShadow(Canvas canvas, Rect rect, double opacity) {
    canvas.drawOval(
      Rect.fromCenter(
        center: rect.center.translate(0, rect.height * 0.42),
        width: rect.width * 0.72,
        height: rect.height * 0.16,
      ),
      Paint()
        ..color = const Color(
          0xFF000000,
        ).withValues(alpha: (state.lowSpec ? 0.14 : 0.22) * opacity)
        ..maskFilter = state.lowSpec
            ? null
            : MaskFilter.blur(BlurStyle.normal, rect.width * 0.06),
    );
  }

  void _paintSphere(Canvas canvas, Rect rect, double opacity) {
    final body = TileShapes.path(art.shape, rect);
    canvas
      ..drawPath(
        body,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 0.95,
            colors: [
              art.secondary.withValues(alpha: opacity),
              art.primary.withValues(alpha: opacity),
              _darken(art.primary, 0.35).withValues(alpha: opacity),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(rect),
      )
      // Specular highlight: the whole reason a ball reads as glossy.
      ..drawOval(
        Rect.fromCenter(
          center: rect.center.translate(-rect.width * 0.17, -rect.height * 0.2),
          width: rect.width * 0.3,
          height: rect.height * 0.22,
        ),
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * opacity)
          ..maskFilter = state.lowSpec
              ? null
              : MaskFilter.blur(BlurStyle.normal, rect.width * 0.04),
      )
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.035
          ..color = _darken(art.primary, 0.45).withValues(alpha: 0.5 * opacity),
      );
  }

  void _paintGem(Canvas canvas, Rect rect, double opacity) {
    final body = TileShapes.path(art.shape, rect);
    canvas
      ..drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              art.secondary.withValues(alpha: opacity),
              art.primary.withValues(alpha: opacity),
              _darken(art.primary, 0.4).withValues(alpha: opacity),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(rect),
      )
      // Crown facets: a bright wedge and a dark one give the stone depth.
      ..save()
      ..clipPath(body)
      ..drawPath(
        Path()
          ..moveTo(rect.left, rect.top + rect.height * 0.32)
          ..lineTo(rect.center.dx, rect.top + rect.height * 0.05)
          ..lineTo(rect.right, rect.top + rect.height * 0.32)
          ..lineTo(rect.center.dx, rect.center.dy)
          ..close(),
        Paint()..color = art.secondary.withValues(alpha: 0.75 * opacity),
      )
      ..drawPath(
        Path()
          ..moveTo(rect.left, rect.top + rect.height * 0.32)
          ..lineTo(rect.center.dx, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..close(),
        Paint()
          ..color = _darken(art.primary, 0.25).withValues(alpha: 0.8 * opacity),
      )
      ..restore()
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.045
          ..color = const Color(0xFFC9A227).withValues(alpha: 0.9 * opacity),
      );
  }

  void _paintCandy(Canvas canvas, Rect rect, double opacity) {
    final body = TileShapes.path(art.shape, rect);
    canvas
      ..drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lighten(art.primary, 0.25).withValues(alpha: opacity),
              art.primary.withValues(alpha: opacity),
              _darken(art.primary, 0.22).withValues(alpha: opacity),
            ],
          ).createShader(rect),
      )
      ..save()
      ..clipPath(body);

    switch (art.shape) {
      case TileShape.lollipop:
        _paintSwirl(canvas, rect, opacity);
      case TileShape.peppermint:
        _paintPinwheel(canvas, rect, opacity);
      case TileShape.liquorice:
        _paintRings(canvas, rect, opacity);
      case TileShape.chocolate:
        _paintChocolateGrid(canvas, rect, opacity);
      case TileShape.wrapped:
        _paintStripes(canvas, rect, opacity);
      case TileShape.candyCane:
        _paintStripes(canvas, rect, opacity);
      case TileShape.citrusSlice:
        _paintSegments(canvas, rect, opacity);
      default:
        break;
    }

    canvas
      ..restore()
      // Soft specular arc sells the sugary coating.
      ..drawArc(
        Rect.fromCenter(
          center: rect.center.translate(0, -rect.height * 0.06),
          width: rect.width * 0.62,
          height: rect.height * 0.62,
        ),
        math.pi * 1.15,
        math.pi * 0.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = rect.width * 0.08
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6 * opacity),
      )
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.03
          ..color = _darken(art.primary, 0.35).withValues(alpha: 0.4 * opacity),
      );
  }

  void _paintSwirl(Canvas canvas, Rect rect, double opacity) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.11
      ..strokeCap = StrokeCap.round
      ..color = art.secondary.withValues(alpha: opacity);
    final path = Path();
    for (var i = 0; i <= 60; i++) {
      final t = i / 60;
      final angle = t * math.pi * 3.4;
      final radius = rect.width * 0.44 * t;
      final point = rect.center.translate(
        radius * math.cos(angle),
        radius * math.sin(angle),
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintPinwheel(Canvas canvas, Rect rect, double opacity) {
    final paint = Paint()..color = art.secondary.withValues(alpha: opacity);
    for (var i = 0; i < 6; i++) {
      final start = i * math.pi / 3;
      canvas.drawPath(
        Path()
          ..moveTo(rect.center.dx, rect.center.dy)
          ..arcTo(rect, start, math.pi / 6, false)
          ..close(),
        paint,
      );
    }
  }

  void _paintRings(Canvas canvas, Rect rect, double opacity) {
    for (var i = 3; i > 0; i--) {
      canvas.drawCircle(
        rect.center,
        rect.width * 0.14 * i,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.07
          ..color = (i.isEven ? art.secondary : art.primary).withValues(
            alpha: opacity,
          ),
      );
    }
  }

  void _paintChocolateGrid(Canvas canvas, Rect rect, double opacity) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.045
      ..color = art.secondary.withValues(alpha: 0.8 * opacity);
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas
        ..drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint)
        ..drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void _paintStripes(Canvas canvas, Rect rect, double opacity) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.09
      ..color = art.secondary.withValues(alpha: opacity);
    for (var i = -2; i <= 2; i++) {
      final offset = i * rect.width * 0.2;
      canvas.drawLine(
        Offset(rect.left + offset, rect.bottom),
        Offset(rect.left + offset + rect.width * 0.5, rect.top),
        paint,
      );
    }
  }

  /// Wedges radiating from the flat edge — the inside of a fruit slice.
  void _paintSegments(Canvas canvas, Rect rect, double opacity) {
    final origin = rect.center.translate(0, rect.height * 0.12);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.05
      ..color = art.secondary.withValues(alpha: 0.95 * opacity);
    for (var i = 1; i < 5; i++) {
      final angle = math.pi + i * math.pi / 5;
      canvas.drawLine(
        origin,
        origin.translate(
          math.cos(angle) * rect.width * 0.5,
          math.sin(angle) * rect.height * 0.7,
        ),
        paint,
      );
    }
    canvas.drawArc(
      Rect.fromCenter(
        center: origin,
        width: rect.width * 0.82,
        height: rect.height * 1.2,
      ),
      math.pi,
      math.pi,
      false,
      paint..strokeWidth = rect.width * 0.045,
    );
  }

  /// Markers for the powers. Deliberately drawn in white with a dark rim so
  /// they read on top of any skin's artwork rather than needing per-skin art.
  void _paintPower(Canvas canvas, Rect rect, double opacity) {
    final white = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.92 * opacity);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.045
      ..color = const Color(0xFF101020).withValues(alpha: 0.55 * opacity);

    switch (state.power) {
      case TilePower.none:
        return;
      case TilePower.clearRow:
      case TilePower.clearColumn:
        // A bar with arrowheads, pointing the way the blast travels.
        final horizontal = state.power == TilePower.clearRow;
        canvas
          ..save()
          ..translate(rect.center.dx, rect.center.dy);
        if (!horizontal) canvas.rotate(math.pi / 2);
        canvas.translate(-rect.center.dx, -rect.center.dy);

        final bar = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: rect.width * 0.66,
            height: rect.height * 0.18,
          ),
          Radius.circular(rect.height * 0.1),
        );
        canvas
          ..drawRRect(bar, white)
          ..drawRRect(bar, rim);
        for (final sign in [-1.0, 1.0]) {
          final tip = rect.center.dx + sign * rect.width * 0.38;
          final base = rect.center.dx + sign * rect.width * 0.24;
          final head = Path()
            ..moveTo(tip, rect.center.dy)
            ..lineTo(base, rect.center.dy - rect.height * 0.17)
            ..lineTo(base, rect.center.dy + rect.height * 0.17)
            ..close();
          canvas
            ..drawPath(head, white)
            ..drawPath(head, rim);
        }
        canvas.restore();
      case TilePower.bomb:
        // A spiked ring: a blast that goes outwards in every direction.
        final star = Path();
        for (var i = 0; i < 16; i++) {
          final radius = rect.width * (i.isEven ? 0.28 : 0.16);
          final angle = i * math.pi / 8;
          final point = rect.center.translate(
            radius * math.cos(angle),
            radius * math.sin(angle),
          );
          i == 0
              ? star.moveTo(point.dx, point.dy)
              : star.lineTo(point.dx, point.dy);
        }
        star.close();
        canvas
          ..drawPath(star, white)
          ..drawPath(star, rim);
      case TilePower.colourBomb:
        // Concentric rings: it takes a whole colour, not a direction.
        for (var i = 3; i >= 1; i--) {
          canvas.drawCircle(
            rect.center,
            rect.width * 0.11 * i,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = rect.width * 0.06
              ..color =
                  (i.isOdd ? const Color(0xFFFFFFFF) : const Color(0xFF101020))
                      .withValues(alpha: 0.9 * opacity),
          );
        }
    }
  }

  /// A stone-set artefact: heavy, obviously not one of the colours, and the
  /// same on every skin so a player never has to re-learn what cargo looks like.
  void _paintRelic(Canvas canvas, Rect rect, double opacity) {
    const stone = Color(0xFF6B6357);
    const gold = Color(0xFFE8C36B);

    final block = RRect.fromRectAndRadius(
      rect.deflate(rect.width * 0.06),
      Radius.circular(rect.width * 0.16),
    );
    canvas
      ..drawRRect(
        block,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lighten(stone, 0.22).withValues(alpha: opacity),
              stone.withValues(alpha: opacity),
              _darken(stone, 0.3).withValues(alpha: opacity),
            ],
          ).createShader(rect),
      )
      ..drawRRect(
        block,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.05
          ..color = gold.withValues(alpha: 0.85 * opacity),
      );

    // A gem seated in the stone, so it reads as treasure rather than a wall.
    final gem = Path();
    final centre = rect.center;
    final radius = rect.width * 0.2;
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final point = Offset(
        centre.dx + radius * math.cos(angle),
        centre.dy + radius * math.sin(angle),
      );
      i == 0 ? gem.moveTo(point.dx, point.dy) : gem.lineTo(point.dx, point.dy);
    }
    gem.close();
    canvas
      ..drawPath(gem, Paint()..color = gold.withValues(alpha: opacity))
      ..drawPath(
        gem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.03
          ..color = _darken(gold, 0.45).withValues(alpha: opacity),
      );
  }

  void _paintSelection(Canvas canvas, Rect rect) {
    canvas.drawCircle(
      rect.center,
      rect.width * 0.62,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.22)
        ..maskFilter = state.lowSpec
            ? null
            : MaskFilter.blur(BlurStyle.normal, rect.width * 0.12),
    );
  }

  /// A breathing ring in the skin's hint colour, with a soft glow behind it.
  ///
  /// The pulse matters as much as the colour: a static ring reads as decoration,
  /// a moving one reads as "look here".
  void _paintHint(Canvas canvas, Rect rect) {
    final colour = state.hintColour ?? const Color(0xFFFFFFFF);
    // Ease the 0..1 sawtooth into a there-and-back swell.
    final swell = math.sin(state.hintPulse * math.pi);
    final radius = rect.width * (0.5 + 0.07 * swell);

    if (!state.lowSpec) {
      canvas.drawCircle(
        rect.center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.16
          ..color = colour.withValues(alpha: 0.16 + 0.22 * swell)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * 0.09),
      );
    }
    // The ring is bracketed by a light and a dark edge. No single colour can
    // contrast with both the lightest and the darkest tile in a skin, but one
    // of these two edges always shows whatever it lands on.
    canvas
      ..drawCircle(
        rect.center,
        radius + rect.width * 0.04,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.022
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75),
      )
      ..drawCircle(
        rect.center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.06
          ..color = colour.withValues(alpha: 0.9),
      )
      ..drawCircle(
        rect.center,
        radius - rect.width * 0.04,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.022
          ..color = const Color(0xFF101020).withValues(alpha: 0.6),
      );
  }

  static Color _darken(Color color, double amount) =>
      Color.lerp(color, const Color(0xFF000000), amount)!;

  static Color _lighten(Color color, double amount) =>
      Color.lerp(color, const Color(0xFFFFFFFF), amount)!;

  @override
  bool shouldRepaint(TilePainter old) =>
      old.art != art ||
      old.state.selected != state.selected ||
      old.state.hinted != state.hinted ||
      old.state.hintPulse != state.hintPulse ||
      old.state.hintColour != state.hintColour ||
      old.state.showSymbols != state.showSymbols ||
      old.state.lowSpec != state.lowSpec ||
      old.state.power != state.power ||
      old.state.isRelic != state.isRelic ||
      old.state.firing != state.firing ||
      old.state.clearProgress != state.clearProgress;
}
