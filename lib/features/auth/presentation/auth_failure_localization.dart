import 'package:flutter/widgets.dart';

import '../../../core/localization/l10n.dart';
import '../domain/auth_service.dart';

String localizedAuthFailure(BuildContext context, AuthFailure? failure) {
  final l10n = context.l10n;

  switch (failure) {
    case AuthFailure.emailAlreadyInUse:
      return l10n.authEmailAlreadyInUse;
    case AuthFailure.invalidEmail:
      return l10n.authInvalidEmail;
    case AuthFailure.weakPassword:
      return l10n.authWeakPassword;
    case AuthFailure.invalidCredentials:
      return l10n.authInvalidCredentials;
    case AuthFailure.tooManyRequests:
      return l10n.authTooManyRequests;
    case AuthFailure.unknown:
    case null:
      return l10n.authUnknownError;
  }
}
