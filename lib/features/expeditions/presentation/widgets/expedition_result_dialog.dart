import 'package:flutter/material.dart';

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

  String _text(BuildContext context, String es, String en) {
    return Localizations.localeOf(context).languageCode == 'es' ? es : en;
  }

  String _title(BuildContext context) {
    switch (review.expeditionType) {
      case 'scavenge':
        return _text(context, 'Informe de rebusca', 'Scavenge report');
      default:
        return _text(context, 'Informe de expedición', 'Expedition report');
    }
  }

  String _narrative(BuildContext context, String narrativeId) {
    switch (narrativeId) {
      case 'scavenge_nothing':
        return _text(
          context,
          'Tras rebuscar durante un buen rato entre polvo y restos, el grupo vuelve con las manos vacías. Nada de lo encontrado merecía cargarlo de vuelta.',
          'After searching through dust and debris for a long while, the group returns empty-handed. Nothing they found was worth carrying back.',
        );
      case 'scavenge_scrap_and_trash':
        return _text(
          context,
          'Bajo una pila de paneles rotos encuentran una caja aplastada. Dentro queda algo de metal aprovechable y un montón de basura que quizá todavía sirva para algo.',
          'Under a pile of broken panels they find a crushed box. There is some usable metal inside, along with a heap of trash that might still be useful.',
        );
      case 'scavenge_scrap_metal_2':
        return _text(
          context,
          'Los restos de una vieja estructura ceden tras unos cuantos tirones. Consiguen separar dos piezas de metal suficientemente enteras como para reutilizarlas.',
          'The remains of an old structure give way after a few hard pulls. They manage to free two pieces of metal intact enough to reuse.',
        );
      case 'scavenge_wood_plank':
        return _text(
          context,
          'Entre los escombros aparece un tablón de madera sorprendentemente entero. Está sucio y astillado, pero aún puede aprovecharse.',
          'Among the rubble they find a surprisingly intact wooden plank. It is dirty and splintered, but still usable.',
        );
      case 'scavenge_food':
        return _text(
          context,
          'En un rincón protegido encuentran un pequeño pájaro muerto hace poco. No es una comida agradable, pero la carne todavía parece aprovechable.',
          'In a sheltered corner they find a small bird that died recently. It is not an appetizing meal, but the meat still appears usable.',
        );
      case 'scavenge_common_event':
        return _text(
          context,
          'Mientras registran la zona ocurre algo fuera de lo habitual. El informe deja constancia de ello para decidir cómo proceder.',
          'Something unusual happens while they search the area. The report records it so you can decide how to proceed.',
        );
      default:
        return _text(
          context,
          'La expedición ha terminado y el informe está esperando una decisión.',
          'The expedition is complete and the report is waiting for a decision.',
        );
    }
  }

  String _optionLabel(BuildContext context, String labelId) {
    switch (labelId) {
      case 'accept':
        return _text(context, 'Aceptar', 'Accept');
      default:
        return labelId.replaceAll('_', ' ');
    }
  }

  String _itemLabel(BuildContext context, String itemId) {
    switch (itemId) {
      case 'scrap_metal':
        return _text(context, 'Chatarra', 'Scrap metal');
      case 'trash':
        return _text(context, 'Basura', 'Trash');
      case 'wood_plank':
        return _text(context, 'Tablón de madera', 'Wood plank');
      case 'food':
        return _text(context, 'Comida', 'Food');
      default:
        return itemId;
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
      parts.add(
        _text(
          context,
          'activa una posible continuación',
          'may trigger a follow-up',
        ),
      );
    }
    if (parts.isEmpty) {
      return _text(
        context,
        'Sin efectos adicionales.',
        'No additional effects.',
      );
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
                                    _text(
                                      context,
                                      'Coordenadas: ${review.coordinates.displayValue}',
                                      'Coordinates: ${review.coordinates.displayValue}',
                                    ),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: const Color(0xFF9D9382),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: _text(
                                context,
                                'Cerrar sin resolver',
                                'Close without resolving',
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: const Color(0xFF9E9586),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const _ResolutionPhaseBanner(),
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
                                ? _text(context, 'Aceptar', 'Accept')
                                : _text(
                                    context,
                                    'Resolver expedición',
                                    'Resolve expedition',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            _text(
                              context,
                              'Cerrar y decidir más tarde',
                              'Close and decide later',
                            ),
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

class _ResolutionPhaseBanner extends StatelessWidget {
  const _ResolutionPhaseBanner();

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF211F19),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF4A4134)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: Color(0xFF8EAD79),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              es
                  ? 'Resolución automática completada. Falta tu decisión.'
                  : 'Automatic resolution completed. Your decision is pending.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB9AF9D),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
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
