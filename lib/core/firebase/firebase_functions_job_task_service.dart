import 'package:cloud_functions/cloud_functions.dart';

import '../../features/jobs/domain/job_task_service.dart';
import 'firebase_functions_config.dart';

class FirebaseFunctionsJobTaskService implements JobTaskService {
  FirebaseFunctionsJobTaskService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<JobTaskStartInfo> fetchStartInfo({required String taskId}) async {
    final callable = _functions.httpsCallable('getJobTaskStartInfo');
    final result = await callable.call(<String, dynamic>{
      'taskId': taskId.trim(),
    });
    final data = result.data;
    if (data is! Map) {
      throw const FormatException('Invalid task start info response.');
    }
    return JobTaskStartInfo.fromMap(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> startTask({
    required String taskId,
    required List<String> survivorIds,
  }) async {
    final callable = _functions.httpsCallable('startJobTask');
    await callable.call(<String, dynamic>{
      'taskId': taskId.trim(),
      'survivorIds': survivorIds.map((id) => id.trim()).toList(growable: false),
    });
  }
}
