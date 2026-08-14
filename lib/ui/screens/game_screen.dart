import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../engine/engine.dart';
import '../../game/game_controller.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../services/level_repository.dart';
import '../../skins/skin.dart';
import '../../skins/skin_background.dart';
import '../widgets/board_view.dart';
import '../widgets/hud.dart';
import '../widgets/skin_switcher.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.modeId,
    this.level,
    this.packId,
    this.resume,
    super.key,
  });

  final String modeId;

  /// A run to pick up instead of dealing a new board.
  final RunSnapshot? resume;

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

  /// The banner waits for the board to go quiet, then a beat longer. Landing it
  /// on top of the last cascade robs the player of seeing their own final move.
  /// Applies to every mode, win or lose.
  static const Duration _settlePause = Duration(milliseconds: 500);
  Timer? _bannerTimer;
  bool _showResult = false;

  /// Resolved after a win so the overlay can offer to carry straight on.
  Level? _nextLevel;

  bool _paused = false;

  /// One pool for the whole screen: creating players per sound would stutter.
  final SoundPlayer _sound = PooledSoundPlayer();

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    _controller = resume == null
        ? GameController(
            mode: _buildMode(),
            seed: DateTime.now().millisecondsSinceEpoch,
          )
        : GameController.resume(mode: _buildMode(), snapshot: resume);
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    unawaited(_sound.dispose());
    _bannerTimer?.cancel();
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
    // Hold the banner until the run is over *and* the board has stopped moving.
    if (_controller.isOver && !_controller.busy && _bannerTimer == null) {
      _bannerTimer = Timer(_settlePause, () {
        if (mounted) setState(() => _showResult = true);
      });
    }

    if (!_controller.busy) _persist();

    if (!_controller.isOver || _scoreRecorded) return;
    _scoreRecorded = true;

    final settings = AppSettings.of(context);

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
      unawaited(_findNextLevel(level.number));
    }
  }

  Future<void> _findNextLevel(int justCleared) async {
    final pack = await LevelRepository().load();
    final next = pack.levels
        .where((level) => level.number == justCleared + 1)
        .firstOrNull;
    if (next != null && mounted) setState(() => _nextLevel = next);
  }

  void _openNextLevel() {
    final next = _nextLevel;
    final packId = widget.packId;
    if (next == null || packId == null) return;
    // Replace rather than stack, so Back still returns to the level picker
    // however many levels the player rattles through.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            GameScreen(modeId: widget.modeId, level: next, packId: packId),
      ),
    );
  }

  /// Banks the score and stores the board every time the board goes quiet.
  ///
  /// The score is recorded as the run goes rather than only at the end, so
  /// walking away from a good Infinite Hunt run still keeps the high score;
  /// `recordScore` ignores anything that is not a new best. A finished run has
  /// nothing worth resuming, so its save is dropped instead.
  void _persist() {
    final settings = AppSettings.of(context);
    unawaited(settings.recordScore(_controller.mode.id, _controller.score));

    if (_controller.isOver) {
      unawaited(settings.clearRun(_controller.mode.id));
      return;
    }
    if (_controller.movesMade == 0) return;
    unawaited(
      settings.saveRun(
        _controller.snapshot(
          levelNumber: widget.level?.number,
          packId: widget.packId,
        ),
      ),
    );
  }

  void _restart() {
    _bannerTimer?.cancel();
    setState(() {
      _bannerTimer = null;
      _showResult = false;
      _scoreRecorded = false;
      _nextLevel = null;
      _controller.restart(seed: DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final skin = settings.skin;
    _controller
      ..motion = settings.motion
      ..haptics = HapticsService(enabled: settings.haptics)
      ..audio = AudioService(player: _sound, enabled: settings.sound);

    return SkinBackground(
      skin: skin,
      simplified: settings.performanceMode,
      child: Scaffold(
        backgroundColor: const Color(0x00000000),
        body: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // The board is a grid that wants to be as big as it can. On a
                  // wide screen that means everything else belongs beside it —
                  // readouts on the left, controls on the right — rather than
                  // stretched across the top and bottom with the board pinched
                  // into the middle.
                  final wide = constraints.maxWidth > constraints.maxHeight;
                  final board = BoardView(
                    controller: _controller,
                    skin: skin,
                    showSymbols: settings.showSymbols,
                    lowSpec: settings.performanceMode,
                    particles:
                        !settings.performanceMode && !settings.reducedMotion,
                    dangerRows: _controller.mode is RisingTideMode ? 2 : 0,
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        _TopBar(
                          controller: _controller,
                          skin: skin,
                          onPause: () => setState(() => _paused = true),
                        ),
                        Hud(
                          controller: _controller,
                          skin: skin,
                          best: settings.bestFor(widget.modeId),
                          par: widget.level?.parMoves,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: board,
                          ),
                        ),
                        _Actions(
                          controller: _controller,
                          skin: skin,
                          onRestart: _restart,
                        ),
                      ],
                    );
                  }

                  final sidebar = (constraints.maxWidth * 0.24).clamp(
                    150.0,
                    260.0,
                  );
                  return Row(
                    children: [
                      SizedBox(
                        width: sidebar,
                        child: _SidePanel(
                          skin: skin,
                          children: [
                            _SideHeader(
                              controller: _controller,
                              skin: skin,
                              onBack: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(height: 18),
                            Hud(
                              controller: _controller,
                              skin: skin,
                              best: settings.bestFor(widget.modeId),
                              par: widget.level?.parMoves,
                              axis: Axis.vertical,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: board,
                        ),
                      ),
                      SizedBox(
                        width: sidebar,
                        child: _SidePanel(
                          skin: skin,
                          alignment: CrossAxisAlignment.stretch,
                          children: [
                            _Actions(
                              controller: _controller,
                              skin: skin,
                              onRestart: _restart,
                              axis: Axis.vertical,
                              onPause: () => setState(() => _paused = true),
                              onSkins: () => _showSkinSheet(context, skin),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_paused && !_showResult)
                _PauseOverlay(
                  skin: skin,
                  onResume: () => setState(() => _paused = false),
                  onRestart: () {
                    setState(() => _paused = false);
                    _restart();
                  },
                  onQuit: () => Navigator.of(context).pop(),
                ),
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _showResult
                    ? _ResultOverlay(
                        controller: _controller,
                        skin: skin,
                        level: widget.level,
                        onRestart: _restart,
                        onExit: () => Navigator.of(context).pop(),
                        onNextLevel: _nextLevel == null ? null : _openNextLevel,
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
  const _TopBar({
    required this.controller,
    required this.skin,
    required this.onPause,
  });

  final GameController controller;
  final Skin skin;
  final VoidCallback onPause;

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
            onPressed: () => _showSkinSheet(context, skin),
            icon: const Icon(Icons.palette_outlined),
            color: skin.palette.textPrimary,
          ),
          IconButton(
            onPressed: onPause,
            icon: const Icon(Icons.pause_rounded),
            color: skin.palette.textPrimary,
          ),
        ],
      ),
    );
  }
}

void _showSkinSheet(BuildContext context, Skin skin) {
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

/// A column of chrome beside the board on a wide screen.
///
/// It scrolls rather than overflowing. A phone on its side has very little
/// height to give — a stack of buttons plus the readouts ran 49 pixels past the
/// bottom of a 1220x2712 device — and chrome that cannot be reached is worse
/// than chrome that has to be nudged.
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.skin,
    required this.children,
    this.alignment = CrossAxisAlignment.start,
  });

  final Skin skin;
  final List<Widget> children;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ConstrainedBox(
        // Centre the contents when they fit, scroll them when they do not.
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: alignment,
          children: children,
        ),
      ),
    ),
  );
}

/// Back arrow and mode name, stacked for the wide layout.
class _SideHeader extends StatelessWidget {
  const _SideHeader({
    required this.controller,
    required this.skin,
    required this.onBack,
  });

  final GameController controller;
  final Skin skin;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconButton(
        onPressed: onBack,
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        icon: const Icon(Icons.arrow_back_rounded),
        color: skin.palette.textPrimary,
      ),
      const SizedBox(height: 4),
      Text(
        controller.mode.name,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: skin.palette.textPrimary,
        ),
      ),
    ],
  );
}

/// Stops the clock and gets out of the way. The board keeps its state; this is
/// only a curtain over it.
class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.skin,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  final Skin skin;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tapping the backdrop is the fastest way back to the game.
      onTap: onResume,
      child: ColoredBox(
        color: skin.palette.backgroundTop.withValues(alpha: 0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paused',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: skin.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _ActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Resume',
                skin: skin,
                onPressed: onResume,
                emphasised: true,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.tune_rounded,
                    label: 'Settings',
                    skin: skin,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.replay_rounded,
                    label: 'Restart',
                    skin: skin,
                    onPressed: onRestart,
                  ),
                  _ActionButton(
                    icon: Icons.close_rounded,
                    label: 'Quit',
                    skin: skin,
                    onPressed: onQuit,
                  ),
                ],
              ),
            ],
          ),
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
    this.axis = Axis.horizontal,
    this.onPause,
    this.onSkins,
  });

  final GameController controller;
  final Skin skin;
  final VoidCallback onRestart;
  final Axis axis;

  /// Only supplied by the wide layout, which has no top bar to put them in.
  final VoidCallback? onPause;
  final VoidCallback? onSkins;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final buttons = <Widget>[
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
          if (onSkins case final open?)
            _ActionButton(
              icon: Icons.palette_outlined,
              label: 'Skin',
              skin: skin,
              onPressed: open,
            ),
          if (onPause case final pause?)
            _ActionButton(
              icon: Icons.pause_rounded,
              label: 'Pause',
              skin: skin,
              onPressed: pause,
            ),
        ];

        if (axis == Axis.vertical) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final button in buttons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: button,
                ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: buttons,
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.skin,
    required this.onPressed,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;
  final Skin skin;
  final VoidCallback? onPressed;

  /// Filled with the skin accent rather than the muted board tint.
  final bool emphasised;

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
          foregroundColor: emphasised
              ? skin.palette.backgroundTop
              : enabled
              ? skin.palette.textPrimary
              : skin.palette.textSecondary.withValues(alpha: 0.4),
          backgroundColor: emphasised
              ? skin.palette.accent
              : skin.palette.boardCell,
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
    required this.onNextLevel,
  });

  final GameController controller;
  final Skin skin;
  final Level? level;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  /// Null on the last level of a pack, and in the endless modes.
  final VoidCallback? onNextLevel;

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
              if (onNextLevel != null) ...[
                _ActionButton(
                  icon: Icons.arrow_forward_rounded,
                  label: 'Next level',
                  skin: skin,
                  onPressed: onNextLevel,
                  emphasised: true,
                ),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.replay_rounded,
                    label: won ? 'Replay' : 'Play again',
                    skin: skin,
                    onPressed: onRestart,
                  ),
                  _ActionButton(
                    icon: Icons.grid_view_rounded,
                    label: level == null ? 'Modes' : 'Levels',
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
    GameEndReason.relicsDelivered => 'Every relic is out of the ground.',
    null => '',
  };
}
