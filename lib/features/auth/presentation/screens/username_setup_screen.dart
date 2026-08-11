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
  final _usernameController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
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
      final saved = await widget.sessionController.saveUsername(username);
      if (!mounted) return;

      if (saved) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
      } else {
        setState(() => _errorMessage = context.l10n.usernameSaveError);
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
    final l10n = context.l10n;

    return AuthCardScaffold(
      icon: Icons.badge_outlined,
      title: l10n.usernameSetupTitle,
      subtitle: l10n.usernameSetupSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usernameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveUsername(),
            decoration: InputDecoration(
              labelText: l10n.usernameLabel,
              hintText: l10n.usernameHint,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            AuthErrorBox(message: _errorMessage!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _saveUsername,
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
