import '../modes/work_order_mode.dart';
import 'level.dart';

/// One Work Order level, as shipped in a pack.
///
/// Unlike a Clear the Board layout there is nothing to *prove* here — the board
/// refills at random, so no search can show an order is fillable. What the
/// generator does instead is play each candidate many times with a goal-seeking
/// bot and keep the ones a competent player finishes: [parMoves] is what that
/// bot needed, and [moveBudget] is that plus room to be human.
class OrderLevel implements PackLevel {
  const OrderLevel({
    required this.number,
    required this.lines,
    required this.moveBudget,
    required this.kindCount,
    required this.parMoves,
    required this.seed,
    this.fillRate = 1,
  });

  factory OrderLevel.fromJson(Map<String, Object?> json) => OrderLevel(
    number: json['number']! as int,
    lines: [
      for (final line in json['lines']! as List<Object?>)
        OrderLine.fromJson((line! as Map).cast<String, Object?>()),
    ],
    moveBudget: json['budget']! as int,
    kindCount: json['kinds']! as int,
    parMoves: json['par']! as int,
    seed: json['seed']! as int,
    fillRate: (json['fill'] as num?)?.toDouble() ?? 1,
  );

  @override
  final int number;

  /// What the order asks for. Stored with zero progress; a run takes its own
  /// copies so a level can be replayed.
  final List<OrderLine> lines;

  final int moveBudget;
  final int kindCount;

  @override
  final int parMoves;

  /// The seed the level was tuned against — enough to reproduce the run the
  /// generator measured.
  final int seed;

  /// How often the bot filled this order, across the seeds it was tried on.
  /// Kept in the file as the record of why the level was considered fair.
  final double fillRate;

  /// Fresh copies, so playing a level twice starts from zero both times.
  List<OrderLine> freshLines() => [
    for (final line in lines)
      OrderLine(kind: line.kind, target: line.target, tileKind: line.tileKind),
  ];

  /// 3 stars for matching the bot, 2 for close, 1 for filling it at all.
  @override
  int starsFor(int movesUsed) {
    if (movesUsed <= parMoves) return 3;
    if (movesUsed <= parMoves + 3) return 2;
    return 1;
  }

  Map<String, Object?> toJson() => {
    'number': number,
    'lines': [for (final line in lines) line.toJson()],
    'budget': moveBudget,
    'kinds': kindCount,
    'par': parMoves,
    'seed': seed,
    'fill': double.parse(fillRate.toStringAsFixed(2)),
  };
}

/// A numbered set of orders, loaded from `assets/orders/`.
class OrderPack {
  const OrderPack({
    required this.id,
    required this.version,
    required this.levels,
  });

  factory OrderPack.fromJson(Map<String, Object?> json) => OrderPack(
    id: json['id']! as String,
    version: json['version']! as int,
    levels: [
      for (final entry in json['levels']! as List<Object?>)
        OrderLevel.fromJson(entry! as Map<String, Object?>),
    ],
  );

  final String id;
  final int version;
  final List<OrderLevel> levels;

  int get length => levels.length;

  OrderLevel byNumber(int number) =>
      levels.firstWhere((level) => level.number == number);

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'levels': [for (final level in levels) level.toJson()],
  };
}
