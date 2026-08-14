import 'board_event.dart';

/// Why a swap was not played out.
enum MoveRejection {
  /// The cells are not orthogonally adjacent.
  notAdjacent,

  /// One of the cells is a hole.
  emptyCell,

  /// Both tiles are the same kind, so the swap changes nothing.
  sameKind,

  /// A legal-looking swap that forms no line. The player still sees it move and
  /// snap back, so this result carries events.
  noMatch,

  /// The run is already over.
  gameOver,

  /// The board is mid-animation; the controller filters these out.
  busy,
}

/// The outcome of one attempted player swap.
class MoveResult {
  const MoveResult._({
    required this.accepted,
    required this.events,
    this.rejection,
    this.scoreDelta = 0,
    this.cascadeCount = 0,
    this.tilesCleared = 0,
    this.longestLine = 0,
    this.specialsCreated = 0,
    this.specialsFired = 0,
  });

  factory MoveResult.rejected(MoveRejection reason) =>
      MoveResult._(accepted: false, events: const [], rejection: reason);

  /// Legal swap, no line formed: animate the swap and the revert.
  factory MoveResult.reverted(List<BoardEvent> events) => MoveResult._(
    accepted: false,
    events: events,
    rejection: MoveRejection.noMatch,
  );

  factory MoveResult.accepted({
    required List<BoardEvent> events,
    required int scoreDelta,
    required int cascadeCount,
    required int tilesCleared,
    required int longestLine,
    int specialsCreated = 0,
    int specialsFired = 0,
  }) => MoveResult._(
    accepted: true,
    events: events,
    scoreDelta: scoreDelta,
    cascadeCount: cascadeCount,
    tilesCleared: tilesCleared,
    longestLine: longestLine,
    specialsCreated: specialsCreated,
    specialsFired: specialsFired,
  );

  /// Whether the move counted against the player's move total.
  final bool accepted;

  /// Complete animation script for this move.
  final List<BoardEvent> events;

  final MoveRejection? rejection;
  final int scoreDelta;

  /// How many resolution steps ran — 1 is a plain match, 3 is a x3 chain.
  final int cascadeCount;
  final int tilesCleared;
  final int longestLine;

  /// Powers earned and powers set off by this move.
  final int specialsCreated;
  final int specialsFired;

  bool get hasEvents => events.isNotEmpty;

  @override
  String toString() => accepted
      ? 'MoveResult(accepted, +$scoreDelta, chain x$cascadeCount)'
      : 'MoveResult(rejected: ${rejection?.name})';
}
