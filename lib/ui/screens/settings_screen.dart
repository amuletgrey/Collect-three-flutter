import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../skins/skin.dart';
import '../../skins/skin_background.dart';
import '../widgets/skin_switcher.dart';

/// Everything the player can change, in one place.
///
/// These toggles used to sit at the bottom of the home screen, where they
/// pushed the mode cards up and read as clutter. The home screen is for
/// choosing what to play.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              Padding(
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
                        'Settings',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: skin.palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              _SectionLabel(text: 'SKIN', skin: skin),
              const SkinSwitcher(compact: false),
              const SizedBox(height: 12),
              _SectionLabel(text: 'PLAY', skin: skin),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (skin.supportsSymbols)
                      _Toggle(
                        label: 'Symbols on tiles',
                        hint: 'Adds a glyph to each colour',
                        value: settings.showSymbols,
                        skin: skin,
                        onChanged: (value) =>
                            settings.setShowSymbols(value: value),
                      ),
                    _Toggle(
                      label: 'Vibration',
                      hint: 'Buzz on matches and chains',
                      value: settings.haptics,
                      skin: skin,
                      onChanged: (value) => settings.setHaptics(value: value),
                    ),
                    _Toggle(
                      label: 'Reduced motion',
                      hint: 'Shortens animations and drops the sparks',
                      value: settings.reducedMotion,
                      skin: skin,
                      onChanged: (value) =>
                          settings.setReducedMotion(value: value),
                    ),
                    _Toggle(
                      label: 'Performance mode',
                      hint: 'Simpler drawing for older phones',
                      value: settings.performanceMode,
                      skin: skin,
                      onChanged: (value) =>
                          settings.setPerformanceMode(value: value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.skin});

  final String text;
  final Skin skin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 22, top: 10, bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
        color: skin.palette.textSecondary,
      ),
    ),
  );
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
        style: TextStyle(fontSize: 15, color: skin.palette.textPrimary),
      ),
      subtitle: Text(
        hint,
        style: TextStyle(fontSize: 12, color: skin.palette.textSecondary),
      ),
    );
  }
}
