import 'package:flutter/material.dart';

import '../../../../app/navigation/app_routes.dart';
import '../../../../core/localization/l10n.dart';
import '../../application/session_controller.dart';
import '../auth_failure_localization.dart';
import '../widgets/auth_card_scaffold.dart';
import '../widgets/auth_error_box.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.sessionController,
  });

  final SessionController sessionController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.sessionController.signIn(
        username: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        Navigator.of(context).pushReplacementNamed(_postAuthRoute());
      } else {
        setState(() {
          _errorMessage = localizedAuthFailure(context, result.failure);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _skip() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.sessionController.skip();
      if (!mounted) return;

      if (result.isSuccess) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _postAuthRoute() {
    return widget.sessionController.needsProfileSetup
        ? AppRoutes.usernameSetup
        : AppRoutes.welcome;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AuthCardScaffold(
      icon: Icons.auto_awesome_rounded,
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.emailLabel,
                hintText: l10n.emailHint,
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: l10n.passwordLabel,
                hintText: l10n.passwordHint,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? l10n.showPassword
                      : l10n.hidePassword,
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
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
                onPressed: _isSubmitting ? null : _login,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.continueButton),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.register),
              child: Text(l10n.createAccountPrompt),
            ),
            const SizedBox(height: 2),
            TextButton(
              onPressed: _isSubmitting ? null : _skip,
              child: Text(l10n.skipForNow),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.developmentShortcut,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7F786A),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
