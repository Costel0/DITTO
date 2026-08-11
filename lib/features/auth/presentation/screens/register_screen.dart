import 'package:flutter/material.dart';

import '../../../../app/navigation/app_routes.dart';
import '../../../../core/localization/l10n.dart';
import '../../application/session_controller.dart';
import '../auth_failure_localization.dart';
import '../widgets/auth_card_scaffold.dart';
import '../widgets/auth_error_box.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.sessionController,
  });

  final SessionController sessionController;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isSubmitting) return;

    final l10n = context.l10n;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    String? validationError;
    if (email.isEmpty) {
      validationError = l10n.emailRequiredError;
    } else if (password.length < 6) {
      validationError = l10n.passwordLengthError;
    } else if (password != confirmPassword) {
      validationError = l10n.passwordMismatchError;
    }

    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.sessionController.register(
        username: email,
        password: password,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        final route = widget.sessionController.needsUsername
            ? AppRoutes.usernameSetup
            : AppRoutes.welcome;
        Navigator.of(context).pushReplacementNamed(route);
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AuthCardScaffold(
      icon: Icons.person_add_alt_1_rounded,
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              autofillHints: const [AutofillHints.newUsername],
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
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.passwordLabel,
                hintText: l10n.passwordMinimumHint,
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
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
              decoration: InputDecoration(
                labelText: l10n.confirmPasswordLabel,
                hintText: l10n.confirmPasswordHint,
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmPassword
                      ? l10n.showPassword
                      : l10n.hidePassword,
                  onPressed: () {
                    setState(
                      () => _obscureConfirmPassword =
                          !_obscureConfirmPassword,
                    );
                  },
                  icon: Icon(
                    _obscureConfirmPassword
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
                onPressed: _isSubmitting ? null : _register,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.createAccountButton),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.login),
              child: Text(l10n.alreadyHaveAccount),
            ),
          ],
        ),
      ),
    );
  }
}
