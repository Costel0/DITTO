import 'package:flutter/material.dart';

import '../../../../app/navigation/app_routes.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/presentation/survival_background.dart';
import '../../../auth/application/session_controller.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.sessionController,
  });

  final SessionController sessionController;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isResettingProfile = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      body: SurvivalBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 34,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFF5A4D38)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 28,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 96,
                            height: 110,
                            decoration: BoxDecoration(
                              color: const Color(0xFF171713),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF67583F),
                              ),
                            ),
                            child: Icon(
                              _characterIcon(sessionController.characterId),
                              color: const Color(0xFFC6B185),
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.welcomeMessage(sessionController.username),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: const Color(0xFFF0E5CF),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: TextButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.logout),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: IconButton(
                  tooltip: l10n.resetProfileTestTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: _isResettingProfile ? null : _resetProfileForTesting,
                  icon: _isResettingProfile
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }
}
