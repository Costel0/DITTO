import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../bunker/domain/bunker_state.dart';
import '../../../jobs/domain/job_area.dart';
import '../../../jobs/presentation/job_labels.dart';

class HubJobs extends StatelessWidget {
  const HubJobs({
    super.key,
    required this.bunkerState,
    required this.isRefreshing,
    required this.loadError,
    required this.onOpenArea,
  });

  final BunkerState? bunkerState;
  final bool isRefreshing;
  final Object? loadError;
  final ValueChanged<JobArea> onOpenArea;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    const areas = <JobArea>[
      JobArea.workshop,
      JobArea.kitchen,
      JobArea.garden,
    ];

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xE611110E),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.hubJobsTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFE6D8BD),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isRefreshing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (bunkerState == null && loadError != null) ...[
                Text(
                  l10n.hubJobsLoadError,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB08C75),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: ListView.separated(
                  itemCount: areas.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final area = areas[index];
                    return HubJobCard(
                      imageAsset: area.cardAssetPath,
                      fallbackIcon: jobAreaIcon(area),
                      title: jobAreaTitle(context, area),
                      description: jobAreaDescription(context, area),
                      specificInfo: _ActiveJobInfo(
                        area: area,
                        bunkerState: bunkerState,
                      ),
                      onTap: () => onOpenArea(area),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HubJobCard extends StatelessWidget {
  const HubJobCard({
    super.key,
    required this.imageAsset,
    required this.fallbackIcon,
    required this.title,
    required this.description,
    required this.specificInfo,
    required this.onTap,
  });

  final String imageAsset;
  final IconData fallbackIcon;
  final String title;
  final String description;
  final Widget specificInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFF1B1A16),
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 164),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFF4E4537)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageWidth = constraints.maxWidth < 560 ? 112.0 : 176.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: imageWidth,
                    height: 164,
                    child: _JobImage(
                      assetPath: imageAsset,
                      fallbackIcon: fallbackIcon,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFFE4D5B8),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF9B8762),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFA79E8E),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          specificInfo,
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _JobImage extends StatelessWidget {
  const _JobImage({
    required this.assetPath,
    required this.fallbackIcon,
  });

  final String assetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF242019)),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            fallbackIcon,
            size: 42,
            color: const Color(0xFFAD9365),
          ),
        ),
      ),
    );
  }
}

class _ActiveJobInfo extends StatelessWidget {
  const _ActiveJobInfo({
    required this.area,
    required this.bunkerState,
  });

  final JobArea area;
  final BunkerState? bunkerState;

  String _groupKey(BusySurvivor busy) {
    final executionId = busy.executionId;
    if (executionId != null) return 'execution:$executionId';
    return 'single:${busy.survivorId}:${busy.activity}:'
        '${busy.startedAt.millisecondsSinceEpoch}:'
        '${busy.endsAt.millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final bunker = bunkerState;
    if (bunker == null) {
      return _JobInfoFrame(
        child: Text(
          context.l10n.hubJobsLoading,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8F8677),
              ),
        ),
      );
    }

    final active = bunker.busySurvivors
        .where((busy) => busy.location == area.id)
        .toList(growable: false);

    if (active.isEmpty) {
      return _JobInfoFrame(
        child: Row(
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              size: 17,
              color: Color(0xFFC0A46F),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.jobNoActiveTasks,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8F8677),
                    ),
              ),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<BusySurvivor>>{};
    for (final busy in active) {
      grouped.putIfAbsent(_groupKey(busy), () => <BusySurvivor>[]).add(busy);
    }
    final executions = grouped.values.toList(growable: false)
      ..sort((a, b) => a.first.endsAt.compareTo(b.first.endsAt));

    return _JobInfoFrame(
      child: Column(
        children: [
          for (var index = 0; index < executions.length; index++) ...[
            _BusyExecutionRow(
              busySurvivors: executions[index],
              bunkerState: bunker,
            ),
            if (index + 1 < executions.length)
              const Divider(height: 14, color: Color(0xFF443D31)),
          ],
        ],
      ),
    );
  }
}

class _JobInfoFrame extends StatelessWidget {
  const _JobInfoFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF25221B),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF443D31)),
      ),
      child: child,
    );
  }
}

class _BusyExecutionRow extends StatelessWidget {
  const _BusyExecutionRow({
    required this.busySurvivors,
    required this.bunkerState,
  });

  final List<BusySurvivor> busySurvivors;
  final BunkerState bunkerState;

  String _formatDateTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatShortDate(local);
    final time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: true,
    );
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = busySurvivors.first;
    final survivorNames = busySurvivors.map((busy) {
      final survivor = bunkerState.survivorById(busy.survivorId);
      return survivor == null
          ? busy.survivorId
          : survivorDisplayName(context, survivor);
    }).join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          busySurvivors.length > 1
              ? Icons.groups_2_outlined
              : Icons.person_outline_rounded,
          size: 18,
          color: const Color(0xFFC0A46F),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$survivorNames · ${jobActivityLabel(context, first.activity)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFBDB3A1),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${context.l10n.jobStartsLabel}: '
                '${_formatDateTime(context, first.startedAt)}  ·  '
                '${context.l10n.jobEndsLabel}: '
                '${_formatDateTime(context, first.endsAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF8F8677),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        _JobCountdown(endsAt: first.endsAt),
      ],
    );
  }
}

class _JobCountdown extends StatefulWidget {
  const _JobCountdown({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_JobCountdown> createState() => _JobCountdownState();
}

class _JobCountdownState extends State<_JobCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _JobCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _updateRemaining();
    if (_remaining == Duration.zero) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
      if (_remaining == Duration.zero) {
        _timer?.cancel();
      }
    });
  }

  void _updateRemaining() {
    final difference = widget.endsAt.difference(DateTime.now());
    final next = difference.isNegative ? Duration.zero : difference;
    if (!mounted) {
      _remaining = next;
      return;
    }
    setState(() => _remaining = next);
  }

  String _formattedRemaining() {
    final totalSeconds = _remaining == Duration.zero
        ? 0
        : (_remaining.inMilliseconds / 1000).ceil();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          _formattedRemaining(),
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFD4B77D),
                fontWeight: FontWeight.w800,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
        ),
      ),
    );
  }
}
