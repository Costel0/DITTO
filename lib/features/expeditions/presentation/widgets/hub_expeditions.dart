import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../bunker/domain/bunker_state.dart';
import '../../../survivors/domain/survivor.dart';
import '../../../survivors/presentation/duplicate_presentation.dart';
import '../../domain/expedition_review.dart';
import '../../domain/expedition_service.dart';
import 'expedition_launcher_dialog.dart';
import 'expedition_result_dialog.dart';

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
  bool _isLoadingReviews = false;
  String? _reviewingId;
  int? _lastRevision;
  List<ExpeditionReviewSummary> _pendingReviews =
      const <ExpeditionReviewSummary>[];

  @override
  void initState() {
    super.initState();
    _lastRevision = widget.bunkerState?.revision;
    unawaited(_loadPendingReviews());
  }

  @override
  void didUpdateWidget(covariant HubExpeditions oldWidget) {
    super.didUpdateWidget(oldWidget);
    final revision = widget.bunkerState?.revision;
    if (revision != null && revision != _lastRevision) {
      _lastRevision = revision;
      unawaited(_loadPendingReviews());
    }
  }

  String _text(BuildContext context, String es, String en) {
    return Localizations.localeOf(context).languageCode == 'es' ? es : en;
  }

  List<Survivor> get _availableSurvivors {
    final bunker = widget.bunkerState;
    if (bunker == null) return const <Survivor>[];
    return bunker.idleSurvivors
        .map(bunker.survivorById)
        .whereType<Survivor>()
        .where((survivor) => survivor.energy >= 0)
        .toList(growable: false);
  }

  Future<void> _loadPendingReviews() async {
    if (_isLoadingReviews) return;
    if (mounted) setState(() => _isLoadingReviews = true);
    try {
      final reviews = await widget.expeditionService.fetchPendingReviews();
      if (!mounted) return;
      setState(() => _pendingReviews = reviews);
    } catch (_) {
      // Keep the latest successfully loaded list. The bunker poll/revision will
      // retry naturally without blocking active expedition rendering.
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
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

  Future<void> _reviewResult(ExpeditionReviewSummary summary) async {
    if (_reviewingId != null) return;
    setState(() => _reviewingId = summary.id);
    try {
      final reviewed =
          await widget.expeditionService.reviewExpeditionResult(summary.id);
      if (!mounted) return;

      setState(() {
        _pendingReviews = _pendingReviews
            .where((review) => review.id != summary.id)
            .toList(growable: false);
      });
      unawaited(widget.onRefreshAfterMutation());

      await ExpeditionResultDialog.show(
        context,
        review: reviewed,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              context,
              'No se ha podido abrir el informe de expedición.',
              'The expedition report could not be opened.',
            ),
          ),
        ),
      );
      unawaited(_loadPendingReviews());
    } finally {
      if (mounted) setState(() => _reviewingId = null);
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
    final hasEntries = activeExpeditions.isNotEmpty || _pendingReviews.isNotEmpty;

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
                  if (widget.isRefreshing || _isLoadingReviews)
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
                _text(context, 'Expediciones', 'Expeditions'),
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
              else if (!hasEntries)
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
                  child: ListView(
                    children: [
                      for (final review in _pendingReviews) ...[
                        _ResolvedExpeditionCard(
                          review: review,
                          isOpening: _reviewingId == review.id,
                          onTap: () => _reviewResult(review),
                        ),
                        const SizedBox(height: 10),
                      ],
                      for (final entries in activeExpeditions) ...[
                        _ActiveExpeditionCard(
                          entries: entries,
                          bunkerState: bunker!,
                          onFinished: widget.onResolveCompletedOccupations,
                        ),
                        const SizedBox(height: 10),
                      ],
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

List<List<BusySurvivor>> _groupActiveExpeditions(
  List<BusySurvivor> busySurvivors,
) {
  final grouped = <String, List<BusySurvivor>>{};
  for (final busy in busySurvivors) {
    if (busy.activity != 'expedition') continue;
    final key = busy.executionId ??
        '${busy.survivorId}:${busy.startedAt.toIso8601String()}';
    grouped.putIfAbsent(key, () => <BusySurvivor>[]).add(busy);
  }
  final result = grouped.values.toList(growable: false);
  result.sort((a, b) => a.first.endsAt.compareTo(b.first.endsAt));
  return result;
}

class _ResolvedExpeditionCard extends StatelessWidget {
  const _ResolvedExpeditionCard({
    required this.review,
    required this.isOpening,
    required this.onTap,
  });

  final ExpeditionReviewSummary review;
  final bool isOpening;
  final VoidCallback onTap;

  String _text(BuildContext context, String es, String en) {
    return Localizations.localeOf(context).languageCode == 'es' ? es : en;
  }

  @override
  Widget build(BuildContext context) {
    if (review.expeditionType == 'scavenge') {
      return Material(
        color: const Color(0xFF1B1A15),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isOpening ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF8A7143)),
            ),
            child: Row(
              children: [
                const _ScavengeVisual(size: 72, resolved: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCAVENGE · ${_text(context, 'RESUELTA', 'RESOLVED')}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: const Color(0xFFD5BA78),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _text(
                          context,
                          'Informe pendiente de revisar',
                          'Report waiting to be reviewed',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: const Color(0xFFE4D5B8),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _text(
                          context,
                          'Coordenadas: ${review.coordinates.displayValue}',
                          'Coordinates: ${review.coordinates.displayValue}',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF9D9382),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isOpening)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    color: Color(0xFFD4B77D),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return ListTile(
      onTap: isOpening ? null : onTap,
      tileColor: const Color(0xFF1B1A16),
      leading: const Icon(Icons.assignment_turned_in_outlined),
      title: Text(_text(context, 'Expedición resuelta', 'Resolved expedition')),
      subtitle: Text(review.coordinates.displayValue),
    );
  }
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

  String get _typeId {
    final explicitType = entries.first.expeditionType;
    if (explicitType != null && explicitType.isNotEmpty) return explicitType;
    final taskId = entries.first.taskId ?? '';
    if (taskId.contains('scout_surroundings') || taskId.contains('scavenge')) {
      return 'scavenge';
    }
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_typeId == 'scavenge') {
      return _ScavengeActiveCard(
        entries: entries,
        bunkerState: bunkerState,
        onFinished: onFinished,
      );
    }
    return _GenericActiveCard(entries: entries, onFinished: onFinished);
  }
}

class _ScavengeActiveCard extends StatelessWidget {
  const _ScavengeActiveCard({
    required this.entries,
    required this.bunkerState,
    required this.onFinished,
  });

  final List<BusySurvivor> entries;
  final BunkerState bunkerState;
  final Future<void> Function() onFinished;

  @override
  Widget build(BuildContext context) {
    final first = entries.first;
    final names = entries.map((entry) {
      final survivor = bunkerState.survivorById(entry.survivorId);
      return survivor == null
          ? entry.survivorId
          : duplicateDisplayName(context, survivor.duplicateId);
    }).join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF191914),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF66583C)),
      ),
      child: Row(
        children: [
          const _ScavengeVisual(size: 76),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCAVENGE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFD3B878),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.l10n.expeditionScavengeInProgressTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFE4D5B8),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.expeditionCoordinatesValue(first.location),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9F9687),
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  names,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8F8677),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ExpeditionCountdown(
            endsAt: first.endsAt,
            onFinished: onFinished,
          ),
        ],
      ),
    );
  }
}

class _GenericActiveCard extends StatelessWidget {
  const _GenericActiveCard({
    required this.entries,
    required this.onFinished,
  });

  final List<BusySurvivor> entries;
  final Future<void> Function() onFinished;

  @override
  Widget build(BuildContext context) {
    final first = entries.first;
    return ListTile(
      tileColor: const Color(0xFF1B1A16),
      leading: const Icon(Icons.explore_outlined),
      title: Text(context.l10n.expeditionActiveFallbackTitle),
      subtitle: Text(first.location),
      trailing: _ExpeditionCountdown(
        endsAt: first.endsAt,
        onFinished: onFinished,
      ),
    );
  }
}

class _ScavengeVisual extends StatefulWidget {
  const _ScavengeVisual({
    required this.size,
    this.resolved = false,
  });

  final double size;
  final bool resolved;

  @override
  State<_ScavengeVisual> createState() => _ScavengeVisualState();
}

class _ScavengeVisualState extends State<_ScavengeVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.resolved) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ScavengeVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resolved == widget.resolved) return;
    if (widget.resolved) {
      _controller.stop();
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.resolved) {
      return SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF242219),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF5C513D)),
          ),
          child: const Center(
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 36,
              color: Color(0xFFD0B36F),
            ),
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: widget.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF242219),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF5C513D)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final sweepLeft = 7 + (widget.size - 16) * _controller.value;
              return Stack(
                children: [
                  const Positioned(
                    left: 9,
                    bottom: 8,
                    child: Icon(
                      Icons.construction_rounded,
                      size: 22,
                      color: Color(0xFF746A58),
                    ),
                  ),
                  const Positioned(
                    right: 8,
                    top: 9,
                    child: Icon(
                      Icons.recycling_rounded,
                      size: 23,
                      color: Color(0xFF8B7957),
                    ),
                  ),
                  Positioned(
                    left: sweepLeft,
                    top: 6,
                    bottom: 6,
                    child: Container(
                      width: 2,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD0B36F),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x88D0B36F),
                            blurRadius: 7,
                          ),
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
  Duration _remaining = Duration.zero;
  bool _completionRequested = false;

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
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _completionRequested = false;
    _update();
    if (_remaining == Duration.zero) {
      _requestCompletion();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _update();
      if (_remaining == Duration.zero) {
        _timer?.cancel();
        _requestCompletion();
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

  void _requestCompletion() {
    if (_completionRequested) return;
    _completionRequested = true;
    unawaited(widget.onFinished());
  }

  String _formatted() {
    final seconds = _remaining == Duration.zero
        ? 0
        : (_remaining.inMilliseconds / 1000).ceil();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    final hoursText = hours.toString().padLeft(2, '0');
    final minutesText = minutes.toString().padLeft(2, '0');
    final secondsText = remainingSeconds.toString().padLeft(2, '0');
    return '$hoursText:$minutesText:$secondsText';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted(),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFFD4B77D),
            fontWeight: FontWeight.w800,
          ),
    );
  }
}
