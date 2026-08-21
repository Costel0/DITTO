import 'package:flutter/material.dart';

import '../../../core/localization/l10n.dart';
import '../../survivors/domain/survivor.dart';
import '../../survivors/presentation/duplicate_presentation.dart';
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
    case 'upgrade_garden_2':
      return '${context.l10n.jobUpgradeGardenTitle} 2';
    case 'upgrade_garden_3':
      return '${context.l10n.jobUpgradeGardenTitle} 3';
    case 'upgrade_garden_4':
      return '${context.l10n.jobUpgradeGardenTitle} 4';
    case 'upgrade_garden_5':
      return '${context.l10n.jobUpgradeGardenTitle} 5';
    case 'upgrade_garden_6':
      return '${context.l10n.jobUpgradeGardenTitle} 6';
    default:
      return taskId;
  }
}

String jobTaskDescription(BuildContext context, String taskId) {
  switch (taskId) {
    case 'prepare_garden':
      return context.l10n.jobPrepareGardenDescription;
    case 'upgrade_garden':
    case 'upgrade_garden_2':
    case 'upgrade_garden_3':
    case 'upgrade_garden_4':
    case 'upgrade_garden_5':
    case 'upgrade_garden_6':
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

String survivorDisplayName(BuildContext context, Survivor survivor) =>
    duplicateDisplayName(context, survivor.duplicateId);
