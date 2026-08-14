import 'package:flutter/material.dart';

import '../../../../app/navigation/app_routes.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/presentation/survival_background.dart';
import '../../../auth/application/session_controller.dart';
import '../../../hub/domain/hub_scene_configuration.dart';
import '../../../hub/presentation/widgets/hub_scrollable_scene.dart';

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
  shelter,
  inventory,
  expeditions,
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isResettingProfile = false;
  _HubSection _selectedSection = _HubSection.shelter;

  SessionController get sessionController => widget.sessionController;

  Future<void> _logout(BuildContext context) async {
    await sessionController.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  Future<void> _resetProfileForTesting() async {
    if (_isResettingProfile) return;

    setState(() => _isResettingProfile = true);
    final cleared = await sessionController.clearInitialProfileForTesting();
    if (!mounted) return;

    if (cleared) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.usernameSetup);
      return;
    }

    setState(() => _isResettingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.resetProfileTestError)),
    );
  }

  IconData _characterIcon(String? characterId) {
    switch (characterId) {
      case 'survivor_02':
        return Icons.face_rounded;
      case 'survivor_03':
        return Icons.accessibility_new_rounded;
      case 'survivor_04':
        return Icons.account_circle_rounded;
      case 'survivor_01':
      default:
        return Icons.person_rounded;
    }
  }

  String get _characterAssetPath {
    final characterId = sessionController.characterId ?? 'survivor_01';
    return 'assets/characters/$characterId.png';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
                                      characters: <
                                          HubCharacterSlot,
                                          HubSceneCharacter
                                        >{
                                          HubCharacterSlot.primary:
                                              HubSceneCharacter(
                                                assetPath: _characterAssetPath,
                                                fallbackIcon: _characterIcon(
                                                  sessionController.characterId,
                                                ),
                                              ),
                                        },
                                    ),
                                  ),
                                  _HubSectionBar(
                                    selectedSection: _selectedSection,
                                    onSelected: (section) {
                                      setState(
                                        () => _selectedSection = section,
                                      );
                                    },
                                  ),
                                  Expanded(
                                    child: _HubSectionView(
                                      section: _selectedSection,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: IconButton(
                                tooltip: l10n.resetProfileTestTooltip,
                                visualDensity: VisualDensity.compact,
                                onPressed: _isResettingProfile
                                    ? null
                                    : _resetProfileForTesting,
                                icon: _isResettingProfile
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.restart_alt_rounded,
                                        size: 20,
                                        color: Color(0xFF817866),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.hubTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFE7D8BB),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (!compact)
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF8F8677),
                        ),
                      ),
                  ],
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
              icon: Icons.home_work_outlined,
              label: l10n.hubTabShelter,
              selected: selectedSection == _HubSection.shelter,
              onTap: () => onSelected(_HubSection.shelter),
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
  const _HubSectionView({required this.section});

  final _HubSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    late final IconData icon;
    late final String title;
    late final String description;

    switch (section) {
      case _HubSection.shelter:
        icon = Icons.home_work_outlined;
        title = l10n.hubShelterTitle;
        description = l10n.hubShelterDescription;
        break;
      case _HubSection.inventory:
        icon = Icons.backpack_outlined;
        title = l10n.hubInventoryTitle;
        description = l10n.hubInventoryDescription;
        break;
      case _HubSection.expeditions:
        icon = Icons.explore_outlined;
        title = l10n.hubExpeditionsTitle;
        description = l10n.hubExpeditionsDescription;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _HubSectionContent(
        key: ValueKey(section),
        icon: icon,
        title: title,
        description: description,
      ),
    );
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
