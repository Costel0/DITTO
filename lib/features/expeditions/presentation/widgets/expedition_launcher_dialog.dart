import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/l10n.dart';
import '../../../survivors/domain/survivor.dart';
import '../../../survivors/presentation/duplicate_presentation.dart';
import '../../../survivors/presentation/widgets/survivor_profile_photo.dart';
import '../../domain/expedition.dart';

class ExpeditionLaunchSelection {
  const ExpeditionLaunchSelection({
    required this.survivorIds,
    required this.coordinates,
    required this.actionIds,
  });

  final List<String> survivorIds;
  final ExpeditionCoordinates coordinates;
  final List<String> actionIds;
}

class ExpeditionLauncherDialog extends StatefulWidget {
  const ExpeditionLauncherDialog({
    super.key,
    required this.info,
    required this.survivors,
  });

  final ExpeditionLauncherInfo info;
  final List<Survivor> survivors;

  static Future<ExpeditionLaunchSelection?> show(
    BuildContext context, {
    required ExpeditionLauncherInfo info,
    required List<Survivor> survivors,
  }) {
    return showDialog<ExpeditionLaunchSelection>(
      context: context,
      barrierColor: const Color(0xB8000000),
      builder: (_) => ExpeditionLauncherDialog(
        info: info,
        survivors: survivors,
      ),
    );
  }

  @override
  State<ExpeditionLauncherDialog> createState() =>
      _ExpeditionLauncherDialogState();
}

class _ExpeditionLauncherDialogState extends State<ExpeditionLauncherDialog> {
  final Set<String> _selectedSurvivorIds = <String>{};
  final Set<String> _selectedActionIds = <String>{};
  late final TextEditingController _letterController;
  late final TextEditingController _numberController;
  late final TextEditingController _zoneController;

  @override
  void initState() {
    super.initState();
    final coordinates = widget.info.bunkerCoordinates;
    _letterController = TextEditingController(text: coordinates.sectorLetter);
    _numberController =
        TextEditingController(text: coordinates.sectorNumber.toString());
    _zoneController = TextEditingController(text: coordinates.zoneIndex.toString());
  }

  @override
  void dispose() {
    _letterController.dispose();
    _numberController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  ExpeditionCoordinates? get _coordinates {
    final letter = _letterController.text.trim().toUpperCase();
    final number = int.tryParse(_numberController.text.trim());
    final zone = int.tryParse(_zoneController.text.trim());
    if (!RegExp(r'^[A-Z]$').hasMatch(letter) ||
        number == null ||
        number < 1 ||
        zone == null ||
        zone < 1 ||
        zone > widget.info.zonesPerSector) {
      return null;
    }
    return ExpeditionCoordinates(
      sectorLetter: letter,
      sectorNumber: number,
      zoneIndex: zone,
    );
  }

  ExpeditionKnownZone? get _knownZone {
    final coordinates = _coordinates;
    return coordinates == null ? null : widget.info.knownZoneAt(coordinates);
  }

  List<ExpeditionActionDefinition> get _availableActions {
    final coordinates = _coordinates;
    if (coordinates == null) return const <ExpeditionActionDefinition>[];
    return widget.info.actionsForCoordinates(coordinates);
  }

  bool get _canConfirm {
    final coordinates = _coordinates;
    if (coordinates == null || _selectedSurvivorIds.isEmpty) return false;
    final availableIds = _availableActions.map((action) => action.id).toSet();
    return _selectedActionIds.isNotEmpty &&
        _selectedActionIds.every(availableIds.contains);
  }

  String _actionTitle(BuildContext context, String actionId) {
    switch (actionId) {
      case 'explore':
        return Localizations.localeOf(context).languageCode == 'es'
            ? 'Explorar'
            : 'Explore';
      case 'scavenge':
      case 'scout_surroundings':
        return context.l10n.expeditionScoutSurroundingsTitle;
      default:
        return context.l10n.expeditionActionFallbackTitle;
    }
  }

  String _zoneKnowledgeLabel(BuildContext context) {
    final coordinates = _coordinates;
    if (coordinates == null) return '';
    final known = _knownZone;
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    if (known == null) {
      return spanish ? 'Zona desconocida' : 'Unknown zone';
    }
    return spanish
        ? 'Zona conocida · ${known.zoneType}'
        : 'Known zone · ${known.zoneType}';
  }

  void _coordinatesChanged() {
    setState(() {
      final availableIds = _availableActions.map((action) => action.id).toSet();
      _selectedActionIds.removeWhere(
        (actionId) => !availableIds.contains(actionId),
      );
    });
  }

  void _toggleSurvivor(Survivor survivor) {
    setState(() {
      if (!_selectedSurvivorIds.remove(survivor.id)) {
        _selectedSurvivorIds.add(survivor.id);
      }
    });
  }

  void _toggleAction(String actionId) {
    setState(() {
      if (!_selectedActionIds.remove(actionId)) {
        _selectedActionIds.add(actionId);
      }
    });
  }

  void _confirm() {
    final coordinates = _coordinates;
    if (!_canConfirm || coordinates == null) return;
    Navigator.of(context).pop(
      ExpeditionLaunchSelection(
        survivorIds: List<String>.unmodifiable(_selectedSurvivorIds),
        coordinates: coordinates,
        actionIds: List<String>.unmodifiable(_selectedActionIds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = _availableActions;
    final coordinates = _coordinates;
    final travelSeconds = coordinates == null
        ? 0
        : widget.info.travelSecondsTo(coordinates);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF181713),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF5A4E3C)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.explore_rounded,
                        color: Color(0xFFC7A970),
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.expeditionLauncherTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: const Color(0xFFE6D8BD),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF9E9586),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF4A4134)),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SectionTitle(
                        title: context.l10n.expeditionSurvivorsTitle,
                      ),
                      const SizedBox(height: 10),
                      if (widget.survivors.isEmpty)
                        Text(
                          context.l10n.expeditionNoSurvivorsAvailable,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB08C75),
                          ),
                        )
                      else
                        for (var index = 0;
                            index < widget.survivors.length;
                            index++) ...[
                          _ExpeditionSurvivorChoice(
                            survivor: widget.survivors[index],
                            selected: _selectedSurvivorIds
                                .contains(widget.survivors[index].id),
                            onTap: () =>
                                _toggleSurvivor(widget.survivors[index]),
                          ),
                          if (index + 1 < widget.survivors.length)
                            const SizedBox(height: 8),
                        ],
                      const SizedBox(height: 22),
                      _SectionTitle(
                        title: context.l10n.expeditionCoordinatesTitle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.expeditionCoordinatesDescription(
                          widget.info.bunkerCoordinates.displayValue,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF9B9284),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _LetterCoordinateField(
                              controller: _letterController,
                              onChanged: _coordinatesChanged,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _NumberCoordinateField(
                              label: 'Sector',
                              controller: _numberController,
                              onChanged: _coordinatesChanged,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _NumberCoordinateField(
                              label: Localizations.localeOf(context).languageCode == 'es'
                                  ? 'Zona'
                                  : 'Zone',
                              controller: _zoneController,
                              onChanged: _coordinatesChanged,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _zoneKnowledgeLabel(context),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _knownZone == null
                              ? const Color(0xFFC7A970)
                              : const Color(0xFFA6AD91),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (coordinates != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${coordinates.displayValue} · '
                          '${_durationLabel(context, travelSeconds)} '
                          '${Localizations.localeOf(context).languageCode == 'es' ? 'de viaje' : 'travel'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF8F8677),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _SectionTitle(
                        title: context.l10n.expeditionActionsTitle,
                      ),
                      const SizedBox(height: 10),
                      if (actions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF211F19),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0xFF4A4134)),
                          ),
                          child: Text(
                            context.l10n.expeditionNoActionsAtCoordinates,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFB08C75),
                            ),
                          ),
                        )
                      else
                        for (var index = 0; index < actions.length; index++) ...[
                          _ExpeditionActionChoice(
                            action: actions[index],
                            title: _actionTitle(context, actions[index].id),
                            effectiveDurationSeconds:
                                actions[index].durationSeconds + travelSeconds,
                            selected:
                                _selectedActionIds.contains(actions[index].id),
                            onTap: () => _toggleAction(actions[index].id),
                          ),
                          if (index + 1 < actions.length)
                            const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF4A4134)),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _canConfirm ? _confirm : null,
                      icon: const Icon(Icons.hiking_rounded),
                      label: Text(context.l10n.expeditionStartButton),
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

String _durationLabel(BuildContext context, int seconds) {
  final duration = Duration(seconds: seconds);
  if (duration.inSeconds % 60 == 0) {
    return context.l10n.expeditionDurationMinutes(duration.inMinutes);
  }
  return context.l10n.expeditionDurationSeconds(duration.inSeconds);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFFE6D8BD),
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _LetterCoordinateField extends StatelessWidget {
  const _LetterCoordinateField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
        LengthLimitingTextInputFormatter(1),
      ],
      onChanged: (_) => onChanged(),
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: 'A-Z',
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _NumberCoordinateField extends StatelessWidget {
  const _NumberCoordinateField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (_) => onChanged(),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ExpeditionSurvivorChoice extends StatelessWidget {
  const _ExpeditionSurvivorChoice({
    required this.survivor,
    required this.selected,
    required this.onTap,
  });

  final Survivor survivor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? const Color(0xFF2B281F) : const Color(0xFF211F19),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC6AA74)
                  : const Color(0xFF443D31),
            ),
          ),
          child: Row(
            children: [
              SurvivorProfilePhoto(survivor: survivor, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  duplicateDisplayName(context, survivor.duplicateId),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFFE5D6BA),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.bolt_rounded,
                size: 16,
                color: Color(0xFFC8A968),
              ),
              const SizedBox(width: 3),
              Text(
                survivor.energy.toString(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFB9AF9D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: const Color(0xFFC6AA74),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpeditionActionChoice extends StatelessWidget {
  const _ExpeditionActionChoice({
    required this.action,
    required this.title,
    required this.effectiveDurationSeconds,
    required this.selected,
    required this.onTap,
  });

  final ExpeditionActionDefinition action;
  final String title;
  final int effectiveDurationSeconds;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? const Color(0xFF2B281F) : const Color(0xFF211F19),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC6AA74)
                  : const Color(0xFF443D31),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: const Color(0xFFC6AA74),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFE5D6BA),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          _durationLabel(context, effectiveDurationSeconds),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF9B9284),
                          ),
                        ),
                        Text(
                          '${context.l10n.jobEnergyCostLabel}: '
                          '${action.energyCostPerSurvivor} '
                          '${context.l10n.jobPerSurvivorLabel}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFC8A968),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
