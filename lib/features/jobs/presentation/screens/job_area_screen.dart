import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/firebase/firestore_item_catalog_service.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/presentation/survival_background.dart';
import '../../../bunker/application/bunker_state_controller.dart';
import '../../../hub/domain/hub_scene_configuration.dart';
import '../../../items/domain/item.dart';
import '../../../survivors/domain/survivor.dart';
import '../../../survivors/presentation/widgets/survivor_profile_photo.dart';
import '../../domain/job_area.dart';
import '../../domain/job_task.dart';
import '../../domain/job_task_service.dart';
import '../job_labels.dart';

bool _survivorMeetsStatRequirements(
  Survivor survivor,
  Map<String, int> requirements,
) {
  return requirements.entries.every(
    (entry) => survivor.effectiveStat(entry.key) > entry.value,
  );
}

String _statLabel(BuildContext context, String stat) {
  switch (stat) {
    case 'strength':
      return context.l10n.statStrength;
    case 'dexterity':
      return context.l10n.statDexterity;
    case 'constitution':
      return context.l10n.statConstitution;
    case 'stealth':
      return context.l10n.statStealth;
    case 'care':
      return context.l10n.statCare;
    case 'cunning':
      return context.l10n.statCunning;
    case 'charm':
      return context.l10n.statCharm;
    default:
      return stat;
  }
}

String? _missingStatRequirementText(
  BuildContext context,
  Survivor survivor,
  Map<String, int> requirements,
) {
  final missing = requirements.entries.where(
    (entry) => survivor.effectiveStat(entry.key) <= entry.value,
  );
  if (missing.isEmpty) return null;

  return missing
      .map(
        (entry) =>
            '${_statLabel(context, entry.key)}: '
            '${survivor.effectiveStat(entry.key)} / > ${entry.value}',
      )
      .join(' · ');
}

class JobAreaScreen extends StatefulWidget {
  const JobAreaScreen({
    super.key,
    required this.area,
    required this.bunkerStateController,
    required this.taskService,
  });

  final JobArea area;
  final BunkerStateController bunkerStateController;
  final JobTaskService taskService;

  @override
  State<JobAreaScreen> createState() => _JobAreaScreenState();
}

class _JobAreaScreenState extends State<JobAreaScreen> {
  final Map<String, JobTaskStartInfo> _startInfoByTaskId =
      <String, JobTaskStartInfo>{};
  String? _startingTaskId;
  bool _isLoadingTaskInfo = true;
  Object? _taskInfoError;

  @override
  void initState() {
    super.initState();
    widget.bunkerStateController.addListener(_onBunkerChanged);
    unawaited(widget.bunkerStateController.refresh());
    unawaited(_loadTaskStartInfo());
  }

  @override
  void dispose() {
    widget.bunkerStateController.removeListener(_onBunkerChanged);
    super.dispose();
  }

  void _onBunkerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTaskStartInfo() async {
    final loaded = <String, JobTaskStartInfo>{};
    Object? firstError;

    for (final task in jobTasksForArea(widget.area)) {
      try {
        loaded[task.id] =
            await widget.taskService.fetchStartInfo(taskId: task.id);
      } catch (error) {
        firstError ??= error;
      }
    }

    if (!mounted) return;
    setState(() {
      _startInfoByTaskId
        ..clear()
        ..addAll(loaded);
      _taskInfoError = firstError;
      _isLoadingTaskInfo = false;
    });
  }

  String _taskTitle(BuildContext context, JobTaskDefinition task) =>
      jobTaskTitle(context, task.id);

  String _taskDescription(BuildContext context, JobTaskDefinition task) =>
      jobTaskDescription(context, task.id);

  Future<void> _startTask(JobTaskDefinition task) async {
    final bunker = widget.bunkerStateController.state;
    if (bunker == null) {
      await widget.bunkerStateController.refresh();
      if (!mounted) return;
    }

    final current = widget.bunkerStateController.state;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.hubJobsLoadError)),
      );
      return;
    }

    final alreadyActive = current.busySurvivors.any(
      (busy) => (busy.taskId ?? busy.activity) == task.id,
    );
    if (alreadyActive) return;

    final startInfo = _startInfoByTaskId[task.id];
    if (startInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.jobTaskStartError)),
      );
      return;
    }

    final completedTaskIds = current.completedTaskIds.toSet();
    final missingPrerequisite = startInfo.requiredTaskIds.any(
      (requiredId) => !completedTaskIds.contains(requiredId),
    );
    if (missingPrerequisite) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.jobTaskStartError)),
      );
      return;
    }

    final available = current.idleSurvivors
        .map(current.survivorById)
        .whereType<Survivor>()
        .where((survivor) => survivor.energy >= 0)
        .toList(growable: false);
    if (available.length < startInfo.minSurvivors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.jobNoIdleSurvivors)),
      );
      return;
    }

    final selected = await showDialog<_TaskAssignmentSelection>(
      context: context,
      barrierColor: const Color(0xB8000000),
      builder: (dialogContext) => _SurvivorTaskDialog(
        survivors: available,
        minSurvivors: startInfo.minSurvivors,
        maxSurvivors: startInfo.maxSurvivors,
        statRequirements: startInfo.statRequirements,
        inventory: current.inventory,
        fixedInventoryCost: startInfo.costInventory,
        resourceCraftingValueRequired:
            startInfo.resourceCraftingValueCost,
        energyCostPerSurvivor: startInfo.energyCostPerSurvivor,
      ),
    );
    if (selected == null || selected.survivors.isEmpty || !mounted) return;

    setState(() => _startingTaskId = task.id);
    try {
      await widget.taskService.startTask(
        taskId: task.id,
        survivorIds:
            selected.survivors.map((survivor) => survivor.id).toList(),
        resourceItems: selected.resourceItems,
      );
      await widget.bunkerStateController.refreshAfterMutation();
      if (!mounted) return;
      final names = selected.survivors
          .map((survivor) => survivorDisplayName(context, survivor))
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.jobTaskStarted}: $names'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.jobTaskStartError)),
      );
    } finally {
      if (mounted) setState(() => _startingTaskId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    final bunkerState = widget.bunkerStateController.state;
    final completedTaskIds = bunkerState?.completedTaskIds.toSet() ?? <String>{};
    final activeTaskIds = bunkerState?.busySurvivors
            .map((busy) => busy.taskId ?? busy.activity)
            .toSet() ??
        <String>{};
    final tasks = jobTasksForArea(area).where((task) {
      if (completedTaskIds.contains(task.id)) return false;
      final startInfo = _startInfoByTaskId[task.id];
      if (startInfo == null) return false;
      return startInfo.requiredTaskIds.every(completedTaskIds.contains);
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SurvivalBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: defaultHubSceneConfiguration.canvasSize.width,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF11110E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF514634)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Column(
                          children: [
                            _JobAreaTopBar(
                              title: jobAreaTitle(context, area),
                              onBack: () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _JobAreaCover(
                                      area: area,
                                      gardenPrepared: completedTaskIds
                                          .contains('prepare_garden'),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        22,
                                        24,
                                        36,
                                      ),
                                      child: _JobAreaContent(
                                        area: area,
                                        tasks: tasks,
                                        activeTaskIds: activeTaskIds,
                                        startingTaskId: _startingTaskId,
                                        taskInfoLoading: _isLoadingTaskInfo,
                                        taskInfoError: _taskInfoError,
                                        startInfoByTaskId: _startInfoByTaskId,
                                        inventory: bunkerState?.inventory ??
                                            const <String, int>{},
                                        taskTitle: (task) =>
                                            _taskTitle(context, task),
                                        taskDescription: (task) =>
                                            _taskDescription(context, task),
                                        onStartTask: _startTask,
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _JobAreaTopBar extends StatelessWidget {
  const _JobAreaTopBar({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF171713),
        border: Border(
          bottom: BorderSide(color: Color(0xFF554A3A)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xFFD8C5A0),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFE6D8BD),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobAreaCover extends StatelessWidget {
  const _JobAreaCover({
    required this.area,
    required this.gardenPrepared,
  });

  final JobArea area;
  final bool gardenPrepared;

  Widget _fallback(BuildContext context) {
    final legacyAssetPath = area.legacyCoverAssetPath;
    if (legacyAssetPath != null) {
      return Image.asset(
        legacyAssetPath,
        key: ValueKey<String>(legacyAssetPath),
        width: double.infinity,
        fit: BoxFit.fitWidth,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _emptyFallback(),
      );
    }
    return _emptyFallback();
  }

  Widget _emptyFallback() {
    return Container(
      width: double.infinity,
      height: 240,
      color: const Color(0xFF242019),
      alignment: Alignment.center,
      child: Icon(
        jobAreaIcon(area),
        size: 56,
        color: const Color(0xFFAD9365),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = area.coverAssetPathFor(
      gardenPrepared: gardenPrepared,
    );
    return Image.asset(
      assetPath,
      key: ValueKey<String>(assetPath),
      width: double.infinity,
      fit: BoxFit.fitWidth,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => _fallback(context),
    );
  }
}

class _TaskRequirementStatus {
  const _TaskRequirementStatus({
    required this.label,
    required this.current,
    required this.required,
  });

  final String label;
  final int current;
  final int required;

  bool get isMet => current >= required;
}

class _JobAreaContent extends StatelessWidget {
  const _JobAreaContent({
    required this.area,
    required this.tasks,
    required this.activeTaskIds,
    required this.startingTaskId,
    required this.taskInfoLoading,
    required this.taskInfoError,
    required this.startInfoByTaskId,
    required this.inventory,
    required this.taskTitle,
    required this.taskDescription,
    required this.onStartTask,
  });

  final JobArea area;
  final List<JobTaskDefinition> tasks;
  final Set<String> activeTaskIds;
  final String? startingTaskId;
  final bool taskInfoLoading;
  final Object? taskInfoError;
  final Map<String, JobTaskStartInfo> startInfoByTaskId;
  final Map<String, int> inventory;
  final String Function(JobTaskDefinition task) taskTitle;
  final String Function(JobTaskDefinition task) taskDescription;
  final ValueChanged<JobTaskDefinition> onStartTask;

  int _availableCraftingValue(
    JobTaskStartInfo startInfo,
    Map<String, Item> catalog,
  ) {
    var total = 0;
    for (final entry in inventory.entries) {
      final item = catalog[entry.key];
      final craftingValue = item?.craftingValue;
      if (item == null || !item.isCraftingResource || craftingValue == null) {
        continue;
      }
      final reserved = startInfo.costInventory[entry.key] ?? 0;
      final available = entry.value - reserved;
      if (available > 0) total += available * craftingValue;
    }
    return total;
  }

  List<_TaskRequirementStatus> _requirementsFor(
    BuildContext context,
    JobTaskStartInfo startInfo,
    Map<String, Item> catalog,
  ) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final result = <_TaskRequirementStatus>[];

    for (final entry in startInfo.costInventory.entries) {
      final item = catalog[entry.key];
      result.add(
        _TaskRequirementStatus(
          label: item?.nameForLanguage(languageCode) ?? entry.key,
          current: inventory[entry.key] ?? 0,
          required: entry.value,
        ),
      );
    }

    if (startInfo.resourceCraftingValueCost > 0) {
      result.add(
        _TaskRequirementStatus(
          label: context.l10n.jobGenericResourcesLabel,
          current: _availableCraftingValue(startInfo, catalog),
          required: startInfo.resourceCraftingValueCost,
        ),
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          jobAreaTitle(context, area),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFFE6D8BD),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          jobAreaDescription(context, area),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFA79E8E),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 26),
        Text(
          context.l10n.jobAvailableTasksTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFFE3D4B7),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (taskInfoLoading)
          _EmptyTasks(message: context.l10n.hubJobsLoading)
        else if (tasks.isEmpty && taskInfoError != null)
          _EmptyTasks(message: context.l10n.hubJobsLoadError)
        else if (tasks.isEmpty)
          _EmptyTasks(message: context.l10n.jobNoAvailableTasks)
        else
          StreamBuilder<Map<String, Item>>(
            stream: FirestoreItemCatalogService.instance.watchCatalog(),
            builder: (context, snapshot) {
              final catalog = snapshot.data ?? const <String, Item>{};
              return Column(
                children: [
                  for (final task in tasks) ...[
                    Builder(
                      builder: (context) {
                        final startInfo = startInfoByTaskId[task.id];
                        final requirements = startInfo == null
                            ? const <_TaskRequirementStatus>[]
                            : _requirementsFor(context, startInfo, catalog);
                        return _TaskTile(
                          title: taskTitle(task),
                          description: taskDescription(task),
                          requirements: requirements,
                          energyCostPerSurvivor:
                              startInfo?.energyCostPerSurvivor ?? 0,
                          isStarting: startingTaskId == task.id,
                          isActive: activeTaskIds.contains(task.id),
                          onTap: startingTaskId == null &&
                                  !activeTaskIds.contains(task.id)
                              ? () => onStartTask(task)
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}
class _TaskAssignmentSelection {
  const _TaskAssignmentSelection({
    required this.survivors,
    required this.resourceItems,
  });

  final List<Survivor> survivors;
  final Map<String, int> resourceItems;
}

class _ResourceOption {
  const _ResourceOption({
    required this.item,
    required this.availableQuantity,
    required this.craftingValue,
  });

  final Item item;
  final int availableQuantity;
  final int craftingValue;
}

class _SurvivorTaskDialog extends StatefulWidget {
  const _SurvivorTaskDialog({
    required this.survivors,
    required this.minSurvivors,
    required this.maxSurvivors,
    required this.statRequirements,
    required this.inventory,
    required this.fixedInventoryCost,
    required this.resourceCraftingValueRequired,
    required this.energyCostPerSurvivor,
  });

  final List<Survivor> survivors;
  final int minSurvivors;
  final int maxSurvivors;
  final Map<String, int> statRequirements;
  final Map<String, int> inventory;
  final Map<String, int> fixedInventoryCost;
  final int resourceCraftingValueRequired;
  final int energyCostPerSurvivor;

  @override
  State<_SurvivorTaskDialog> createState() => _SurvivorTaskDialogState();
}

class _SurvivorTaskDialogState extends State<_SurvivorTaskDialog> {
  final Set<String> _selectedIds = <String>{};
  final Map<String, int> _selectedResourceQuantities = <String, int>{};
  late final Stream<Map<String, Item>> _catalogStream;

  @override
  void initState() {
    super.initState();
    _catalogStream = FirestoreItemCatalogService.instance.watchCatalog();
  }

  bool get _survivorsCanConfirm =>
      _selectedIds.length >= widget.minSurvivors &&
      _selectedIds.length <= widget.maxSurvivors;

  bool get _fixedInventorySatisfied =>
      widget.fixedInventoryCost.entries.every(
        (entry) => (widget.inventory[entry.key] ?? 0) >= entry.value,
      );

  int _selectedResourceValue(Map<String, Item> catalog) {
    var total = 0;
    for (final entry in _selectedResourceQuantities.entries) {
      final craftingValue = catalog[entry.key]?.craftingValue;
      if (craftingValue == null) continue;
      total += craftingValue * entry.value;
    }
    return total;
  }

  List<_TaskRequirementStatus> _requirementStatuses(
    BuildContext context,
    Map<String, Item> catalog,
  ) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final result = <_TaskRequirementStatus>[];

    for (final entry in widget.fixedInventoryCost.entries) {
      result.add(
        _TaskRequirementStatus(
          label: catalog[entry.key]?.nameForLanguage(languageCode) ?? entry.key,
          current: widget.inventory[entry.key] ?? 0,
          required: entry.value,
        ),
      );
    }

    if (widget.resourceCraftingValueRequired > 0) {
      result.add(
        _TaskRequirementStatus(
          label: context.l10n.jobGenericResourcesLabel,
          current: _selectedResourceValue(catalog),
          required: widget.resourceCraftingValueRequired,
        ),
      );
    }

    return result;
  }

  bool _canConfirm(Map<String, Item> catalog) {
    if (!_survivorsCanConfirm || !_fixedInventorySatisfied) return false;
    if (widget.resourceCraftingValueRequired <= 0) return true;
    return _selectedResourceValue(catalog) >=
        widget.resourceCraftingValueRequired;
  }

  List<_ResourceOption> _resourceOptions(Map<String, Item> catalog) {
    final options = <_ResourceOption>[];
    for (final inventoryEntry in widget.inventory.entries) {
      final item = catalog[inventoryEntry.key];
      final craftingValue = item?.craftingValue;
      if (item == null || !item.isCraftingResource || craftingValue == null) {
        continue;
      }

      final reserved = widget.fixedInventoryCost[inventoryEntry.key] ?? 0;
      final available = inventoryEntry.value - reserved;
      if (available <= 0) continue;

      options.add(
        _ResourceOption(
          item: item,
          availableQuantity: available,
          craftingValue: craftingValue,
        ),
      );
    }
    return options;
  }

  void _toggle(Survivor survivor) {
    if (!_survivorMeetsStatRequirements(survivor, widget.statRequirements)) {
      return;
    }

    setState(() {
      if (_selectedIds.remove(survivor.id)) return;
      if (_selectedIds.length < widget.maxSurvivors) {
        _selectedIds.add(survivor.id);
      }
    });
  }

  void _changeResourceQuantity(
    String itemId,
    int delta,
    int availableQuantity,
  ) {
    setState(() {
      final current = _selectedResourceQuantities[itemId] ?? 0;
      final next = (current + delta).clamp(0, availableQuantity).toInt();
      if (next == 0) {
        _selectedResourceQuantities.remove(itemId);
      } else {
        _selectedResourceQuantities[itemId] = next;
      }
    });
  }

  void _confirm(Map<String, Item> catalog) {
    if (!_canConfirm(catalog)) return;
    final selectedSurvivors = widget.survivors
        .where((survivor) => _selectedIds.contains(survivor.id))
        .toList(growable: false);
    final selectedResources = Map<String, int>.fromEntries(
      _selectedResourceQuantities.entries.where((entry) => entry.value > 0),
    );
    Navigator.of(context).pop(
      _TaskAssignmentSelection(
        survivors: selectedSurvivors,
        resourceItems: selectedResources,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requiresResources = widget.resourceCraftingValueRequired > 0;
    final needsCatalog =
        requiresResources || widget.fixedInventoryCost.isNotEmpty;

    return StreamBuilder<Map<String, Item>>(
      stream: needsCatalog ? _catalogStream : null,
      builder: (context, snapshot) {
        final catalog = snapshot.data ?? const <String, Item>{};
        final requirements = _requirementStatuses(context, catalog);
        final missingRequirements =
            requirements.where((requirement) => !requirement.isMet).toList();
        final resourceOptions = _resourceOptions(catalog);
        final languageCode = Localizations.localeOf(context).languageCode;
        resourceOptions.sort(
          (a, b) => a.item
              .nameForLanguage(languageCode)
              .compareTo(b.item.nameForLanguage(languageCode)),
        );
        final selectedResourceValue = _selectedResourceValue(catalog);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A261E),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF514634),
                              ),
                            ),
                            child: const Icon(
                              Icons.groups_2_outlined,
                              color: Color(0xFFC7A970),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.jobChooseSurvivorTitle,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFFE6D8BD),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.jobChooseSurvivorDescription,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF9B9284),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_selectedIds.length} / '
                                  '${widget.minSurvivors}-'
                                  '${widget.maxSurvivors}',
                                  style:
                                      theme.textTheme.labelMedium?.copyWith(
                                    color: const Color(0xFFC7A970),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.energyCostPerSurvivor > 0) ...[
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.bolt_rounded,
                                        size: 15,
                                        color: Color(0xFFC8A968),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${context.l10n.jobEnergyCostLabel}: '
                                          '${widget.energyCostPerSurvivor} '
                                          '${context.l10n.jobPerSurvivorLabel}',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: const Color(0xFFB9AF9D),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                    ),
                    const Divider(height: 1, color: Color(0xFF4A4134)),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(14),
                        children: [
                          if (requirements.isNotEmpty) ...[
                            Text(
                              context.l10n.jobRequirementsLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFFE6D8BD),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final requirement in requirements)
                                  _RequirementBadge(
                                    requirement: requirement,
                                  ),
                              ],
                            ),
                            if (missingRequirements.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.jobRequirementsMissingHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFD29C86),
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            const Divider(
                              height: 1,
                              color: Color(0xFF4A4134),
                            ),
                            const SizedBox(height: 18),
                          ],
                          for (var index = 0;
                              index < widget.survivors.length;
                              index++) ...[
                            Builder(
                              builder: (context) {
                                final survivor = widget.survivors[index];
                                final selected =
                                    _selectedIds.contains(survivor.id);
                                final meetsRequirements =
                                    _survivorMeetsStatRequirements(
                                  survivor,
                                  widget.statRequirements,
                                );
                                final enabled = meetsRequirements &&
                                    (selected ||
                                        _selectedIds.length <
                                            widget.maxSurvivors);
                                return _SurvivorChoice(
                                  survivor: survivor,
                                  selected: selected,
                                  enabled: enabled,
                                  restrictionText: meetsRequirements
                                      ? null
                                      : _missingStatRequirementText(
                                          context,
                                          survivor,
                                          widget.statRequirements,
                                        ),
                                  onTap: () => _toggle(survivor),
                                );
                              },
                            ),
                            if (index + 1 < widget.survivors.length)
                              const SizedBox(height: 10),
                          ],
                          if (requiresResources) ...[
                            const SizedBox(height: 20),
                            const Divider(
                              height: 1,
                              color: Color(0xFF4A4134),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              context.l10n.jobResourceSelectionTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFFE6D8BD),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              context.l10n.jobResourceSelectionDescription,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF9B9284),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${context.l10n.jobResourceValueLabel}: '
                              '$selectedResourceValue / '
                              '${widget.resourceCraftingValueRequired}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: selectedResourceValue >=
                                        widget.resourceCraftingValueRequired
                                    ? const Color(0xFF9FC493)
                                    : const Color(0xFFC7A970),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (snapshot.hasError)
                              Text(
                                context.l10n.jobNoEligibleResources,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFB08C75),
                                ),
                              )
                            else if (!snapshot.hasData)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(14),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (resourceOptions.isEmpty)
                              Text(
                                context.l10n.jobNoEligibleResources,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFB08C75),
                                ),
                              )
                            else
                              for (var index = 0;
                                  index < resourceOptions.length;
                                  index++) ...[
                                _ResourceChoice(
                                  option: resourceOptions[index],
                                  selectedQuantity:
                                      _selectedResourceQuantities[
                                              resourceOptions[index].item.id]
                                          ??
                                          0,
                                  onChanged: (delta) =>
                                      _changeResourceQuantity(
                                    resourceOptions[index].item.id,
                                    delta,
                                    resourceOptions[index]
                                        .availableQuantity,
                                  ),
                                ),
                                if (index + 1 < resourceOptions.length)
                                  const SizedBox(height: 8),
                              ],
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF4A4134)),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _canConfirm(catalog)
                              ? () => _confirm(catalog)
                              : null,
                          child: Text(context.l10n.jobTaskStartButton),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResourceChoice extends StatelessWidget {
  const _ResourceChoice({
    required this.option,
    required this.selectedQuantity,
    required this.onChanged,
  });

  final _ResourceOption option;
  final int selectedQuantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final item = option.item;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF211F19),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selectedQuantity > 0
              ? const Color(0xFF8D7A54)
              : const Color(0xFF443D31),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Image.asset(
              item.assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.construction_rounded,
                color: Color(0xFFB79B68),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameForLanguage(languageCode),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFE0D1B5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${option.availableQuantity} '
                  '${context.l10n.jobResourceAvailableLabel} · '
                  '${option.craftingValue} '
                  '${context.l10n.jobResourcePerUnitLabel}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF9B9284),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                selectedQuantity > 0 ? () => onChanged(-1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$selectedQuantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFFE0D1B5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: selectedQuantity < option.availableQuantity
                ? () => onChanged(1)
                : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
class _SurvivorChoice extends StatelessWidget {
  const _SurvivorChoice({
    required this.survivor,
    required this.selected,
    required this.enabled,
    required this.restrictionText,
    required this.onTap,
  });

  final Survivor survivor;
  final bool selected;
  final bool enabled;
  final String? restrictionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected ? const Color(0xFF2B281F) : const Color(0xFF211F19),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                SurvivorProfilePhoto(
                  survivor: survivor,
                  size: 72,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        survivorDisplayName(context, survivor),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFE5D6BA),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B281F),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4A4234)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: Color(0xFFC8A968),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${context.l10n.jobEnergyLabel}: ${survivor.energy}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFFB9AF9D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (restrictionText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          restrictionText!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFD29C86),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.title,
    required this.description,
    required this.requirements,
    required this.energyCostPerSurvivor,
    required this.isStarting,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final String description;
  final List<_TaskRequirementStatus> requirements;
  final int energyCostPerSurvivor;
  final bool isStarting;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isActive ? const Color(0xFF25221B) : const Color(0xFF1B1A16),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF7A6745)
                  : const Color(0xFF4E4537),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  isActive
                      ? Icons.hourglass_top_rounded
                      : Icons.task_alt_rounded,
                  color: const Color(0xFFC0A46F),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFE4D5B8),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9F9687),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (energyCostPerSurvivor > 0) ...[
                      const SizedBox(height: 9),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: Color(0xFFC8A968),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${context.l10n.jobEnergyCostLabel}: '
                            '$energyCostPerSurvivor '
                            '${context.l10n.jobPerSurvivorLabel}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: const Color(0xFFBEB39E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (requirements.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        context.l10n.jobRequirementsLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFFC5B596),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final requirement in requirements)
                            _RequirementBadge(requirement: requirement),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              if (isStarting)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isActive)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timelapse_rounded,
                      size: 18,
                      color: Color(0xFFC7A970),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.jobTaskInProgress,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFC7A970),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD4B77D),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementBadge extends StatelessWidget {
  const _RequirementBadge({required this.requirement});

  final _TaskRequirementStatus requirement;

  @override
  Widget build(BuildContext context) {
    final met = requirement.isMet;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: met ? const Color(0xFF202B20) : const Color(0xFF30211D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: met ? const Color(0xFF597052) : const Color(0xFF81594D),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_rounded : Icons.warning_amber_rounded,
            size: 14,
            color: met ? const Color(0xFF9FC493) : const Color(0xFFD29C86),
          ),
          const SizedBox(width: 5),
          Text(
            '${requirement.label}: '
            '${requirement.current}/${requirement.required}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: met
                      ? const Color(0xFFB6CDAE)
                      : const Color(0xFFDDB0A0),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A16),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF403A30)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF8F8677),
            ),
      ),
    );
  }
}
