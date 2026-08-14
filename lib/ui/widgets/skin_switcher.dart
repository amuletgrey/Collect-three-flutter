import 'package:flutter/widgets.dart';

import '../../app_settings.dart';
import '../../skins/skin.dart';
import '../../skins/skin_registry.dart';
import '../../skins/tile_painter.dart';

/// Skin picker: a row of sample tiles per skin.
///
/// Switching is instant and safe at any time, including mid-game — a skin owns
/// no game state.
class SkinSwitcher extends StatelessWidget {
  const SkinSwitcher({required this.compact, this.onSelected, super.key});

  final bool compact;

  /// Called after a skin is picked — the in-game sheet uses this to close
  /// itself, so the board is visible again straight away.
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final skin in SkinRegistry.all)
          _SkinRow(
            skin: skin,
            selected: skin.id == settings.skin.id,
            compact: compact,
            onTap: () {
              settings.selectSkin(skin);
              onSelected?.call();
            },
          ),
      ],
    );
  }
}

class _SkinRow extends StatelessWidget {
  const _SkinRow({
    required this.skin,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final Skin skin;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = AppSettings.of(context).skin;
    final sample = compact ? 26.0 : 34.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? active.palette.accent.withValues(alpha: 0.16)
              : active.palette.boardCell,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? active.palette.accent
                : active.palette.textSecondary.withValues(alpha: 0.25),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            for (var kind = 0; kind < 4; kind++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CustomPaint(
                  size: Size.square(sample),
                  painter: TilePainter(
                    art: skin.art(kind),
                    state: const TileVisualState(),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    skin.name,
                    style: TextStyle(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      color: active.palette.textPrimary,
                    ),
                  ),
                  if (!compact)
                    Text(
                      skin.tagline,
                      style: TextStyle(
                        fontSize: 12,
                        color: active.palette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
