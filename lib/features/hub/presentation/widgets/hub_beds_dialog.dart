import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../bunker/application/bunker_state_controller.dart';
import '../../../bunker/domain/bunker_state.dart';
import '../../../survivors/domain/survivor.dart';
import '../../../survivors/presentation/duplicate_presentation.dart';
import '../../../survivors/presentation/widgets/survivor_profile_photo.dart';

class HubBedsDialog extends StatelessWidget {
  const HubBedsDialog({
    super.key,
    required this.controller,
  });

  final BunkerStateController controller;

  static Future<void> show(
    BuildContext context, {
    required BunkerStateController controller,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0xB8000000),
      builder: (_) => HubBedsDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
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
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF262219),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: const Color(0xFF514634),
                          ),
                        ),
                        child: const Icon(
                          Icons.bedtime_outlined,
                          color: Color(0xFFC7A970),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.hubBedsTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFFE6D8BD),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.l10n.hubBedsDescription,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF9B9284),
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
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final state = controller.state;
                      final sleepers = state == null
                          ? const <BusySurvivor>[]
                          : state.busySurvivors
                              .where((busy) => busy.activity == 'sleeping')
                              .toList(growable: false)
                        ..sort((a, b) => a.endsAt.compareTo(b.endsAt));

                      if (state == null && controller.isRefreshing) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      if (sleepers.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.hotel_outlined,
                                color: Color(0xFF8F8677),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  context.l10n.hubBedsEmpty,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF9F9687),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(14),
                        itemCount: sleepers.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sleeping = sleepers[index];
                          final survivor =
                              state?.survivorById(sleeping.survivorId);
                          return _SleepingSurvivorTile(
                            sleeping: sleeping,
                            survivor: survivor,
                            onFinished:
                                controller.resolveCompletedOccupations,
                          );
                        },
                      );
                    },
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

class _SleepingSurvivorTile extends StatelessWidget {
  const _SleepingSurvivorTile({
    required this.sleeping,
    required this.survivor,
    required this.onFinished,
  });

  final BusySurvivor sleeping;
  final Survivor? survivor;
  final Future<void> Function() onFinished;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSurvivor = survivor;
    final name = currentSurvivor == null
        ? sleeping.survivorId
        : duplicateDisplayName(context, currentSurvivor.duplicateId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF211F19),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF443D31)),
      ),
      child: Row(
        children: [
          if (currentSurvivor != null)
            SurvivorProfilePhoto(
              survivor: currentSurvivor,
              size: 52,
            )
          else
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF29261E),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF8F8677),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFFE4D5B8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bedtime_outlined,
                      size: 15,
                      color: Color(0xFF9B9284),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      context.l10n.jobSleepingTitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF9B9284),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SleepingCountdown(
            endsAt: sleeping.endsAt,
            onFinished: onFinished,
          ),
        ],
      ),
    );
  }
}

class _SleepingCountdown extends StatefulWidget {
  const _SleepingCountdown({
    required this.endsAt,
    required this.onFinished,
  });

  final DateTime endsAt;
  final Future<void> Function() onFinished;

  @override
  State<_SleepingCountdown> createState() => _SleepingCountdownState();
}

class _SleepingCountdownState extends State<_SleepingCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _completionRequested = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _SleepingCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _completionRequested = false;
    _updateRemaining();
    if (_remaining == Duration.zero) {
      _requestCompletion();
      return;
    }

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _updateRemaining();
        if (_remaining == Duration.zero) {
          _timer?.cancel();
          _requestCompletion();
        }
      },
    );
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

  void _requestCompletion() {
    if (_completionRequested) return;
    _completionRequested = true;
    unawaited(widget.onFinished());
  }

  String _formattedRemaining() {
    final totalSeconds = _remaining == Duration.zero
        ? 0
        : (_remaining.inMilliseconds / 1000).ceil();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final hoursText = hours.toString().padLeft(2, '0');
    final minutesText = minutes.toString().padLeft(2, '0');
    final secondsText = seconds.toString().padLeft(2, '0');
    return '$hoursText:$minutesText:$secondsText';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formattedRemaining(),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFFD4B77D),
            fontWeight: FontWeight.w800,
            fontFeatures: const <FontFeature>[
              FontFeature.tabularFigures(),
            ],
          ),
    );
  }
}
