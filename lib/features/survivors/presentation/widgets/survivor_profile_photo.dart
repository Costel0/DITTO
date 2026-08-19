import 'package:flutter/material.dart';

import '../../domain/survivor.dart';
import 'survivor_portrait_artwork.dart';

/// Compact square Survivor portrait that keeps the worn photo treatment used
/// by the full character portrait while remaining reusable in selectors,
/// rosters, task assignments, and other dense UI.
class SurvivorProfilePhoto extends StatelessWidget {
  const SurvivorProfilePhoto({
    super.key,
    required this.survivor,
    this.size = 64,
  });

  final Survivor survivor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Transform.rotate(
        angle: -0.015,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFC7BEAA),
            border: Border.all(
              color: const Color(0xFF665D4D),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF222019)),
                  Image.asset(
                    defaultSurvivorPortraitBackgroundAssetPath,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  _ProfilePortrait(survivor: survivor),
                  const IgnorePointer(
                    child: ColoredBox(color: Color(0x121A1711)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePortrait extends StatelessWidget {
  const _ProfilePortrait({required this.survivor});

  final Survivor survivor;

  @override
  Widget build(BuildContext context) {
    Widget fallback() {
      return Image.asset(
        survivor.idleAssetPath,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const Padding(
          padding: EdgeInsets.all(14),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Icon(
              Icons.person_rounded,
              color: Color(0xFF8E8169),
            ),
          ),
        ),
      );
    }

    return Image.asset(
      survivor.profileAssetPath,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => fallback(),
    );
  }
}
