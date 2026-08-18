import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../items/presentation/widgets/equipped_item_list.dart';
import '../../../survivors/domain/duplicate_catalog.dart';
import '../../../survivors/domain/survivor.dart';
import '../../../survivors/presentation/widgets/survivor_portrait_artwork.dart';

class HubCharacterInfo extends StatelessWidget {
  const HubCharacterInfo({
    super.key,
    required this.survivor,
    this.onPrevious,
    this.onNext,
  });

  final Survivor? survivor;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  String _name(BuildContext context, String duplicateId) {
    final l10n = context.l10n;
    switch (duplicateId) {
      case '01':
        return l10n.characterName1;
      case '02':
        return l10n.characterName2;
      case '03':
        return l10n.characterName3;
      case '04':
        return l10n.characterName4;
      default:
        return duplicateId;
    }
  }

  String _description(BuildContext context, String duplicateId) {
    final l10n = context.l10n;
    switch (duplicateId) {
      case '01':
        return l10n.characterDescription1;
      case '02':
        return l10n.characterDescription2;
      case '03':
        return l10n.characterDescription3;
      case '04':
        return l10n.characterDescription4;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final survivor = this.survivor;
    if (survivor == null) {
      return _EmptyCharacterInfo(message: context.l10n.characterRequiredError);
    }

    final duplicate = duplicateById(survivor.duplicateId);
    final baseStats = duplicate?.baseStats;
    final mods = survivor.statMods;
    final stats = <_CharacterStat>[
      _CharacterStat(
        label: context.l10n.statStrength,
        value: (baseStats?.strength ?? 0) + mods.strength,
      ),
      _CharacterStat(
        label: context.l10n.statDexterity,
        value: (baseStats?.dexterity ?? 0) + mods.dexterity,
      ),
      _CharacterStat(
        label: context.l10n.statConstitution,
        value: (baseStats?.constitution ?? 0) + mods.constitution,
      ),
      _CharacterStat(
        label: context.l10n.statStealth,
        value: (baseStats?.stealth ?? 0) + mods.stealth,
      ),
      _CharacterStat(
        label: context.l10n.statCare,
        value: (baseStats?.care ?? 0) + mods.care,
      ),
      _CharacterStat(
        label: context.l10n.statCunning,
        value: (baseStats?.cunning ?? 0) + mods.cunning,
      ),
      _CharacterStat(
        label: context.l10n.statCharm,
        value: (baseStats?.charm ?? 0) + mods.charm,
      ),
    ];

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xE611110E),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _CharacterPortrait(
                        assetPath: survivor.idleAssetPath,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _name(context, survivor.duplicateId),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: const Color(0xFFE6D8BD),
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _EnergyIndicator(energy: survivor.energy),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: context.l10n.previousCharacter,
                                onPressed: onPrevious,
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              const SizedBox(width: 4),
                              IconButton.outlined(
                                tooltip: context.l10n.nextCharacter,
                                onPressed: onNext,
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final stat in stats)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _StatRow(stat: stat),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171713),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFF4F4638)),
                  ),
                  child: Text(
                    _description(context, survivor.duplicateId),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFA9A08F),
                          height: 1.5,
                        ),
                  ),
                ),
                const SizedBox(height: 18),
                EquippedItemList(itemIds: survivor.equippedItemIds),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnergyIndicator extends StatelessWidget {
  const _EnergyIndicator({required this.energy});

  final int energy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.bolt_rounded,
          size: 20,
          color: Color(0xFFD7BD89),
        ),
        const SizedBox(width: 2),
        Text(
          '$energy',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFFD8C8A8),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CharacterPortrait extends StatelessWidget {
  const _CharacterPortrait({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 280,
          maxHeight: 315,
        ),
        child: SurvivorPortraitArtwork(
          imageAssetPath: assetPath,
        ),
      ),
    );
  }
}

class _CharacterStat {
  const _CharacterStat({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat});

  final _CharacterStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedValue = (stat.value / 10).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFC5BAA4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${stat.value}/10',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFFD8C8A8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: normalizedValue,
            minHeight: 9,
            backgroundColor: const Color(0xFF353128),
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _EmptyCharacterInfo extends StatelessWidget {
  const _EmptyCharacterInfo({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xE611110E),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFA49B8B),
            ),
      ),
    );
  }
}
