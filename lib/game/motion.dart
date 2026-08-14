import 'package:flutter/animation.dart';

/// One place for every duration and curve in the game.
///
/// [reduced] collapses the timings for the reduced-motion setting without any
/// call site having to know about it.
class Motion {
  const Motion({this.reduced = false});

  final bool reduced;

  Duration _scale(int ms) =>
      Duration(milliseconds: reduced ? (ms * 0.35).round() : ms);

  Duration get swap => _scale(150);
  Duration get revert => _scale(150);
  Duration get clear => _scale(240);
  Duration get fallPerCell => _scale(70);
  Duration get slide => _scale(200);
  Duration get spawn => _scale(220);
  Duration get rowInsert => _scale(260);

  /// A power going off, and a power appearing on the board.
  Duration get blast => _scale(180);
  Duration get specialBirth => _scale(160);

  /// Beat between cascade steps so a chain reads as separate hits.
  Duration get cascadeGap => _scale(60);

  Curve get swapCurve => Curves.easeOutCubic;
  Curve get fallCurve => Curves.easeInQuad;
  Curve get popCurve => Curves.easeOutBack;
}
