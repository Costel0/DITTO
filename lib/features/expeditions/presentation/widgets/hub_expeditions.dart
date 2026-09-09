import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../bunker/domain/bunker_state.dart';
import '../../../survivors/domain/survivor.dart';
import '../../../survivors/presentation/duplicate_presentation.dart';
import '../../../survivors/presentation/widgets/survivor_profile_photo.dart';
import '../../domain/expedition_service.dart';
import 'expedition_launcher_dialog.dart';

class HubExpeditions extends StatefulWidget {
  const HubExpeditions({
    super.key,
    required this.bunkerState,
    required this.isRefreshing,
    required this.loadError,
    required this.expeditionService,
    required this.onRefreshAfterMutation,
    required this.onResolveCompletedOccupations,
  });

  final BunkerState? bunkerState;
  final bool isRefreshing;
  final Object? loadError;
  final ExpeditionService expeditionService;
  final Future<void> Function() onRefreshAfterMutation;
  final Future<void> Function() onResolveCompletedOccupations;

  @override
  State<HubExpeditions> createState() => _HubExpeditionsState();
}

class _HubExpeditionsState extends State<HubExpeditions> {
  bool _isOpeningLauncher = false;

  List<Survivor> get _availableSurvivors {
    final bunker = widget.bunkerState;
    if (bunker == null) return const <Survivor>[];
    return bunker.idleSurvivors
        .map(bunker.survivorById)
        .whereType<Survivor>()
        .where((survivor) => survivor.energy >= 0)
        .toList(growable: false);
  }

  Future<void> _openLauncher() async {
    if (_isOpeningLauncher || widget.bunkerState == null) return;

    setState(() => _isOpeningLauncher = true);
    try {
      final info = await widget.expeditionService.fetchLauncherInfo();
      if (!mounted) return;

      final selection = await ExpeditionLauncherDialog.show(
        context,
        info: info,
        survivors: _availableSurvivors,
      );
      if (!mounted || selection == null) return;

      await widget.expeditionService.startExpedition(
        survivorIds: selection.survivorIds,
        coordinates: selection.coordinates,
        actionIds: selection.actionIds,
      );
      await widget.onRefreshAfterMutation();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.expeditionStarted)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.expeditionStartError)),
      );
    } finally {
      if (mounted) setState(() => _isOpeningLauncher = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final bunker = widget.bunkerState;
    final activeExpeditions = _groupActiveExpeditions(
      bunker?.busySurvivors ?? const <BusySurvivor>[],
    );

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
                      l10n.hubExpeditionsTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFE6D8BD),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.isRefreshing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.hubExpeditionsDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFA49B8B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 74,
                child: FilledButton.icon(
                  onPressed:
                      bunker == null || _isOpeningLauncher ? null : _openLauncher,
                  icon: _isOpeningLauncher
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.explore_rounded, size: 30),
                  label: Text(
                    l10n.expeditionLaunchButton,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                l10n.expeditionActiveTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFE3D4B7),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (bunker == null && widget.loadError != null)
                Text(
                  l10n.hubJobsLoadError,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB08C75),
                  ),
                )
              else if (activeExpeditions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1A16),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0xFF403A30)),
                  ),
                  child: Text(
                    l10n.expeditionNoActive,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF8F8677),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: activeExpeditions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ActiveExpeditionCard(
                      entries: activeExpeditions[index],
                      bunkerState: bunker!,
                      onFinished: widget.onResolveCompletedOccupations,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

List<List<BusySurvivor>> _groupActiveExpeditions(
  List<BusySurvivor> busySurvivors,
) {
  final grouped = <String, List<BusySurvivor>>{};
  for (final busy in busySurvivors) {
    if (busy.activity != 'expedition') continue;
    final key = busy.executionId ??
        busy.survivorId + ':' + busy.startedAt.toIso8601String();
    grouped.putIfAbsent(key, () => <BusySurvivor>[]).add(busy);
  }
  final result = grouped.values.toList(growable: false);
  result.sort((a, b) => a.first.endsAt.compareTo(b.first.endsAt));
  return result;
}

class _ActiveExpeditionCard extends StatelessWidget {
  const _ActiveExpeditionCard({
    required this.entries,
    required this.bunkerState,
    required this.onFinished,
  });

  final List<BusySurvivor> entries;
  final BunkerState bunkerState;
  final Future<void> Function() onFinished;

  List<String> get _actionIds {
    final taskId = entries.first.taskId;
    if (taskId == null || !taskId.startsWith('expedition:')) {
      return const <String>[];
    }
    return taskId
        .substring('expedition:'.length)
        .split('+')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  String _actionLabel(BuildContext context, String actionId) {
    switch (actionId) {
      case 'scout_surroundings':
        return context.l10n.expeditionScoutSurroundingsTitle;
      default:
        return actionId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = entries.first;
    final names = entries.map((entry) {
      final survivor = bunkerState.survivorById(entry.survivorId);
      return survivor == null
          ? entry.survivorId
          : duplicateDisplayName(context, survivor.duplicateId);
    }).join(', ');
    final actions = _actionIds
        .map((actionId) => _actionLabel(context, actionId))
        .join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A16),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF4E4537)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                actions.isEmpty
                    ? context.l10n.expeditionActiveFallbackTitle
                    : actions,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFFE4D5B8),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.expeditionCoordinatesValue(first.location),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9F9687),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                names,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF8F8677),
                ),
              ),
            ],
          );
          final portraits = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in entries)
                  _ExpeditionPortrait(
                    survivor: bunkerState.survivorById(entry.survivorId),
                  ),
              ],
            ),
          );
          final countdown = _ExpeditionCountdown(
            endsAt: first.endsAt,
            onFinished: onFinished,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    portraits,
                    const SizedBox(width: 10),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: countdown),
              ],
            );
          }

          return Row(
            children: [
              portraits,
              const SizedBox(width: 12),
              Expanded(child: details),
              const SizedBox(width: 18),
              countdown,
            ],
          );
        },
      ),
    );
  }
}

class _ExpeditionPortrait extends StatelessWidget {
  const _ExpeditionPortrait({required this.survivor});

  final Survivor? survivor;

  @override
  Widget build(BuildContext context) {
    final current = survivor;
    if (current != null) {
      return SurvivorProfilePhoto(survivor: current, size: 38);
    }
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF211F19),
        border: Border.all(color: const Color(0xFF514634)),
      ),
      child: const Icon(
        Icons.person_outline_rounded,
        color: Color(0xFF8F8677),
      ),
    );
  }
}

class _ExpeditionCountdown extends StatefulWidget {
  const _ExpeditionCountdown({
    required this.endsAt,
    required this.onFinished,
  });

  final DateTime endsAt;
  final Future<void> Function() onFinished;

  @override
  State<_ExpeditionCountdown> createState() => _ExpeditionCountdownState();
}

class _ExpeditionCountdownState extends State<_ExpeditionCountdown> {
  Timer? _timer;
  Timer? _completionTimer;
  Duration _remaining = Duration.zero;
  bool _completionScheduled = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _ExpeditionCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _completionTimer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _completionTimer?.cancel();
    _completionScheduled = false;
    _update();
    if (_remaining == Duration.zero) {
      _scheduleCompletion();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _update();
      if (_remaining == Duration.zero) {
        _timer?.cancel();
        _scheduleCompletion();
      }
    });
  }

  void _update() {
    final difference = widget.endsAt.difference(DateTime.now());
    final next = difference.isNegative ? Duration.zero : difference;
    if (!mounted) {
      _remaining = next;
      return;
    }
    setState(() => _remaining = next);
  }

  void _scheduleCompletion() {
    if (_completionScheduled) return;
    _completionScheduled = true;
    _completionTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      unawaited(widget.onFinished());
    });
  }

  String _formatted() {
    final seconds = _remaining == Duration.zero
        ? 0
        : (_remaining.inMilliseconds / 1000).ceil();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return hours.toString().padLeft(2, '0') +
        ':' +
        minutes.toString().padLeft(2, '0') +
        ':' +
        remainingSeconds.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted(),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFFD4B77D),
            fontWeight: FontWeight.w800,
            fontFeatures: const <FontFeature>[
              FontFeature.tabularFigures(),
            ],
          ),
    );
  }
}
