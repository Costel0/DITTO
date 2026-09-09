import 'package:flutter/material.dart';

import '../../domain/expedition_review.dart';

class ExpeditionResultDialog extends StatelessWidget {
  const ExpeditionResultDialog({
    super.key,
    required this.review,
  });

  final ExpeditionReview review;

  static Future<void> show(
    BuildContext context, {
    required ExpeditionReview review,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0xC0000000),
      builder: (_) => ExpeditionResultDialog(review: review),
    );
  }

  String _text(BuildContext context, String es, String en) {
    return Localizations.localeOf(context).languageCode == 'es' ? es : en;
  }

  String _title(BuildContext context) {
    switch (review.expeditionType) {
      case 'scavenge':
        return _text(context, 'Resultado de rebusca', 'Scavenge result');
      default:
        return _text(context, 'Resultado de expedición', 'Expedition result');
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
          'Mientras registran la zona ocurre algo fuera de lo habitual. Por ahora no hay ningún evento implementado que continúe esta situación.',
          'Something unusual happens while they search the area. There is no implemented event yet to continue this situation.',
        );
      default:
        return _text(
          context,
          'La expedición ha terminado y el informe ya está disponible.',
          'The expedition is complete and its report is now available.',
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rewards = review.inventoryDelta.entries.toList(growable: false);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
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
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: const Color(0xFF9E9586),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (var index = 0;
                            index < review.outcomes.length;
                            index++) ...[
                          Text(
                            _narrative(
                              context,
                              review.outcomes[index].narrativeId,
                            ),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFFC9BDA9),
                              height: 1.55,
                            ),
                          ),
                          if (index + 1 < review.outcomes.length)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          _text(context, 'Recompensa', 'Reward'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFFE0D1B5),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (rewards.isEmpty)
                          _RewardRow(
                            icon: Icons.remove_circle_outline_rounded,
                            label: _text(
                              context,
                              'No se ha recuperado ningún objeto.',
                              'No items were recovered.',
                            ),
                          )
                        else
                          for (final reward in rewards)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _RewardRow(
                                icon: Icons.inventory_2_outlined,
                                label:
                                    '+${reward.value} ${_itemLabel(context, reward.key)}',
                              ),
                            ),
                        for (final outcome in review.outcomes)
                          if (outcome.eventPoolId != null) ...[
                            const SizedBox(height: 8),
                            _RewardRow(
                              icon: Icons.auto_awesome_outlined,
                              label: _text(
                                context,
                                'Evento común detectado · todavía sin resolver',
                                'Common event detected · not resolved yet',
                              ),
                            ),
                          ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(_text(context, 'Cerrar informe', 'Close report')),
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

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF211F19),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF463E32)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFC7A970)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFD1C3AA),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
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
