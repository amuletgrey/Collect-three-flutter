import 'package:flutter/widgets.dart';

import '../../engine/engine.dart';
import '../../game/game_controller.dart';
import '../../skins/skin.dart';

/// Score, records, and one mode-specific readout.
///
/// Every mode shows the same frame; only the middle slot changes, which keeps
/// the screen recognisable however you are playing.
class Hud extends StatelessWidget {
  const Hud({
    required this.controller,
    required this.skin,
    required this.best,
    this.par,
    super.key,
  });

  final GameController controller;
  final Skin skin;
  final int best;

  /// Clear the Board levels show the proven solution length instead of a best
  /// score — beating it is the actual goal.
  final int? par;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Stat(
              label: 'Score',
              value: '${controller.score}',
              skin: skin,
              large: true,
            ),
            _modeStat(),
            if (par != null)
              _Stat(
                label: 'Moves / par',
                value: '${controller.movesMade} / $par',
                skin: skin,
                highlight: controller.movesMade > par!,
              )
            else
              _Stat(
                label: controller.score > best ? 'New best' : 'Best',
                value: '${controller.score > best ? controller.score : best}',
                skin: skin,
                highlight: controller.score > best,
              ),
          ],
        ),
      ),
    );
  }

  Widget _modeStat() {
    final mode = controller.mode;
    if (mode is RisingTideMode) {
      return _Stat(
        label: 'Tide in',
        value: '${mode.movesUntilRise}',
        skin: skin,
        highlight: mode.movesUntilRise <= 1,
      );
    }
    if (mode is RelicDigMode) {
      return _Stat(
        label: 'Relics left',
        value: '${mode.remaining}',
        skin: skin,
        highlight: mode.remaining == 0,
      );
    }
    if (mode is ClearBoardMode) {
      return _Stat(
        label: 'Tiles left',
        value: '${controller.board.tileCount}',
        skin: skin,
      );
    }
    return _Stat(label: 'Moves', value: '${controller.movesMade}', skin: skin);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.skin,
    this.large = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final Skin skin;
  final bool large;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
            color: skin.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 34 : 22,
            fontWeight: FontWeight.w800,
            color: highlight ? skin.palette.accent : skin.palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
