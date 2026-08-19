import 'package:cloud_functions/cloud_functions.dart';

import '../../features/jobs/domain/job_task_service.dart';
import 'firebase_functions_config.dart';

class FirebaseFunctionsJobTaskService implements JobTaskService {
  FirebaseFunctionsJobTaskService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<void> startTask({
    required String taskId,
    required String survivorId,
  }) async {
    final callable = _functions.httpsCallable('startJobTask');
    await callable.call(<String, dynamic>{
      'taskId': taskId.trim(),
      'survivorId': survivorId.trim(),
    });
  }
}
