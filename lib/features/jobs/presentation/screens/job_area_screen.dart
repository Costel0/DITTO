import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../bunker/application/bunker_state_controller.dart';
import '../../../survivors/domain/survivor.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.hubJobsLoadError)),
        );
      }
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

    final selected = await showModalBottomSheet<Survivor>(
      context: context,
      backgroundColor: const Color(0xFF1B1A16),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.jobChooseSurvivorTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFE6D8BD),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              for (final survivor in available)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF2A261E),
                    child: Text(
                      survivorDisplayName(context, survivor).characters.first,
                    ),
                  ),
                  title: Text(
                    survivorDisplayName(context, survivor),
                    style: const TextStyle(color: Color(0xFFE1D4BB)),
                  ),
                  subtitle: Text(
                    '${context.l10n.jobEnergyLabel}: ${survivor.energy}',
                    style: const TextStyle(color: Color(0xFF9E9586)),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(survivor),
                ),
            ],
          ),
        ),
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF11110E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171713),
        foregroundColor: const Color(0xFFE6D8BD),
        title: Text(jobAreaTitle(context, area)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        area.coverAssetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF242019),
                          alignment: Alignment.center,
                          child: Icon(
                            jobAreaIcon(area),
                            size: 56,
                            color: const Color(0xFFAD9365),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
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
                        title: _taskTitle(context, task),
                        description: _taskDescription(context, task),
                        isStarting: _startingTaskId == task.id,
                        onTap: _startingTaskId == null
                            ? () => _startTask(task)
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
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
