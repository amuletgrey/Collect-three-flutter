import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'skin.dart';
import 'skin_registry.dart';

/// Full-screen backdrop for the active skin.
///
/// Static by design: the decoration is painted once and never animates, which
/// keeps the reduced-motion setting honest and the board the only moving thing
/// on screen.
class SkinBackground extends StatelessWidget {
  const SkinBackground({
    required this.skin,
    required this.child,
    this.simplified = false,
    super.key,
  });

  final Skin skin;
  final Widget child;

  /// Performance mode: gradient only, no painted decoration.
  final bool simplified;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.palette.backgroundTop, skin.palette.backgroundBottom],
        ),
      ),
      child: simplified
          ? child
          : CustomPaint(painter: _BackdropPainter(skin), child: child),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.skin);

  final Skin skin;

  @override
  void paint(Canvas canvas, Size size) {
    switch (skin.id) {
      case SkinRegistry.classicArcadeId:
        _scanlines(canvas, size);
      case SkinRegistry.treasureHuntId:
        _torchGlow(canvas, size);
      case SkinRegistry.candyShopId:
        _stripes(canvas, size);
    }
  }

  void _scanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _torchGlow(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.28);
    canvas.drawCircle(
      centre,
      size.width * 0.8,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                skin.palette.accent.withValues(alpha: 0.16),
                skin.palette.accent.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: centre, radius: size.width * 0.8),
            ),
    );
  }

  void _stripes(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14FF5C8A)
      ..strokeWidth = size.width * 0.06;
    final diagonal = size.width + size.height;
    for (var i = -1.0; i * paint.strokeWidth * 2 < diagonal; i++) {
      final offset = i * paint.strokeWidth * 2;
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(offset + size.height, 0),
        paint,
      );
    }
    // A few soft bokeh dots, seeded so they never dance between rebuilds.
    final random = math.Random(7);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        size.width * (0.01 + random.nextDouble() * 0.03),
        Paint()..color = const Color(0x22FFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.skin.id != skin.id;
}
