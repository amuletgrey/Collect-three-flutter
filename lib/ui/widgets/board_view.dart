import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../engine/engine.dart';
import '../../game/game_controller.dart';
import '../../skins/skin.dart';
import 'particle_layer.dart';
import 'tile_view.dart';

/// The playing field.
///
/// Tiles are positioned widgets keyed by tile id, so Flutter animates the same
/// widget from cell to cell instead of cross-fading the grid. Both input styles
/// are supported: tap a tile then a neighbour, or drag one towards a neighbour.
class BoardView extends StatefulWidget {
  const BoardView({
    required this.controller,
    required this.skin,
    this.showSymbols = false,
    this.lowSpec = false,
    this.particles = true,
    this.dangerRows = 0,
    super.key,
  });

  final GameController controller;
  final Skin skin;
  final bool showSymbols;

  /// Performance mode: skip the blurred shadows and highlights.
  final bool lowSpec;

  /// Sparks on collect. Off for reduced motion and performance mode.
  final bool particles;

  /// Rising Tide tints this many rows at the top as the drowning warning.
  final int dangerRows;

  /// Identifies the square that exactly covers the grid.
  static const Key gridKey = ValueKey('collect-three-grid');

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with TickerProviderStateMixin {
  Pos? _dragOrigin;

  /// Runs only while a hint is on screen, so an idle board schedules no frames.
  late final AnimationController _hintPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// A single beat when the stack first reaches the danger rows.
  ///
  /// Deliberately one-shot rather than a loop: a permanently repeating
  /// animation keeps scheduling frames for as long as the player is in trouble,
  /// which costs battery and means the widget tree never settles.
  late final AnimationController _dangerFlash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _inDanger = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncHintPulse);
    _syncHintPulse();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncHintPulse);
    _hintPulse.dispose();
    _dangerFlash.dispose();
    super.dispose();
  }

  void _syncHintPulse() {
    final wanted = widget.controller.hint != null;
    if (wanted && !_hintPulse.isAnimating) {
      _hintPulse.repeat();
    } else if (!wanted && _hintPulse.isAnimating) {
      _hintPulse
        ..stop()
        ..value = 0;
    }

    // Beat once on the way in, and again each time the stack climbs back up.
    final danger = _dangerReached(widget.controller.board);
    if (danger && !_inDanger) _dangerFlash.forward(from: 0);
    _inDanger = danger;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, _hintPulse, _dangerFlash]),
      builder: (context, _) {
        final board = controller.board;
        return LayoutBuilder(
          builder: (context, constraints) {
            final cell = (constraints.maxWidth / board.cols).clamp(
              0.0,
              constraints.maxHeight / board.rows,
            );
            final width = cell * board.cols;
            final height = cell * board.rows;

            return Center(
              child: SizedBox(
                // Keyed so on-device tests can measure the grid exactly and
                // aim taps at real cell centres.
                key: BoardView.gridKey,
                width: width,
                height: height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => controller.tap(
                    _posAt(details.localPosition, cell, board),
                  ),
                  onPanStart: (details) =>
                      _dragOrigin = _posAt(details.localPosition, cell, board),
                  onPanUpdate: (details) =>
                      _onDrag(details.localPosition, cell, board),
                  onPanEnd: (_) => _dragOrigin = null,
                  child: Stack(
                    children: [
                      _Grid(
                        board: board,
                        cell: cell,
                        skin: widget.skin,
                        dangerRows: widget.dangerRows,
                        // A tint that is always on becomes wallpaper; this
                        // beats once as the stack arrives.
                        dangerPulse: _dangerFlash.value,
                      ),
                      for (final id in controller.tileIds)
                        _positioned(controller, id, cell),
                      Positioned.fill(
                        child: ParticleLayer(
                          controller: controller,
                          skin: widget.skin,
                          cell: cell,
                          enabled: widget.particles,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _positioned(GameController controller, int id, double cell) {
    final pos = controller.positionOf(id);
    final tile = controller.tileById(id);
    return AnimatedPositioned(
      key: ValueKey(id),
      duration: controller.stepDuration,
      curve: Curves.easeOutCubic,
      left: pos.col * cell,
      top: pos.row * cell,
      width: cell,
      height: cell,
      child: TileView(
        art: widget.skin.art(tile.kind),
        size: cell,
        selected: controller.selected == pos,
        hinted: _isHinted(controller, pos),
        clearing: controller.isClearing(id),
        rejected: controller.isRejected(pos),
        power: tile.power,
        firing: controller.isFiring(pos),
        hintPulse: _hintPulse.value,
        hintColour: widget.skin.palette.hint,
        showSymbols: widget.showSymbols && widget.skin.supportsSymbols,
        lowSpec: widget.lowSpec,
      ),
    );
  }

  /// True when a tile occupies one of the rows we tint as the drowning warning.
  bool _dangerReached(Board board) {
    if (widget.dangerRows == 0) return false;
    for (var row = 0; row < widget.dangerRows; row++) {
      for (var col = 0; col < board.cols; col++) {
        if (board.atRc(row, col) != null) return true;
      }
    }
    return false;
  }

  bool _isHinted(GameController controller, Pos pos) {
    final hint = controller.hint;
    return hint != null && (hint.a == pos || hint.b == pos);
  }

  /// Turns a drag into a swap as soon as it leaves the starting cell, so a
  /// short flick is enough — no need to drag all the way across.
  void _onDrag(Offset local, double cell, Board board) {
    final origin = _dragOrigin;
    if (origin == null) return;
    final current = _posAt(local, cell, board);
    if (current == origin) return;
    if (!origin.isAdjacentTo(current)) {
      _dragOrigin = null;
      return;
    }
    _dragOrigin = null;
    widget.controller.swipe(origin, current);
  }

  Pos _posAt(Offset local, double cell, Board board) => Pos(
    (local.dy ~/ cell).clamp(0, board.rows - 1),
    (local.dx ~/ cell).clamp(0, board.cols - 1),
  );
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.board,
    required this.cell,
    required this.skin,
    required this.dangerRows,
    required this.dangerPulse,
  });

  final Board board;
  final double cell;
  final Skin skin;
  final int dangerRows;
  final double dangerPulse;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(cell * board.cols, cell * board.rows),
      painter: _GridPainter(
        rows: board.rows,
        cols: board.cols,
        cell: cell,
        skin: skin,
        dangerRows: dangerRows,
        dangerPulse: dangerPulse,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.rows,
    required this.cols,
    required this.cell,
    required this.skin,
    required this.dangerRows,
    required this.dangerPulse,
  });

  final int rows;
  final int cols;
  final double cell;
  final Skin skin;
  final int dangerRows;
  final double dangerPulse;

  @override
  void paint(Canvas canvas, Size size) {
    final cellPaint = Paint()..color = skin.palette.boardCell;
    final beat = math.sin(dangerPulse * math.pi).abs();
    final dangerPaint = Paint()
      ..color = skin.palette.danger.withValues(alpha: 0.16 + 0.26 * beat);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            col * cell,
            row * cell,
            cell,
            cell,
          ).deflate(cell * 0.04),
          Radius.circular(cell * 0.18),
        );
        canvas.drawRRect(rect, row < dangerRows ? dangerPaint : cellPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.dangerPulse != dangerPulse ||
      old.rows != rows ||
      old.cols != cols ||
      old.cell != cell ||
      old.dangerRows != dangerRows ||
      old.skin.id != skin.id;
}
