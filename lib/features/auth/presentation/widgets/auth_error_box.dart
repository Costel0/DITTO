import 'package:flutter/material.dart';

class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: colors.error.withValues(alpha: 0.55)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: colors.onErrorContainer,
          fontSize: 13,
        ),
      ),
    );
  }
}
