import 'package:ditto/features/jobs/domain/job_area.dart';
import 'package:ditto/features/jobs/domain/job_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('garden task registry contains prepare and chained upgrade tasks', () {
    final gardenTasks = jobTasksForArea(JobArea.garden);

    expect(
      gardenTasks.map((task) => task.id),
      <String>[
        'prepare_garden',
        'upgrade_garden',
        'upgrade_garden_2',
        'upgrade_garden_3',
        'upgrade_garden_4',
        'upgrade_garden_5',
        'upgrade_garden_6',
      ],
    );
  });

  test('areas without registered tasks return an empty list', () {
    expect(jobTasksForArea(JobArea.workshop), isEmpty);
    expect(jobTasksForArea(JobArea.kitchen), isEmpty);
  });
}
