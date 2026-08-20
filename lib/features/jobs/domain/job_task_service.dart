class JobTaskStartInfo {
  const JobTaskStartInfo({
    required this.taskId,
    required this.minSurvivors,
    required this.maxSurvivors,
    required this.costInventory,
    required this.requiredTaskIds,
    required this.storable,
  });

  final String taskId;
  final int minSurvivors;
  final int maxSurvivors;
  final Map<String, int> costInventory;
  final List<String> requiredTaskIds;
  final bool storable;

  factory JobTaskStartInfo.fromMap(Map<String, dynamic> map) {
    final taskId = map['taskId'];
    final minSurvivors = map['minSurvivors'];
    final maxSurvivors = map['maxSurvivors'];
    final costRaw = map['costInventory'];
    final requiredRaw = map['requiredTaskIds'];
    final storable = map['storable'];

    if (taskId is! String || taskId.trim().isEmpty) {
      throw const FormatException('Task start info has an invalid taskId.');
    }
    if (minSurvivors is! num || minSurvivors.toInt() < 1) {
      throw const FormatException('Task start info has an invalid minimum.');
    }
    if (maxSurvivors is! num ||
        maxSurvivors.toInt() < minSurvivors.toInt()) {
      throw const FormatException('Task start info has an invalid maximum.');
    }
    if (costRaw is! Map) {
      throw const FormatException('Task start info cost must be a map.');
    }
    if (requiredRaw is! List || requiredRaw.any((value) => value is! String)) {
      throw const FormatException('Task prerequisites must be string IDs.');
    }
    if (storable is! bool) {
      throw const FormatException('Task storable flag must be boolean.');
    }

    final costInventory = <String, int>{};
    for (final entry in costRaw.entries) {
      if (entry.key is! String || entry.value is! num) {
        throw const FormatException('Task cost contains an invalid quantity.');
      }
      costInventory[entry.key as String] = (entry.value as num).toInt();
    }

    return JobTaskStartInfo(
      taskId: taskId.trim(),
      minSurvivors: minSurvivors.toInt(),
      maxSurvivors: maxSurvivors.toInt(),
      costInventory: Map<String, int>.unmodifiable(costInventory),
      requiredTaskIds: List<String>.unmodifiable(requiredRaw.cast<String>()),
      storable: storable,
    );
  }
}

abstract class JobTaskService {
  Future<JobTaskStartInfo> fetchStartInfo({required String taskId});

  Future<void> startTask({
    required String taskId,
    required List<String> survivorIds,
  });
}
