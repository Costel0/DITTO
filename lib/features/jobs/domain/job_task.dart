import 'job_area.dart';

class JobTaskDefinition {
  const JobTaskDefinition({
    required this.id,
    required this.area,
  });

  final String id;
  final JobArea area;
}

const cleanKitchenTask = JobTaskDefinition(
  id: 'clean_kitchen',
  area: JobArea.kitchen,
);

const craftElectronicsFromScrapTask = JobTaskDefinition(
  id: 'craft_electronics_from_scrap',
  area: JobArea.workshop,
);

const plantPotatoesTask = JobTaskDefinition(
  id: 'plant_potatoes',
  area: JobArea.garden,
);

const prepareGardenTask = JobTaskDefinition(
  id: 'prepare_garden',
  area: JobArea.garden,
);

const upgradeGardenTask = JobTaskDefinition(
  id: 'upgrade_garden',
  area: JobArea.garden,
);

const upgradeGarden2Task = JobTaskDefinition(
  id: 'upgrade_garden_2',
  area: JobArea.garden,
);

const upgradeGarden3Task = JobTaskDefinition(
  id: 'upgrade_garden_3',
  area: JobArea.garden,
);

const upgradeGarden4Task = JobTaskDefinition(
  id: 'upgrade_garden_4',
  area: JobArea.garden,
);

const upgradeGarden5Task = JobTaskDefinition(
  id: 'upgrade_garden_5',
  area: JobArea.garden,
);

const upgradeGarden6Task = JobTaskDefinition(
  id: 'upgrade_garden_6',
  area: JobArea.garden,
);

const jobTasks = <JobTaskDefinition>[
  cleanKitchenTask,
  craftElectronicsFromScrapTask,
  prepareGardenTask,
  plantPotatoesTask,
  upgradeGardenTask,
  upgradeGarden2Task,
  upgradeGarden3Task,
  upgradeGarden4Task,
  upgradeGarden5Task,
  upgradeGarden6Task,
];

List<JobTaskDefinition> jobTasksForArea(JobArea area) => jobTasks
    .where((task) => task.area == area)
    .toList(growable: false);
