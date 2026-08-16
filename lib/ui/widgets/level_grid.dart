import 'package:flutter/material.dart';

import '../../skins/skin.dart';

/// One entry in a level picker.
class LevelEntry {
  const LevelEntry({
    required this.number,
    required this.stars,
    required this.subtitle,
  });

  final int number;
  final int stars;

  /// A line under the number — the size of a layout, the shape of an order.
  final String subtitle;
}

/// The picker itself: a numbered grid that unlocks in order.
///
/// Shared by both packs. Clear the Board and Work Order ramp differently but
/// they are picked the same way, and the unlock rule is the sort of thing that
/// should exist once — playing a pack out of order skips the teaching, whatever
/// the pack is teaching.
class LevelGrid extends StatelessWidget {
  const LevelGrid({
    required this.title,
    required this.entries,
    required this.skin,
    required this.onOpen,
    super.key,
  });

  final String title;
  final List<LevelEntry> entries;
  final Skin skin;
  final void Function(int number) onOpen;

  @override
  Widget build(BuildContext context) {
    // The next unplayed level is the only locked one you can reach.
    var unlockedUpTo = 1;
    for (final entry in entries) {
      if (entry.stars > 0) unlockedUpTo = entry.number + 1;
    }

    return Column(
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
                  title,
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
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _LevelTile(
                entry: entry,
                skin: skin,
                locked: entry.number > unlockedUpTo,
                onOpen: () => onOpen(entry.number),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.entry,
    required this.skin,
    required this.locked,
    required this.onOpen,
  });

  final LevelEntry entry;
  final Skin skin;
  final bool locked;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: locked
          ? skin.palette.boardCell.withValues(alpha: 0.4)
          : skin.palette.boardCell,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: locked ? null : onOpen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              Icon(
                Icons.lock_outline_rounded,
                color: skin.palette.textSecondary,
                size: 20,
              )
            else ...[
              Text(
                '${entry.number}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: skin.palette.textPrimary,
                ),
              ),
              Text(
                entry.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: skin.palette.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 3; i++)
                  Icon(
                    i <= entry.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 13,
                    color: i <= entry.stars
                        ? skin.palette.accent
                        : skin.palette.textSecondary.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
