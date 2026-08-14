import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../engine/engine.dart';
import '../../skins/skin.dart';
import '../../skins/skin_background.dart';
import '../widgets/skin_switcher.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final skin = settings.skin;

    return SkinBackground(
      skin: skin,
      simplified: settings.performanceMode,
      child: Scaffold(
        backgroundColor: const Color(0x00000000),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const SizedBox(height: 28),
              Text(
                'TESSERA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 52,
                  height: 1.05,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w900,
                  color: skin.palette.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'LINE UP THE MOSAIC',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  letterSpacing: 5,
                  fontWeight: FontWeight.w300,
                  color: skin.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 26),
              for (final mode in ModeRegistry.createAll())
                _ModeCard(
                  mode: mode,
                  skin: skin,
                  best: settings.bestFor(mode.id),
                  saved: settings.savedRun(mode.id),
                ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 22, bottom: 6),
                child: Text(
                  'SKIN',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: skin.palette.textSecondary,
                  ),
                ),
              ),
              const SkinSwitcher(compact: false),
              const SizedBox(height: 10),
              _SettingsRow(settings: settings, skin: skin),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.skin,
    required this.best,
    required this.saved,
  });

  final GameMode mode;
  final Skin skin;
  final int best;

  /// A run left unfinished, if there is one.
  final RunSnapshot? saved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: skin.palette.boardCell,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          // Clear the Board runs on hand-verified levels, so it opens the
          // picker; the endless modes start straight away, resuming whatever
          // was left unfinished.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => mode.id == ModeRegistry.clearBoardId
                  ? const LevelSelectScreen()
                  : GameScreen(modeId: mode.id, resume: saved),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: skin.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mode.tagline,
                        style: TextStyle(
                          fontSize: 13,
                          color: skin.palette.textSecondary,
                        ),
                      ),
                      if (saved != null) ...[
                        const SizedBox(height: 8),
                        _ResumeChip(saved: saved!, skin: skin),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'BEST',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: skin.palette.textSecondary,
                      ),
                    ),
                    Text(
                      '$best',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: skin.palette.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Says a run is waiting, and what state it is in.
class _ResumeChip extends StatelessWidget {
  const _ResumeChip({required this.saved, required this.skin});

  final RunSnapshot saved;
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: skin.palette.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: skin.palette.accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 15, color: skin.palette.accent),
          const SizedBox(width: 4),
          Text(
            'Continue · ${saved.score} pts, move ${saved.movesMade}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: skin.palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.settings, required this.skin});

  final AppSettings settings;
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (skin.supportsSymbols)
            _Toggle(
              label: 'Symbols on tiles',
              hint: 'Adds a glyph to each colour',
              value: settings.showSymbols,
              skin: skin,
              onChanged: (value) => settings.setShowSymbols(value: value),
            ),
          _Toggle(
            label: 'Reduced motion',
            hint: 'Shortens every animation',
            value: settings.reducedMotion,
            skin: skin,
            onChanged: (value) => settings.setReducedMotion(value: value),
          ),
          _Toggle(
            label: 'Performance mode',
            hint: 'Simpler drawing for older phones',
            value: settings.performanceMode,
            skin: skin,
            onChanged: (value) => settings.setPerformanceMode(value: value),
          ),
          _Toggle(
            label: 'Vibration',
            hint: 'Buzz on matches and chains',
            value: settings.haptics,
            skin: skin,
            onChanged: (value) => settings.setHaptics(value: value),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.hint,
    required this.value,
    required this.skin,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool value;
  final Skin skin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: skin.palette.accent,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: skin.palette.textPrimary),
      ),
      subtitle: Text(
        hint,
        style: TextStyle(fontSize: 12, color: skin.palette.textSecondary),
      ),
    );
  }
}
