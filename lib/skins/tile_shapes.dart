import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'skin.dart';

/// Silhouettes for every tile shape, built inside a unit-ish [rect].
///
/// Shapes are what make a skin readable without colour, so each one is
/// deliberately distinct at small sizes — see docs/SKINS.md.
class TileShapes {
  const TileShapes._();

  static Path path(TileShape shape, Rect r) {
    switch (shape) {
      case TileShape.sphere:
      case TileShape.peppermint:
      case TileShape.liquorice:
        return Path()..addOval(r);
      case TileShape.roundBrilliant:
        return _polygon(r, 8, rotation: math.pi / 8);
      case TileShape.emeraldCut:
        return _cutRect(r);
      case TileShape.marquise:
        return _marquise(r);
      case TileShape.trillion:
        return _polygon(r, 3, rotation: -math.pi / 2);
      case TileShape.pear:
        return _pear(r);
      case TileShape.heart:
        return _heart(r);
      case TileShape.kite:
        return _polygon(r, 4, rotation: -math.pi / 2);
      case TileShape.lollipop:
        return Path()..addOval(r.deflate(r.width * 0.04));
      case TileShape.wrapped:
        return _wrapped(r);
      case TileShape.jellyBean:
        return _jellyBean(r);
      case TileShape.gumdrop:
        return _gumdrop(r);
      case TileShape.chocolate:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            r.deflate(r.width * 0.04),
            Radius.circular(r.width * 0.14),
          ),
        );
    }
  }

  static Path _polygon(Rect r, int sides, {double rotation = 0}) {
    final path = Path();
    final radius = r.shortestSide / 2;
    for (var i = 0; i < sides; i++) {
      final angle = rotation + i * 2 * math.pi / sides;
      final point = Offset(
        r.center.dx + radius * math.cos(angle),
        r.center.dy + radius * math.sin(angle),
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  /// Step cut: a rectangle with its corners sliced off.
  static Path _cutRect(Rect r) {
    final inset = r.width * 0.18;
    final box = r.deflate(r.width * 0.06);
    return Path()
      ..moveTo(box.left + inset, box.top)
      ..lineTo(box.right - inset, box.top)
      ..lineTo(box.right, box.top + inset)
      ..lineTo(box.right, box.bottom - inset)
      ..lineTo(box.right - inset, box.bottom)
      ..lineTo(box.left + inset, box.bottom)
      ..lineTo(box.left, box.bottom - inset)
      ..lineTo(box.left, box.top + inset)
      ..close();
  }

  /// Pointed oval: two arcs meeting at top and bottom.
  static Path _marquise(Rect r) {
    final box = r.deflate(r.width * 0.04);
    return Path()
      ..moveTo(box.center.dx, box.top)
      ..quadraticBezierTo(box.right, box.center.dy, box.center.dx, box.bottom)
      ..quadraticBezierTo(box.left, box.center.dy, box.center.dx, box.top)
      ..close();
  }

  static Path _pear(Rect r) {
    final box = r.deflate(r.width * 0.06);
    final belly = box.top + box.height * 0.45;
    return Path()
      ..moveTo(box.center.dx, box.top)
      ..quadraticBezierTo(
        box.right,
        belly,
        box.right - box.width * 0.12,
        box.bottom - box.height * 0.18,
      )
      ..quadraticBezierTo(
        box.center.dx,
        box.bottom + box.height * 0.06,
        box.left + box.width * 0.12,
        box.bottom - box.height * 0.18,
      )
      ..quadraticBezierTo(box.left, belly, box.center.dx, box.top)
      ..close();
  }

  static Path _heart(Rect r) {
    final box = r.deflate(r.width * 0.06);
    final w = box.width;
    final h = box.height;
    return Path()
      ..moveTo(box.center.dx, box.bottom)
      ..cubicTo(
        box.left - w * 0.05,
        box.top + h * 0.55,
        box.left + w * 0.12,
        box.top - h * 0.08,
        box.center.dx,
        box.top + h * 0.22,
      )
      ..cubicTo(
        box.right - w * 0.12,
        box.top - h * 0.08,
        box.right + w * 0.05,
        box.top + h * 0.55,
        box.center.dx,
        box.bottom,
      )
      ..close();
  }

  /// Hard candy: a disc with twisted wrapper ends.
  static Path _wrapped(Rect r) {
    final core = Rect.fromCenter(
      center: r.center,
      width: r.width * 0.62,
      height: r.height * 0.62,
    );
    final path = Path()..addOval(core);
    for (final sign in [-1.0, 1.0]) {
      final tipX = r.center.dx + sign * r.width * 0.48;
      final baseX = r.center.dx + sign * r.width * 0.29;
      path
        ..moveTo(baseX, r.center.dy - r.height * 0.1)
        ..lineTo(tipX, r.center.dy - r.height * 0.24)
        ..lineTo(tipX, r.center.dy + r.height * 0.24)
        ..lineTo(baseX, r.center.dy + r.height * 0.1)
        ..close();
    }
    return path;
  }

  static Path _jellyBean(Rect r) {
    final box = r.deflate(r.width * 0.08);
    return Path()
      ..moveTo(box.left, box.center.dy + box.height * 0.12)
      ..quadraticBezierTo(
        box.left + box.width * 0.05,
        box.top,
        box.center.dx,
        box.top + box.height * 0.06,
      )
      ..quadraticBezierTo(
        box.right,
        box.top - box.height * 0.02,
        box.right,
        box.center.dy + box.height * 0.08,
      )
      ..quadraticBezierTo(
        box.right - box.width * 0.1,
        box.bottom,
        box.center.dx,
        box.bottom,
      )
      ..quadraticBezierTo(
        box.left + box.width * 0.05,
        box.bottom,
        box.left,
        box.center.dy + box.height * 0.12,
      )
      ..close();
  }

  /// Dome with a flat base.
  static Path _gumdrop(Rect r) {
    final box = r.deflate(r.width * 0.06);
    return Path()
      ..moveTo(box.left, box.bottom)
      ..quadraticBezierTo(
        box.left + box.width * 0.02,
        box.top + box.height * 0.1,
        box.center.dx,
        box.top,
      )
      ..quadraticBezierTo(
        box.right - box.width * 0.02,
        box.top + box.height * 0.1,
        box.right,
        box.bottom,
      )
      ..close();
  }

  /// Accessibility glyph, drawn on top of a tile.
  static Path symbol(TileSymbol symbol, Rect r) {
    final box = Rect.fromCenter(
      center: r.center,
      width: r.width * 0.34,
      height: r.height * 0.34,
    );
    switch (symbol) {
      case TileSymbol.none:
        return Path();
      case TileSymbol.dot:
        return Path()..addOval(box.deflate(box.width * 0.2));
      case TileSymbol.ring:
        return Path()
          ..addOval(box)
          ..addOval(box.deflate(box.width * 0.22))
          ..fillType = PathFillType.evenOdd;
      case TileSymbol.square:
        return Path()..addRect(box.deflate(box.width * 0.08));
      case TileSymbol.cross:
        final arm = box.width * 0.22;
        return Path()
          ..addRect(
            Rect.fromCenter(center: box.center, width: box.width, height: arm),
          )
          ..addRect(
            Rect.fromCenter(center: box.center, width: arm, height: box.height),
          );
      case TileSymbol.triangle:
        return _polygon(box, 3, rotation: -math.pi / 2);
      case TileSymbol.diamond:
        return _polygon(box, 4, rotation: -math.pi / 2);
      case TileSymbol.star:
        return _star(box);
    }
  }

  static Path _star(Rect r) {
    final path = Path();
    final outer = r.shortestSide / 2;
    final inner = outer * 0.45;
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(
        r.center.dx + radius * math.cos(angle),
        r.center.dy + radius * math.sin(angle),
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }
}
