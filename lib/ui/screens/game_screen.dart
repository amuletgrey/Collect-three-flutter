import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../engine/engine.dart';
import '../../game/game_controller.dart';
import '../../services/haptics_service.dart';
import '../../skins/skin.dart';
import '../../skins/skin_background.dart';
import '../widgets/board_view.dart';
import '../widgets/hud.dart';
import '../widgets/skin_switcher.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({required this.modeId, this.level, this.packId, super.key});

  final String modeId;

  /// Set for Clear the Board: the shipped level being played, which decides
  /// the board, the par, and where stars are recorded.
  final Level? level;
  final String? packId;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _controller;
  bool _scoreRecorded = false;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      mode: _buildMode(),
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  GameMode _buildMode() {
    final level = widget.level;
    return level == null
        ? ModeRegistry.create(widget.modeId)
        : ClearBoardMode.fromLevel(level);
  }

  void _onChanged() {
    if (!_controller.isOver || _scoreRecorded) return;
    _scoreRecorded = true;

    final settings = AppSettings.of(context);
    unawaited(settings.recordScore(_controller.mode.id, _controller.score));

    // Stars are only awarded for actually clearing the level.
    final level = widget.level;
    final packId = widget.packId;
    if (level != null &&
        packId != null &&
        _controller.status == GameStatus.won) {
      unawaited(
        settings.recordStars(
          packId,
          level.number,
          level.starsFor(_controller.movesMade),
        ),
      );
    }
  }

  void _restart() {
    setState(() {
      _scoreRecorded = false;
      _controller.restart(seed: DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final skin = settings.skin;
    _controller
      ..motion = settings.motion
      ..haptics = HapticsService(enabled: settings.haptics);

    return SkinBackground(
      skin: skin,
      simplified: settings.performanceMode,
      child: Scaffold(
        backgroundColor: const Color(0x00000000),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TopBar(controller: _controller, skin: skin),
                  Hud(
                    controller: _controller,
                    skin: skin,
                    best: settings.bestFor(widget.modeId),
                    par: widget.level?.parMoves,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: BoardView(
                        controller: _controller,
                        skin: skin,
                        showSymbols: settings.showSymbols,
                        lowSpec: settings.performanceMode,
                        dangerRows: _controller.mode is RisingTideMode ? 2 : 0,
                      ),
                    ),
                  ),
                  _Actions(
                    controller: _controller,
                    skin: skin,
                    onRestart: _restart,
                  ),
                ],
              ),
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _controller.isOver
                    ? _ResultOverlay(
                        controller: _controller,
                        skin: skin,
                        level: widget.level,
                        onRestart: _restart,
                        onExit: () => Navigator.of(context).pop(),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.skin});

  final GameController controller;
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: skin.palette.textPrimary,
          ),
          Expanded(
            child: Text(
              controller.mode.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: skin.palette.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showSkins(context),
            icon: const Icon(Icons.palette_outlined),
            color: skin.palette.textPrimary,
          ),
        ],
      ),
    );
  }

  void _showSkins(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: skin.palette.backgroundBottom,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SkinSwitcher(
          compact: true,
          onSelected: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.controller,
    required this.skin,
    required this.onRestart,
  });

  final GameController controller;
  final Skin skin;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Hint',
              skin: skin,
              onPressed: controller.busy ? null : controller.showHint,
            ),
            if (controller.mode.allowsUndo)
              _ActionButton(
                icon: Icons.undo_rounded,
                label: 'Undo ${controller.undosRemaining}',
                skin: skin,
                onPressed: controller.canUndo ? controller.undo : null,
              ),
            _ActionButton(
              icon: Icons.refresh_rounded,
              label: 'Restart',
              skin: skin,
              onPressed: onRestart,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.skin,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Skin skin;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: enabled
              ? skin.palette.textPrimary
              : skin.palette.textSecondary.withValues(alpha: 0.4),
          backgroundColor: skin.palette.boardCell,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.controller,
    required this.skin,
    required this.level,
    required this.onRestart,
    required this.onExit,
  });

  final GameController controller;
  final Skin skin;
  final Level? level;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final won = controller.status == GameStatus.won;
    return ColoredBox(
      color: skin.palette.backgroundTop.withValues(alpha: 0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? 'Board cleared' : 'Run over',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: won ? skin.palette.accent : skin.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _reasonText(controller.endReason),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: skin.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              if (won && level != null)
                _stars(level!.starsFor(controller.movesMade)),
              const SizedBox(height: 10),
              Text(
                '${controller.score}',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: skin.palette.textPrimary,
                ),
              ),
              Text(
                'best chain x${controller.bestChain} · '
                '${controller.movesMade} moves',
                style: TextStyle(
                  fontSize: 13,
                  color: skin.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.replay_rounded,
                    label: 'Play again',
                    skin: skin,
                    onPressed: onRestart,
                  ),
                  _ActionButton(
                    icon: Icons.grid_view_rounded,
                    label: 'Modes',
                    skin: skin,
                    onPressed: onExit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stars(int earned) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 1; i <= 3; i++)
        Icon(
          i <= earned ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 34,
          color: i <= earned
              ? skin.palette.accent
              : skin.palette.textSecondary.withValues(alpha: 0.5),
        ),
    ],
  );

  String _reasonText(GameEndReason? reason) => switch (reason) {
    GameEndReason.noMovesLeft => 'No legal moves left on the board.',
    GameEndReason.boardCleared => 'Every last tile collected.',
    GameEndReason.outOfMoves => 'The move budget ran out.',
    GameEndReason.overflow => 'The stack was pushed past the top row.',
    null => '',
  };
}
