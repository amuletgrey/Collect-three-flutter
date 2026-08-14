import 'package:flutter/services.dart';

import '../engine/engine.dart';

/// Physical feedback for board events.
///
/// Uses the platform's built-in haptics rather than a plugin, so it costs
/// nothing on platforms that have none — the calls are simply no-ops.
class HapticsService {
  const HapticsService({required this.enabled});

  final bool enabled;

  /// Scales with the size of the moment: a plain match is a tap, a long chain
  /// is a thump, and the end of a run is unmistakable.
  void forEvent(BoardEvent event) {
    if (!enabled) return;
    switch (event) {
      case TilesCleared(:final cascadeStep):
        if (cascadeStep >= 3) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.selectionClick();
        }
      case SwapReverted():
        HapticFeedback.lightImpact();
      case RowInserted():
        HapticFeedback.mediumImpact();
      case GameEnded():
        HapticFeedback.heavyImpact();
      case SwapPerformed():
      case TilesMoved():
      case TilesSpawned():
        break;
    }
  }
}
