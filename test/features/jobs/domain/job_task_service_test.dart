import 'package:ditto/features/jobs/domain/job_task_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> startInfo({
  required String mode,
  int maxExecutionCount = 1,
}) {
  return <String, dynamic>{
    'taskId': 'test_task',
    'location': 'workshop',
    'minSurvivors': 1,
    'maxSurvivors': 1,
    'statRequirements': <String, dynamic>{},
    'costInventory': <String, int>{},
    'resourceCraftingValueCost': 0,
    'energyCostPerSurvivor': 0,
    'durationSecondsPerExecution': 30,
    'outputInventoryPerExecution': <String, int>{},
    'executionMode': mode,
    'maxExecutionCount': maxExecutionCount,
    'requiredTaskIds': <String>[],
    'storable': false,
  };
}

void main() {
  test('parses all supported server-authoritative execution modes', () {
    final single = JobTaskStartInfo.fromMap(
      startInfo(mode: 'single'),
    );
    final batch = JobTaskStartInfo.fromMap(
      startInfo(mode: 'batch', maxExecutionCount: 25),
    );
    final background = JobTaskStartInfo.fromMap(
      startInfo(mode: 'background'),
    );

    expect(single.executionMode, JobTaskExecutionMode.single);
    expect(single.isBatch, isFalse);
    expect(single.isBackground, isFalse);

    expect(batch.executionMode, JobTaskExecutionMode.batch);
    expect(batch.isBatch, isTrue);
    expect(batch.maxExecutionCount, 25);

    expect(background.executionMode, JobTaskExecutionMode.background);
    expect(background.isBackground, isTrue);
    expect(background.maxExecutionCount, 1);
  });

  test('requires an authoritative task location', () {
    final data = startInfo(mode: 'single')..remove('location');

    expect(
      () => JobTaskStartInfo.fromMap(data),
      throwsFormatException,
    );
  });

  test('non-batch execution modes cannot expose a batch count', () {
    expect(
      () => JobTaskStartInfo.fromMap(
        startInfo(mode: 'single', maxExecutionCount: 2),
      ),
      throwsFormatException,
    );
    expect(
      () => JobTaskStartInfo.fromMap(
        startInfo(mode: 'background', maxExecutionCount: 2),
      ),
      throwsFormatException,
    );
  });
}
