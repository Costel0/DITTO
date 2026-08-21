import 'package:flutter/material.dart';

import '../../../../app/navigation/app_routes.dart';
import '../../../../core/localization/l10n.dart';
import '../../../survivors/domain/duplicate_catalog.dart';
import '../../../survivors/presentation/duplicate_presentation.dart';
import '../../../survivors/presentation/widgets/survivor_portrait_artwork.dart';
import '../../application/session_controller.dart';
import '../widgets/auth_card_scaffold.dart';
import '../widgets/auth_error_box.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({
    super.key,
    required this.sessionController,
  });

  final SessionController sessionController;

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _usernameController = TextEditingController();
  late final PageController _pageController;

  late int _selectedDuplicateIndex;
  late String _selectedDuplicateId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existingUsername = widget.sessionController.profileUsername;
    if (existingUsername != null && existingUsername.trim().isNotEmpty) {
      _usernameController.text = existingUsername.trim();
    }

    final existingDuplicateId = widget.sessionController.initialDuplicateId;
    final existingIndex = predefinedDuplicates.indexWhere(
      (duplicate) => duplicate.id == existingDuplicateId,
    );
    _selectedDuplicateIndex = existingIndex >= 0 ? existingIndex : 0;
    _selectedDuplicateId = predefinedDuplicates[_selectedDuplicateIndex].id;
    _pageController = PageController(initialPage: _selectedDuplicateIndex);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_isSubmitting) return;

    final l10n = context.l10n;
    final username = _usernameController.text.trim();

    if (username.length < 3 || username.length > 24) {
      setState(() => _errorMessage = l10n.usernameLengthError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final saved = await widget.sessionController.saveInitialProfile(
        username: username,
        duplicateId: _selectedDuplicateId,
      );
      if (!mounted) return;

      if (saved) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
      } else {
        setState(() => _errorMessage = context.l10n.profileSaveError);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _logout() async {
    await widget.sessionController.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  void _selectDuplicate(int index) {
    setState(() {
      _selectedDuplicateIndex = index;
      _selectedDuplicateId = predefinedDuplicates[index].id;
      _errorMessage = null;
    });
  }

  void _changeDuplicate(int delta) {
    final target = _selectedDuplicateIndex + delta;
    if (target < 0 || target >= predefinedDuplicates.length) return;

    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AuthCardScaffold(
      icon: Icons.badge_outlined,
      title: l10n.usernameSetupTitle,
      subtitle: l10n.usernameSetupSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.usernameLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: const Color(0xFFD8C8A8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _usernameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveProfile(),
            decoration: InputDecoration(
              hintText: l10n.usernameHint,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            l10n.initialCharacterLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: const Color(0xFFD8C8A8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.characterNavigationHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF928A7A),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 620,
            child: PageView.builder(
              controller: _pageController,
              itemCount: predefinedDuplicates.length,
              onPageChanged: _selectDuplicate,
              itemBuilder: (context, index) {
                final duplicate = predefinedDuplicates[index];
                final stats = duplicate.baseStats;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _CharacterSheet(
                    imageAsset: duplicate.dormantAssetPath,
                    fallbackImageAsset: duplicate.idleAssetPath,
                    placeholderIcon: duplicatePlaceholderIcon(duplicate.id),
                    name: duplicateDisplayName(context, duplicate.id),
                    description: duplicateDescription(context, duplicate.id),
                    stats: [
                      _CharacterStat(
                        label: l10n.statStrength,
                        value: stats.strength,
                      ),
                      _CharacterStat(
                        label: l10n.statDexterity,
                        value: stats.dexterity,
                      ),
                      _CharacterStat(
                        label: l10n.statConstitution,
                        value: stats.constitution,
                      ),
                      _CharacterStat(
                        label: l10n.statStealth,
                        value: stats.stealth,
                      ),
                      _CharacterStat(
                        label: l10n.statCare,
                        value: stats.care,
                      ),
                      _CharacterStat(
                        label: l10n.statCunning,
                        value: stats.cunning,
                      ),
                      _CharacterStat(
                        label: l10n.statCharm,
                        value: stats.charm,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.outlined(
                tooltip: l10n.previousCharacter,
                onPressed: _selectedDuplicateIndex == 0
                    ? null
                    : () => _changeDuplicate(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(predefinedDuplicates.length, (index) {
                    final selected = index == _selectedDuplicateIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selected ? 20 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary
                            : const Color(0xFF5A5245),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
              ),
              IconButton.outlined(
                tooltip: l10n.nextCharacter,
                onPressed:
                    _selectedDuplicateIndex == predefinedDuplicates.length - 1
                        ? null
                        : () => _changeDuplicate(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            AuthErrorBox(message: _errorMessage!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _saveProfile,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.continueButton),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSubmitting ? null : _logout,
            child: Text(l10n.useAnotherAccount),
          ),
        ],
      ),
    );
  }
}

class _CharacterSheet extends StatelessWidget {
  const _CharacterSheet({
    required this.imageAsset,
    required this.fallbackImageAsset,
    required this.placeholderIcon,
    required this.name,
    required this.description,
    required this.stats,
  });

  final String imageAsset;
  final String fallbackImageAsset;
  final IconData placeholderIcon;
  final String name;
  final String description;
  final List<_CharacterStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171713),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF5A4D38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _CharacterPortrait(
              imageAsset: imageAsset,
              fallbackImageAsset: fallbackImageAsset,
              placeholderIcon: placeholderIcon,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFE8D8B7),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFFA9A08F),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          ...stats.map(
            (stat) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StatBar(stat: stat),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterPortrait extends StatelessWidget {
  const _CharacterPortrait({
    required this.imageAsset,
    required this.fallbackImageAsset,
    required this.placeholderIcon,
  });

  final String imageAsset;
  final String fallbackImageAsset;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return SurvivorPortraitArtwork(
      imageAssetPath: imageAsset,
      fallbackImageAssetPath: fallbackImageAsset,
      placeholderIcon: placeholderIcon,
    );
  }
}

class _CharacterStat {
  const _CharacterStat({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.stat});

  final _CharacterStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFFC5BAA4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: stat.value / 10,
              minHeight: 9,
              backgroundColor: const Color(0xFF353128),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            '${stat.value}/10',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFFD8C8A8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
