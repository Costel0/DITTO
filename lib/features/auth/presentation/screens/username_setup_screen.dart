import 'package:flutter/material.dart';

import '../../../../app/navigation/app_routes.dart';
import '../../../../core/localization/l10n.dart';
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
  static const _characterIds = <String>[
    'survivor_01',
    'survivor_02',
    'survivor_03',
    'survivor_04',
  ];

  static const _characterIcons = <IconData>[
    Icons.person_rounded,
    Icons.face_rounded,
    Icons.accessibility_new_rounded,
    Icons.account_circle_rounded,
  ];

  final _usernameController = TextEditingController();

  String? _selectedCharacterId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existingUsername = widget.sessionController.profileUsername;
    if (existingUsername != null && existingUsername.trim().isNotEmpty) {
      _usernameController.text = existingUsername.trim();
    }
    _selectedCharacterId = widget.sessionController.characterId;
  }

  @override
  void dispose() {
    _usernameController.dispose();
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

    final characterId = _selectedCharacterId;
    if (characterId == null) {
      setState(() => _errorMessage = l10n.characterRequiredError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final saved = await widget.sessionController.saveInitialProfile(
        username: username,
        characterId: characterId,
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
            l10n.initialCharacterHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF928A7A),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _characterIds.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final characterId = _characterIds[index];
              final selected = characterId == _selectedCharacterId;

              return _CharacterPlaceholder(
                icon: _characterIcons[index],
                label: l10n.characterOption(index + 1),
                selected: selected,
                onTap: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _selectedCharacterId = characterId;
                          _errorMessage = null;
                        });
                      },
              );
            },
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

class _CharacterPlaceholder extends StatelessWidget {
  const _CharacterPlaceholder({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF332C20)
                : const Color(0xFF171713),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : const Color(0xFF4A4338),
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: Icon(
                            icon,
                            size: 66,
                            color: selected
                                ? const Color(0xFFD2B98A)
                                : const Color(0xFF817866),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected
                              ? const Color(0xFFE7D9BC)
                              : const Color(0xFFA39A89),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 19,
                    color: Color(0xFFD2A35D),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
