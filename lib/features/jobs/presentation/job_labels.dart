import 'package:flutter/material.dart';

import '../../../core/localization/l10n.dart';
import '../../survivors/domain/survivor.dart';
import '../domain/job_area.dart';

String jobAreaTitle(BuildContext context, JobArea area) {
  final l10n = context.l10n;
  switch (area) {
    case JobArea.workshop:
      return l10n.jobWorkshopTitle;
    case JobArea.kitchen:
      return l10n.jobKitchenTitle;
    case JobArea.garden:
      return l10n.jobGardenTitle;
  }
}

String jobAreaDescription(BuildContext context, JobArea area) {
  final l10n = context.l10n;
  switch (area) {
    case JobArea.workshop:
      return l10n.jobWorkshopDescription;
    case JobArea.kitchen:
      return l10n.jobKitchenDescription;
    case JobArea.garden:
      return l10n.jobGardenDescription;
  }
}

IconData jobAreaIcon(JobArea area) {
  switch (area) {
    case JobArea.workshop:
      return Icons.handyman_outlined;
    case JobArea.kitchen:
      return Icons.soup_kitchen_outlined;
    case JobArea.garden:
      return Icons.grass_outlined;
  }
}

String jobTaskTitle(BuildContext context, String taskId) {
  switch (taskId) {
    case 'prepare_garden':
      return context.l10n.jobPrepareGardenTitle;
    case 'upgrade_garden':
      return context.l10n.jobUpgradeGardenTitle;
    default:
      return taskId;
  }
}

String jobTaskDescription(BuildContext context, String taskId) {
  switch (taskId) {
    case 'prepare_garden':
      return context.l10n.jobPrepareGardenDescription;
    case 'upgrade_garden':
      return context.l10n.jobUpgradeGardenDescription;
    default:
      return '';
  }
}

String jobActivityLabel(BuildContext context, String activity) {
  if (activity == 'sleeping') {
    return context.l10n.jobSleepingTitle;
  }
  return jobTaskTitle(context, activity);
}

String survivorDisplayName(BuildContext context, Survivor survivor) {
  final l10n = context.l10n;
  switch (survivor.duplicateId) {
    case '01':
      return l10n.characterName1;
    case '02':
      return l10n.characterName2;
    case '03':
      return l10n.characterName3;
    case '04':
      return l10n.characterName4;
    default:
      return survivor.duplicateId;
  }
}
