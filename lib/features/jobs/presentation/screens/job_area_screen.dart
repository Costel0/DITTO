import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/presentation/survival_background.dart';
import '../../../bunker/application/bunker_state_controller.dart';
import '../../../hub/domain/hub_scene_configuration.dart';
import '../../../survivors/domain/survivor.dart';
import '../../../survivors/presentation/widgets/survivor_profile_photo.dart';
import '../../domain/job_area.dart';
import '../../domain/job_task.dart';
import '../../domain/job_task_service.dart';
import '../job_labels.dart';

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
  String? _startingTaskId;

  @override
  void initState() {
    super.initState();
    widget.bunkerStateController.addListener(_onBunkerChanged);
    unawaited(widget.bunkerStateController.refresh());
  }

  @override
  void dispose() {
    widget.bunkerStateController.removeListener(_onBunkerChanged);
    super.dispose();
  }

  void _onBunkerChanged() {
    if (mounted) setState(() {});
  }

  String _taskTitle(BuildContext context, JobTaskDefinition task) {
    switch (task.id) {
      case 'clear_garden':
        return context.l10n.jobClearGardenTitle;
      default:
        return task.id;
    }
  }

  String _taskDescription(BuildContext context, JobTaskDefinition task) {
    switch (task.id) {
      case 'clear_garden':
        return context.l10n.jobClearGardenDescription;
      default:
        return '';
    }
  }

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

    final available = current.idleSurvivors
        .map(current.survivorById)
        .whereType<Survivor>()
        .where((survivor) => survivor.energy >= 0)
        .toList(growable: false);
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.jobNoIdleSurvivors)),
      );
      return;
    }

    final selected = await showDialog<Survivor>(
      context: context,
      barrierColor: const Color(0xB8000000),
      builder: (dialogContext) => _SurvivorTaskDialog(
        survivors: available,
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _startingTaskId = task.id);
    try {
      await widget.taskService.startTask(
        taskId: task.id,
        survivorId: selected.id,
      );
      await widget.bunkerStateController.refreshAfterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.jobTaskStarted}: '
            '${survivorDisplayName(context, selected)}',
          ),
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
    final tasks = jobTasksForArea(area);

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
                                    _JobAreaCover(area: area),
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
                                        startingTaskId: _startingTaskId,
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
  const _JobAreaCover({required this.area});

  final JobArea area;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      area.coverAssetPath,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Container(
        width: double.infinity,
        height: 240,
        color: const Color(0xFF242019),
        alignment: Alignment.center,
        child: Icon(
          jobAreaIcon(area),
          size: 56,
          color: const Color(0xFFAD9365),
        ),
      ),
    );
  }
}

class _JobAreaContent extends StatelessWidget {
  const _JobAreaContent({
    required this.area,
    required this.tasks,
    required this.startingTaskId,
    required this.taskTitle,
    required this.taskDescription,
    required this.onStartTask,
  });

  final JobArea area;
  final List<JobTaskDefinition> tasks;
  final String? startingTaskId;
  final String Function(JobTaskDefinition task) taskTitle;
  final String Function(JobTaskDefinition task) taskDescription;
  final ValueChanged<JobTaskDefinition> onStartTask;

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
        if (tasks.isEmpty)
          _EmptyTasks(message: context.l10n.jobNoAvailableTasks)
        else
          for (final task in tasks) ...[
            _TaskTile(
              title: taskTitle(task),
              description: taskDescription(task),
              isStarting: startingTaskId == task.id,
              onTap: startingTaskId == null
                  ? () => onStartTask(task)
                  : null,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _SurvivorTaskDialog extends StatelessWidget {
  const _SurvivorTaskDialog({required this.survivors});

  final List<Survivor> survivors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
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
                          border: Border.all(color: const Color(0xFF514634)),
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
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(14),
                    itemCount: survivors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _SurvivorChoice(
                      survivor: survivors[index],
                      onTap: () => Navigator.of(context).pop(survivors[index]),
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

class _SurvivorChoice extends StatelessWidget {
  const _SurvivorChoice({
    required this.survivor,
    required this.onTap,
  });

  final Survivor survivor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFF211F19),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF443D31)),
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
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC6AA74),
              ),
            ],
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
    required this.isStarting,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool isStarting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFF1B1A16),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFF4E4537)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: Color(0xFFC0A46F),
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
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.jobTaskStartButton,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFD4B77D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFD4B77D),
                    ),
                  ],
                ),
            ],
          ),
        ),
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
