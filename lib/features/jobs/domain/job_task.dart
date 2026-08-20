import 'job_area.dart';

class JobTaskDefinition {
  const JobTaskDefinition({
    required this.id,
    required this.area,
  });

  final String id;
  final JobArea area;
}

const clearGardenTask = JobTaskDefinition(
  id: 'prepare_garden',
  area: JobArea.garden,
);

List<JobTaskDefinition> jobTasksForArea(JobArea area) {
  switch (area) {
    case JobArea.workshop:
    case JobArea.kitchen:
      return const <JobTaskDefinition>[];
    case JobArea.garden:
      return const <JobTaskDefinition>[clearGardenTask];
  }
}
