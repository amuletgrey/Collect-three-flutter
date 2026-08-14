import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../game/game_controller.dart';
import '../../skins/skin.dart';

/// Sparks thrown off by collected tiles, in the colour of whatever was cleared.
///
/// The layer owns its own ticker and only runs while sparks are alive, so an
/// idle board schedules no frames. It draws nothing at all when the player has
/// asked for reduced motion or performance mode — this is pure decoration and
/// it is the first thing that should go.
class ParticleLayer extends StatefulWidget {
  const ParticleLayer({
    required this.controller,
    required this.skin,
    required this.cell,
    this.enabled = true,
    super.key,
  });

  final GameController controller;
  final Skin skin;
  final double cell;
  final bool enabled;

  @override
  State<ParticleLayer> createState() => _ParticleLayerState();
}

class _ParticleLayerState extends State<ParticleLayer>
    with SingleTickerProviderStateMixin {
  static const int _perTile = 6;
  static const Duration _life = Duration(milliseconds: 620);

  final List<_Spark> _sparks = [];
  final math.Random _random = math.Random(7);

  /// Built here rather than lazily: touching `createTicker` for the first time
  /// inside `dispose` looks up an ancestor on a deactivated widget, which a
  /// board that never threw a spark would otherwise do.
  late final Ticker _ticker;

  int _lastTick = 0;
  Duration _now = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _lastTick = widget.controller.burstTick;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!widget.enabled) return;
    final tick = widget.controller.burstTick;
    if (tick == _lastTick) return;
    _lastTick = tick;
    _spawn(widget.controller.bursts);
  }

  void _spawn(List<CollectBurst> bursts) {
    for (final burst in bursts) {
      final colour = widget.skin.art(burst.kind).primary;
      final centre = Offset(
        (burst.at.col + 0.5) * widget.cell,
        (burst.at.row + 0.5) * widget.cell,
      );
      for (var i = 0; i < _perTile; i++) {
        final angle = _random.nextDouble() * math.pi * 2;
        final speed = widget.cell * (0.9 + _random.nextDouble() * 1.4);
        _sparks.add(
          _Spark(
            origin: centre,
            velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
            colour: colour,
            radius: widget.cell * (0.05 + _random.nextDouble() * 0.05),
            born: _now,
          ),
        );
      }
    }
    if (!_ticker.isActive) _ticker.start();
    setState(() {});
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    _sparks.removeWhere((spark) => elapsed - spark.born > _life);
    if (_sparks.isEmpty) {
      _ticker.stop();
      _now = Duration.zero;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _sparks.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _SparkPainter(sparks: _sparks, now: _now, life: _life),
      ),
    );
  }
}

class _Spark {
  const _Spark({
    required this.origin,
    required this.velocity,
    required this.colour,
    required this.radius,
    required this.born,
  });

  final Offset origin;
  final Offset velocity;
  final Color colour;
  final double radius;
  final Duration born;
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({
    required this.sparks,
    required this.now,
    required this.life,
  });

  final List<_Spark> sparks;
  final Duration now;
  final Duration life;

  @override
  void paint(Canvas canvas, Size size) {
    for (final spark in sparks) {
      final age = (now - spark.born).inMicroseconds / life.inMicroseconds;
      if (age < 0 || age > 1) continue;

      // Thrown outwards, slowed, and pulled down — sparks, not confetti.
      final travel = 1 - math.pow(1 - age, 2).toDouble();
      final position =
          spark.origin +
          spark.velocity * travel * 0.35 +
          Offset(0, age * age * spark.radius * 26);

      canvas.drawCircle(
        position,
        spark.radius * (1 - age * 0.55),
        Paint()..color = spark.colour.withValues(alpha: (1 - age) * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}
