abstract class JobTaskService {
  Future<void> startTask({
    required String taskId,
    required String survivorId,
  });
}
