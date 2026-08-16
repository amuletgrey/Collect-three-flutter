import '../generation/board_generator.dart';
import '../generation/order_level.dart';
import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';
import '../resolution/board_event.dart';
import 'game_mode.dart';

/// What one line of the order asks for.
enum OrderKind {
  /// Collect this many tiles of one kind, however they are taken.
  collect,

  /// Remove this many tiles with powers rather than with lines.
  demolish,

  /// Reach a cascade this deep, once.
  cascade,
}

/// A single line of the order: what is wanted, how much, and how far along.
class OrderLine {
  OrderLine({
    required this.kind,
    required this.target,
    this.tileKind = 0,
    int progress = 0,
  }) {
    _progress = progress;
  }

  factory OrderLine.fromJson(Map<String, Object?> json) => OrderLine(
    kind: OrderKind.values[json['kind']! as int],
    target: json['target']! as int,
    tileKind: json['tile'] as int? ?? 0,
    progress: json['progress'] as int? ?? 0,
  );

  final OrderKind kind;
  final int target;

  /// Which tile kind [OrderKind.collect] wants. Meaningless otherwise.
  final int tileKind;

  late int _progress;
  int get progress => _progress;
  bool get isDone => _progress >= target;

  /// Folds one move into this line.
  void record(MoveSummary move) {
    if (isDone) return;
    switch (kind) {
      case OrderKind.collect:
        _progress += move.clearedOf(tileKind);
      case OrderKind.demolish:
        _progress += move.blastCleared;
      case OrderKind.cascade:
        // A one-shot: the deepest chain of the run so far, not a running total.
        if (move.cascadeCount > _progress) _progress = move.cascadeCount;
    }
    if (_progress > target) _progress = target;
  }

  String get label => switch (kind) {
    OrderKind.collect => 'Collect',
    OrderKind.demolish => 'Blast',
    OrderKind.cascade => 'Chain',
  };

  Map<String, Object?> toJson() => {
    'kind': kind.index,
    'target': target,
    'tile': tileKind,
    'progress': _progress,
  };
}

/// Fill the order before the moves run out.
///
/// A short list of demands — so many of a colour, so many tiles taken with
/// powers, one deep chain — against a fixed move budget. It is the most
/// conventional match-3 mode in the game and that is the point: Infinite Hunt
/// has no shape, and this is where a player can be given something specific to
/// do and be judged on how efficiently they did it.
///
/// The order is drawn from the run's seed, so the same seed sets the same job.
class WorkOrderMode extends GameMode {
  WorkOrderMode({
    this.grid = const GridConfig(rows: 8, cols: 8, kindCount: 6),
    this.moveBudget = 25,
    this.lineCount = 3,
    this.fixedOrder,
  });

  /// Builds the mode for a shipped level: the order and the budget are the
  /// ones the generator measured, not ones drawn from this run's seed.
  factory WorkOrderMode.fromLevel(OrderLevel level) => WorkOrderMode(
    grid: GridConfig(rows: 8, cols: 8, kindCount: level.kindCount),
    moveBudget: level.moveBudget,
    lineCount: level.lines.length,
    fixedOrder: level.freshLines(),
  );

  @override
  final GridConfig grid;

  /// Moves the player gets for the whole order.
  final int moveBudget;

  /// How many lines the order runs to. Ignored when [fixedOrder] is set.
  final int lineCount;

  /// The shipped order, when this run is a level rather than free play.
  final List<OrderLine>? fixedOrder;

  /// Paid per finished line, and per move still in hand at the end — a fast
  /// order is worth far more than a slow one, which is the whole tension.
  static const int lineBonus = 400;
  static const int spareMoveBonus = 120;

  List<OrderLine> _order = [];
  int _bonusPaid = 0;

  List<OrderLine> get order => List.unmodifiable(_order);
  bool get isFilled => _order.isNotEmpty && _order.every((line) => line.isDone);

  @override
  String get id => 'work_order';

  @override
  String get name => 'Work Order';

  @override
  String get tagline => 'Fill the order before the moves run out.';

  @override
  GravityRule get gravity => GravityRule.down;

  @override
  RefillRule get refill => RefillRule.fromTop;

  @override
  bool get allowsSpecials => true;

  @override
  int? get moveLimit => moveBudget;

  @override
  List<ModeGoal> get goals => [
    for (final line in _order)
      ModeGoal(
        label: line.label,
        progress: line.progress,
        target: line.target,
        tileKind: line.kind == OrderKind.collect ? line.tileKind : null,
      ),
  ];

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) {
    _order = fixedOrder ?? _drawOrder(rng);
    return BoardGenerator.generate(grid: grid, rng: rng, tiles: tiles);
  }

  /// Builds the list. Collection lines come first and always use distinct
  /// kinds — two lines wanting the same colour would be one line with a bigger
  /// number, and reads like a bug.
  List<OrderLine> _drawOrder(SeededRandom rng) {
    final kinds = [for (var k = 0; k < grid.kindCount; k++) k];
    rng.shuffle(kinds);

    final lines = <OrderLine>[
      for (var i = 0; i < lineCount - 1 && i < kinds.length; i++)
        OrderLine(
          kind: OrderKind.collect,
          tileKind: kinds[i],
          // Comfortably inside the budget on its own, uncomfortable stacked up
          // with the rest of the list.
          target: 18 + rng.nextInt(4) * 3,
        ),
    ];

    // The last line asks for something other than volume, so filling an order
    // is never just "match a lot".
    lines.add(
      rng.nextBool()
          ? OrderLine(kind: OrderKind.demolish, target: 10 + rng.nextInt(3) * 2)
          : OrderLine(kind: OrderKind.cascade, target: 3 + rng.nextInt(2)),
    );
    return lines;
  }

  @override
  ModeStepOutcome afterMove(ModeContext ctx) {
    final move = ctx.move;
    if (move == null) return ModeStepOutcome(board: ctx.board);

    final before = isFilled;
    for (final line in _order) {
      line.record(move);
    }

    // Paid once, on the move that completes the order.
    if (!before && isFilled) {
      final spare = (moveBudget - ctx.movesMade).clamp(0, moveBudget);
      _bonusPaid = _order.length * lineBonus + spare * spareMoveBonus;
      return ModeStepOutcome(board: ctx.board, scoreDelta: _bonusPaid);
    }
    return ModeStepOutcome(board: ctx.board);
  }

  @override
  ModeEvaluation evaluate(ModeContext ctx) {
    if (isFilled) return const ModeEvaluation.won(GameEndReason.orderFilled);
    if (ctx.movesMade >= moveBudget) {
      return const ModeEvaluation.lost(GameEndReason.outOfMoves);
    }
    return MoveFinder.hasLegalMove(ctx.board, specials: allowsSpecials)
        ? const ModeEvaluation.playing()
        : const ModeEvaluation.lost(GameEndReason.noMovesLeft);
  }

  @override
  Map<String, Object?> saveState() => {
    'order': [for (final line in _order) line.toJson()],
    'bonus': _bonusPaid,
  };

  @override
  void restoreState(Map<String, Object?> state) {
    final saved = state['order'] as List<Object?>? ?? const [];
    _order = [
      for (final line in saved)
        OrderLine.fromJson((line! as Map).cast<String, Object?>()),
    ];
    _bonusPaid = state['bonus'] as int? ?? 0;
  }

  @override
  GameMode fresh() => WorkOrderMode(
    grid: grid,
    moveBudget: moveBudget,
    lineCount: lineCount,
    // Copies, or a restart would carry the finished progress back in.
    fixedOrder: fixedOrder == null
        ? null
        : [
            for (final line in fixedOrder!)
              OrderLine(
                kind: line.kind,
                target: line.target,
                tileKind: line.tileKind,
              ),
          ],
  );
}
