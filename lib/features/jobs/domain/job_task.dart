import 'job_area.dart';

class JobTaskDefinition {
  const JobTaskDefinition({
    required this.id,
    required this.area,
  });

  final String id;
  final JobArea area;
}

const prepareGardenTask = JobTaskDefinition(
  id: 'prepare_garden',
  area: JobArea.garden,
);

const upgradeGardenTask = JobTaskDefinition(
  id: 'upgrade_garden',
  area: JobArea.garden,
);

const jobTasks = <JobTaskDefinition>[
  prepareGardenTask,
  upgradeGardenTask,
];

List<JobTaskDefinition> jobTasksForArea(JobArea area) => jobTasks
    .where((task) => task.area == area)
    .toList(growable: false);
