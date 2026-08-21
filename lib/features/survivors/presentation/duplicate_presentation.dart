import 'package:flutter/material.dart';

import '../../../core/localization/l10n.dart';

String duplicateDisplayName(BuildContext context, String duplicateId) {
  final l10n = context.l10n;
  switch (duplicateId) {
    case '01':
      return l10n.characterName1;
    case '02':
      return l10n.characterName2;
    case '03':
      return l10n.characterName3;
    case '04':
      return l10n.characterName4;
    case '05':
      return l10n.characterName5;
    default:
      return duplicateId;
  }
}

String duplicateDescription(BuildContext context, String duplicateId) {
  final l10n = context.l10n;
  switch (duplicateId) {
    case '01':
      return l10n.characterDescription1;
    case '02':
      return l10n.characterDescription2;
    case '03':
      return l10n.characterDescription3;
    case '04':
      return l10n.characterDescription4;
    case '05':
      return l10n.characterDescription5;
    default:
      return '';
  }
}

IconData duplicatePlaceholderIcon(String duplicateId) {
  switch (duplicateId) {
    case '02':
      return Icons.face_rounded;
    case '03':
      return Icons.accessibility_new_rounded;
    case '04':
      return Icons.account_circle_rounded;
    case '05':
      return Icons.person_4_outlined;
    case '01':
    default:
      return Icons.person_rounded;
  }
}
