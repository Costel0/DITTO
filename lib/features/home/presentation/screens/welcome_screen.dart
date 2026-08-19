import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/navigation/app_routes.dart';
import '../../../../core/firebase/firebase_functions_job_task_service.dart';
import '../../../../core/firebase/firestore_bunker_state_service.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/presentation/survival_background.dart';
import '../../../auth/application/session_controller.dart';
import '../../../bunker/application/bunker_state_controller.dart';
import '../../../bunker/domain/bunker_state.dart';
import '../../../hub/domain/hub_scene_configuration.dart';
import '../../../hub/presentation/widgets/hub_character_info.dart';
import '../../../hub/presentation/widgets/hub_debug_controls.dart';
import '../../../hub/presentation/widgets/hub_inventory.dart';
import '../../../hub/presentation/widgets/hub_jobs.dart';
import '../../../hub/presentation/widgets/hub_scrollable_scene.dart';
import '../../../jobs/domain/job_area.dart';
import '../../../jobs/presentation/screens/job_area_screen.dart';
import '../../../survivors/domain/survivor.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.sessionController,
  });

  final SessionController sessionController;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

enum _HubSection {
  character,
  inventory,
  jobs,
  expeditions,
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  _HubSection _selectedSection = _HubSection.character;
  int _selectedSurvivorIndex = 0;
  BunkerStateController? _bunkerStateController;
  final FirebaseFunctionsJobTaskService _jobTaskService =
      FirebaseFunctionsJobTaskService();

  SessionController get sessionController => widget.sessionController;

  List<Survivor> get _roster =>
      _bunkerStateController?.state?.survivors ?? sessionController.survivors;

  List<Survivor> get _idleHubSurvivors {
    final bunkerState = _bunkerStateController?.state;
    if (bunkerState == null) return const <Survivor>[];

    final idleIds = bunkerState.idleSurvivors.toSet();
    return bunkerState.survivors
        .where((survivor) => idleIds.contains(survivor.id))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    sessionController.addListener(_onSessionChanged);
    _initializeBunkerStateController();
  }

  void _initializeBunkerStateController() {
    final userId = sessionController.credentials?.userId;
    if (userId == null || userId.isEmpty) return;

    final controller = BunkerStateController(
      service: FirestoreBunkerStateService(userId: userId),
    );
    controller.addListener(_onBunkerStateChanged);
    _bunkerStateController = controller;
    controller.startPolling();
  }

  @override
  void dispose() {
    sessionController.removeListener(_onSessionChanged);
    final bunkerController = _bunkerStateController;
    if (bunkerController != null) {
      bunkerController.removeListener(_onBunkerStateChanged);
      bunkerController.dispose();
    }
    super.dispose();
  }

  void _clampSelectedSurvivorIndex() {
    final rosterLength = _roster.length;
    if (rosterLength == 0) {
      _selectedSurvivorIndex = 0;
    } else if (_selectedSurvivorIndex >= rosterLength) {
      _selectedSurvivorIndex = rosterLength - 1;
    }
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(_clampSelectedSurvivorIndex);
  }

  void _onBunkerStateChanged() {
    if (!mounted) return;
    setState(_clampSelectedSurvivorIndex);
  }

  Future<void> _logout(BuildContext context) async {
    await sessionController.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  Future<void> _resetProfileForTesting() async {
    final cleared = await sessionController.clearInitialProfileForTesting();
    if (!mounted) return;

    if (cleared) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.usernameSetup);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.resetProfileTestError)),
    );
  }

  Future<void> _refreshBunkerAfterDebugMutation() async {
    final controller = _bunkerStateController;
    if (controller == null) return;
    await controller.refreshAfterMutation();
  }

  void _selectSection(_HubSection section) {
    setState(() => _selectedSection = section);
    final controller = _bunkerStateController;
    if (section == _HubSection.jobs && controller != null) {
      unawaited(controller.refresh());
    }
  }

  void _openJobArea(JobArea area) {
    final controller = _bunkerStateController;
    if (controller == null) return;

    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => JobAreaScreen(
            area: area,
            bunkerStateController: controller,
            taskService: _jobTaskService,
          ),
        ),
      ),
    );
  }

  IconData _characterIcon(String duplicateId) {
    switch (duplicateId) {
      case '02':
        return Icons.face_rounded;
      case '03':
        return Icons.accessibility_new_rounded;
      case '04':
        return Icons.account_circle_rounded;
      case '01':
      default:
        return Icons.person_rounded;
    }
  }

  Map<HubCharacterSlot, HubSceneCharacter> get _hubCharacters {
    final idleSurvivors = _idleHubSurvivors;
    final variantSeed = _bunkerStateController?.state?.revision ?? 0;
    final result = <HubCharacterSlot, HubSceneCharacter>{};
    final visibleCount = idleSurvivors.length < hubRosterSlotOrder.length
        ? idleSurvivors.length
        : hubRosterSlotOrder.length;

    for (var index = 0; index < visibleCount; index++) {
      final survivor = idleSurvivors[index];
      result[hubRosterSlotOrder[index]] = HubSceneCharacter(
        assetPath: survivor.idleAssetPath,
        fallbackIcon: _characterIcon(survivor.duplicateId),
        variantSeed: variantSeed,
        variantKey: survivor.id.isNotEmpty ? survivor.id : survivor.duplicateId,
      );
    }

    return result;
  }

  Survivor? get _selectedSurvivor {
    final roster = _roster;
    if (roster.isEmpty) return null;
    if (_selectedSurvivorIndex >= roster.length) return roster.last;
    return roster[_selectedSurvivorIndex];
  }

  Map<String, int>? get _inventory {
    final controller = _bunkerStateController;
    if (controller == null) return const <String, int>{};
    return controller.state?.inventory;
  }

  void _openCharacterFromSlot(HubCharacterSlot slot) {
    final idleIndex = hubRosterSlotOrder.indexOf(slot);
    final idleSurvivors = _idleHubSurvivors;
    if (idleIndex < 0 || idleIndex >= idleSurvivors.length) return;

    final selectedId = idleSurvivors[idleIndex].id;
    final rosterIndex = _roster.indexWhere((survivor) => survivor.id == selectedId);
    if (rosterIndex < 0) return;

    setState(() {
      _selectedSurvivorIndex = rosterIndex;
      _selectedSection = _HubSection.character;
    });
  }

  void _changeSelectedSurvivor(int delta) {
    final target = _selectedSurvivorIndex + delta;
    if (target < 0 || target >= _roster.length) return;

    setState(() {
      _selectedSurvivorIndex = target;
      _selectedSection = _HubSection.character;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rosterLength = _roster.length;
    final bunkerController = _bunkerStateController;

    return Scaffold(
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
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Column(
                                children: [
                                  _HubTopBar(
                                    username: sessionController.username,
                                    onSettings: () {},
                                    onLogout: () => _logout(context),
                                  ),
                                  SizedBox(
                                    height: defaultHubSceneConfiguration
                                        .canvasSize.height,
                                    child: HubScrollableScene(
                                      characters: _hubCharacters,
                                      onCharacterTap: _openCharacterFromSlot,
                                    ),
                                  ),
                                  _HubSectionBar(
                                    selectedSection: _selectedSection,
                                    onSelected: _selectSection,
                                  ),
                                  Expanded(
                                    child: _HubSectionView(
                                      section: _selectedSection,
                                      survivor: _selectedSurvivor,
                                      inventory: _inventory,
                                      inventoryLoadError:
                                          bunkerController?.lastError,
                                      bunkerState: bunkerController?.state,
                                      bunkerIsRefreshing:
                                          bunkerController?.isRefreshing ?? false,
                                      bunkerLoadError:
                                          bunkerController?.lastError,
                                      onOpenJobArea: _openJobArea,
                                      onPreviousSurvivor:
                                          _selectedSurvivorIndex > 0
                                              ? () =>
                                                  _changeSelectedSurvivor(-1)
                                              : null,
                                      onNextSurvivor:
                                          _selectedSurvivorIndex + 1 <
                                                  rosterLength
                                              ? () => _changeSelectedSurvivor(1)
                                              : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: HubDebugControls(
                                sessionController: sessionController,
                                onResetProfile: _resetProfileForTesting,
                                onItemAdded: _refreshBunkerAfterDebugMutation,
                                resetTooltip: l10n.resetProfileTestTooltip,
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

class _HubTopBar extends StatelessWidget {
  const _HubTopBar({
    required this.username,
    required this.onSettings,
    required this.onLogout,
  });

  final String username;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF554A3A)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;

          return Row(
            children: [
              Expanded(
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF8F8677),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.settingsTooltip,
                onPressed: onSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
              if (compact)
                IconButton(
                  tooltip: l10n.logout,
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                )
              else
                TextButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.logout),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HubSectionBar extends StatelessWidget {
  const _HubSectionBar({
    required this.selectedSection,
    required this.onSelected,
  });

  final _HubSection selectedSection;
  final ValueChanged<_HubSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF171713),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: const Color(0xFF574B3A).withValues(alpha: 0.9),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HubSectionButton(
              icon: Icons.person_outline_rounded,
              label: l10n.hubTabCharacter,
              selected: selectedSection == _HubSection.character,
              onTap: () => onSelected(_HubSection.character),
            ),
          ),
          Expanded(
            child: _HubSectionButton(
              icon: Icons.backpack_outlined,
              label: l10n.hubTabInventory,
              selected: selectedSection == _HubSection.inventory,
              onTap: () => onSelected(_HubSection.inventory),
            ),
          ),
          Expanded(
            child: _HubSectionButton(
              icon: Icons.work_outline_rounded,
              label: l10n.hubTabJobs,
              selected: selectedSection == _HubSection.jobs,
              onTap: () => onSelected(_HubSection.jobs),
            ),
          ),
          Expanded(
            child: _HubSectionButton(
              icon: Icons.explore_outlined,
              label: l10n.hubTabExpeditions,
              selected: selectedSection == _HubSection.expeditions,
              onTap: () => onSelected(_HubSection.expeditions),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubSectionButton extends StatelessWidget {
  const _HubSectionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2D281F)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 135;
              final iconColor = selected
                  ? const Color(0xFFD7BD89)
                  : const Color(0xFF8C8477);
              final textColor = selected
                  ? const Color(0xFFE3D4B7)
                  : const Color(0xFF9D9485);

              if (compact) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: iconColor),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textColor,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
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

class _HubSectionView extends StatelessWidget {
  const _HubSectionView({
    required this.section,
    required this.survivor,
    required this.inventory,
    required this.inventoryLoadError,
    required this.bunkerState,
    required this.bunkerIsRefreshing,
    required this.bunkerLoadError,
    required this.onOpenJobArea,
    required this.onPreviousSurvivor,
    required this.onNextSurvivor,
  });

  final _HubSection section;
  final Survivor? survivor;
  final Map<String, int>? inventory;
  final Object? inventoryLoadError;
  final BunkerState? bunkerState;
  final bool bunkerIsRefreshing;
  final Object? bunkerLoadError;
  final ValueChanged<JobArea> onOpenJobArea;
  final VoidCallback? onPreviousSurvivor;
  final VoidCallback? onNextSurvivor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    switch (section) {
      case _HubSection.character:
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: HubCharacterInfo(
            key: ValueKey(survivor?.duplicateId ?? 'no-character'),
            survivor: survivor,
            onPrevious: onPreviousSurvivor,
            onNext: onNextSurvivor,
          ),
        );
      case _HubSection.inventory:
        return HubInventory(
          key: const ValueKey(_HubSection.inventory),
          inventory: inventory,
          loadError: inventoryLoadError,
        );
      case _HubSection.jobs:
        return HubJobs(
          key: const ValueKey(_HubSection.jobs),
          bunkerState: bunkerState,
          isRefreshing: bunkerIsRefreshing,
          loadError: bunkerLoadError,
          onOpenArea: onOpenJobArea,
        );
      case _HubSection.expeditions:
        return _HubSectionContent(
          key: const ValueKey(_HubSection.expeditions),
          icon: Icons.explore_outlined,
          title: l10n.hubExpeditionsTitle,
          description: l10n.hubExpeditionsDescription,
        );
    }
  }
}

class _HubSectionContent extends StatelessWidget {
  const _HubSectionContent({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: const Color(0xE611110E),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF262219),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFF554936)),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFC6AA74),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFE6D8BD),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFA49B8B),
                          height: 1.5,
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
    );
  }
}
