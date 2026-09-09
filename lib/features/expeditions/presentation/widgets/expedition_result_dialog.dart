import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../domain/expedition_review.dart';

class ExpeditionResultDialog extends StatefulWidget {
  const ExpeditionResultDialog({
    super.key,
    required this.review,
  });

  final ExpeditionReview review;

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required ExpeditionReview review,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      barrierColor: const Color(0xC0000000),
      builder: (_) => ExpeditionResultDialog(review: review),
    );
  }

  @override
  State<ExpeditionResultDialog> createState() => _ExpeditionResultDialogState();
}

class _ExpeditionResultDialogState extends State<ExpeditionResultDialog> {
  final Map<String, String> _selectedOptions = <String, String>{};

  ExpeditionReview get review => widget.review;

  @override
  void initState() {
    super.initState();
    for (final outcome in review.outcomes) {
      if (outcome.resolutionOptions.length == 1) {
        _selectedOptions[outcome.actionId] =
            outcome.resolutionOptions.single.id;
      }
    }
  }

  String _title(BuildContext context) {
    switch (review.expeditionType) {
      case 'scavenge':
        return context.l10n.expeditionReportScavengeTitle;
      default:
        return context.l10n.expeditionReportFallbackTitle;
    }
  }

  String _narrative(BuildContext context, String narrativeId) {
    switch (narrativeId) {
      case 'scavenge_nothing':
        return context.l10n.expeditionNarrativeNothing;
      case 'scavenge_scrap_and_trash':
        return context.l10n.expeditionNarrativeScrapAndTrash;
      case 'scavenge_scrap_metal_2':
        return context.l10n.expeditionNarrativeScrapMetal;
      case 'scavenge_wood_plank':
        return context.l10n.expeditionNarrativeWoodPlank;
      case 'scavenge_food':
      case 'scavenge_small_dead_animal':
        return context.l10n.expeditionNarrativeSmallDeadAnimal;
      case 'scavenge_common_event':
        return context.l10n.expeditionNarrativeCommonEvent;
      default:
        return context.l10n.expeditionNarrativeFallback;
    }
  }

  String _optionLabel(BuildContext context, String labelId) {
    switch (labelId) {
      case 'accept':
        return context.l10n.expeditionOptionAccept;
      default:
        return context.l10n.expeditionOptionFallback;
    }
  }

  String _itemLabel(BuildContext context, String itemId) {
    switch (itemId) {
      case 'scrap_metal':
        return context.l10n.expeditionRewardScrapMetal;
      case 'trash':
        return context.l10n.expeditionRewardTrash;
      case 'wood_plank':
        return context.l10n.expeditionRewardWoodPlank;
      case 'food':
        return context.l10n.expeditionRewardFood;
      default:
        return context.l10n.expeditionRewardUnknown;
    }
  }

  String _optionEffect(
    BuildContext context,
    ExpeditionResolutionOption option,
  ) {
    final parts = <String>[
      for (final reward in option.inventoryDelta.entries)
        '+${reward.value} ${_itemLabel(context, reward.key)}',
    ];
    if (option.eventPoolId != null) {
      parts.add(context.l10n.expeditionCommonEventUnimplemented);
    }
    if (parts.isEmpty) {
      return context.l10n.expeditionNoAdditionalEffects;
    }
    return parts.join(' · ');
  }

  String get _generalImagePath =>
      'assets/expeditions/results/${review.expeditionType}.png';

  String? get _specialImagePath {
    for (final outcome in review.outcomes) {
      final imageKey = outcome.imageKey;
      if (imageKey != null && imageKey.isNotEmpty) {
        return 'assets/expeditions/results/'
            '${review.expeditionType}_$imageKey.png';
      }
    }
    return null;
  }

  bool get _canResolve => review.outcomes.every((outcome) {
        final selected = _selectedOptions[outcome.actionId];
        return selected != null &&
            outcome.resolutionOptions.any((option) => option.id == selected);
      });

  bool get _singleAcceptPath =>
      review.outcomes.length == 1 &&
      review.outcomes.single.resolutionOptions.length == 1 &&
      review.outcomes.single.resolutionOptions.single.labelId == 'accept';

  void _resolve() {
    if (!_canResolve) return;
    Navigator.of(context).pop(
      Map<String, String>.unmodifiable(_selectedOptions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 860),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF181713),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF65563D)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ResultImage(
                  specialAssetPath: _specialImagePath,
                  generalAssetPath: _generalImagePath,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _title(context),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: const Color(0xFFE6D8BD),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.l10n.expeditionCoordinatesValue(
                                      review.coordinates.displayValue,
                                    ),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: const Color(0xFF9D9382),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  context.l10n.expeditionCloseWithoutResolving,
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: const Color(0xFF9E9586),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (var outcomeIndex = 0;
                            outcomeIndex < review.outcomes.length;
                            outcomeIndex++) ...[
                          _OutcomeResolutionSection(
                            outcome: review.outcomes[outcomeIndex],
                            narrative: _narrative(
                              context,
                              review.outcomes[outcomeIndex].narrativeId,
                            ),
                            selectedOptionId:
                                _selectedOptions[
                                    review.outcomes[outcomeIndex].actionId],
                            optionLabel: (option) =>
                                _optionLabel(context, option.labelId),
                            optionEffect: (option) =>
                                _optionEffect(context, option),
                            onSelected: (optionId) {
                              setState(() {
                                _selectedOptions[
                                    review.outcomes[outcomeIndex].actionId] =
                                    optionId;
                              });
                            },
                          ),
                          if (outcomeIndex + 1 < review.outcomes.length)
                            const SizedBox(height: 18),
                        ],
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _canResolve ? _resolve : null,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            _singleAcceptPath
                                ? context.l10n.expeditionOptionAccept
                                : context.l10n.expeditionResolveButton,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            context.l10n.expeditionCloseDecideLater,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _OutcomeResolutionSection extends StatelessWidget {
  const _OutcomeResolutionSection({
    required this.outcome,
    required this.narrative,
    required this.selectedOptionId,
    required this.optionLabel,
    required this.optionEffect,
    required this.onSelected,
  });

  final ExpeditionOutcomeReview outcome;
  final String narrative;
  final String? selectedOptionId;
  final String Function(ExpeditionResolutionOption option) optionLabel;
  final String Function(ExpeditionResolutionOption option) optionEffect;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          narrative,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFC9BDA9),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 14),
        for (final option in outcome.resolutionOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selectedOptionId == option.id
                  ? const Color(0xFF2B281F)
                  : const Color(0xFF211F19),
              borderRadius: BorderRadius.circular(7),
              child: InkWell(
                onTap: () => onSelected(option.id),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: selectedOptionId == option.id
                          ? const Color(0xFFC6AA74)
                          : const Color(0xFF463E32),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        selectedOptionId == option.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: const Color(0xFFC6AA74),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              optionLabel(option),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: const Color(0xFFE0D1B5),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              optionEffect(option),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF9F9687),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({
    required this.specialAssetPath,
    required this.generalAssetPath,
  });

  final String? specialAssetPath;
  final String generalAssetPath;

  @override
  Widget build(BuildContext context) {
    Widget fallbackIllustration() {
      return Container(
        height: 230,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF302A20),
              Color(0xFF171713),
            ],
          ),
        ),
        child: const Stack(
          children: [
            Positioned(
              left: 34,
              bottom: 28,
              child: Icon(
                Icons.construction_rounded,
                size: 76,
                color: Color(0xFF6E6350),
              ),
            ),
            Positioned(
              right: 44,
              top: 34,
              child: Icon(
                Icons.search_rounded,
                size: 92,
                color: Color(0xFFC8AA69),
              ),
            ),
            Positioned(
              right: 105,
              bottom: 27,
              child: Icon(
                Icons.recycling_rounded,
                size: 54,
                color: Color(0xFF8B7957),
              ),
            ),
          ],
        ),
      );
    }

    Widget generalImage() {
      return Image.asset(
        generalAssetPath,
        height: 230,
        width: double.infinity,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => fallbackIllustration(),
      );
    }

    final special = specialAssetPath;
    if (special == null) return generalImage();

    return Image.asset(
      special,
      height: 230,
      width: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => generalImage(),
    );
  }
}
