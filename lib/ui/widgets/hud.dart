import 'package:flutter/widgets.dart';

import '../../engine/engine.dart';
import '../../game/game_controller.dart';
import '../../skins/skin.dart';
import 'tile_view.dart';

/// Score, records, and one mode-specific readout.
///
/// Every mode shows the same frame; only the middle slot changes, which keeps
/// the screen recognisable however you are playing. It stacks vertically on a
/// wide screen, where the readouts belong in a column beside the board rather
/// than flung across the full width.
class Hud extends StatelessWidget {
  const Hud({
    required this.controller,
    required this.skin,
    required this.best,
    this.par,
    this.axis = Axis.horizontal,
    super.key,
  });

  final Axis axis;

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
      builder: (context, _) {
        final stats = [
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
        ];

        if (axis == Axis.vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final stat in stats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: stat,
                ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: stats,
          ),
        );
      },
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
    if (mode is WorkOrderMode) {
      final left = controller.engine.movesRemaining ?? 0;
      return _Stat(
        label: 'Moves left',
        value: '$left',
        skin: skin,
        highlight: left <= 3,
      );
    }
    if (mode is CreepingRotMode) {
      final rot = mode.rotOn(controller.board);
      return _Stat(
        label: 'Rot',
        value: '$rot / ${mode.rotCapacity}',
        skin: skin,
        highlight: rot >= mode.rotCapacity * 0.75,
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

/// What the mode is asking for, drawn from [GameMode.goals].
///
/// Generic on purpose: it renders whatever list the mode hands over, so the
/// next mode with goals gets the readout without touching this file. Shows
/// nothing at all for the modes whose only goal is to keep going.
class GoalStrip extends StatelessWidget {
  const GoalStrip({
    required this.controller,
    required this.skin,
    this.axis = Axis.horizontal,
    super.key,
  });

  final GameController controller;
  final Skin skin;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final goals = controller.mode.goals;
        if (goals.isEmpty) return const SizedBox.shrink();

        final chips = [
          for (final goal in goals) _GoalChip(goal: goal, skin: skin),
        ];

        if (axis == Axis.vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final chip in chips)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: chip),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final chip in chips)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: chip,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.goal, required this.skin});

  final ModeGoal goal;
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    final done = goal.isDone;
    final tint = done ? skin.palette.accent : skin.palette.textSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: skin.palette.boardFrame.withValues(alpha: done ? 0.9 : 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: done ? 0.9 : 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (goal.tileKind case final kind?) ...[
              // The actual artwork rather than a colour name: it survives a
              // skin change, and it is what the player is looking for.
              TileView(art: skin.art(kind), size: 18),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                goal.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: skin.palette.textSecondary,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              done ? 'done' : '${goal.progress}/${goal.target}',
              style: TextStyle(
                color: done ? skin.palette.accent : skin.palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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
