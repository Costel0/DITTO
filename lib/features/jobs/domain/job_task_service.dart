class JobTaskStartInfo {
  const JobTaskStartInfo({
    required this.taskId,
    required this.minSurvivors,
    required this.maxSurvivors,
    required this.statRequirements,
    required this.costInventory,
    required this.requiredTaskIds,
    required this.storable,
  });

  final String taskId;
  final int minSurvivors;
  final int maxSurvivors;

  /// Survivor stat -> exclusive minimum required by the task.
  /// Example: {'care': 3} means the selected Survivor must have care > 3.
  final Map<String, int> statRequirements;

  final Map<String, int> costInventory;
  final List<String> requiredTaskIds;
  final bool storable;

  factory JobTaskStartInfo.fromMap(Map<String, dynamic> map) {
    final taskId = map['taskId'];
    final minSurvivors = map['minSurvivors'];
    final maxSurvivors = map['maxSurvivors'];
    final statRequirementsRaw = map['statRequirements'];
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
    if (statRequirementsRaw != null && statRequirementsRaw is! Map) {
      throw const FormatException('Task stat requirements must be a map.');
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

    final statRequirements = <String, int>{};
    if (statRequirementsRaw is Map) {
      for (final entry in statRequirementsRaw.entries) {
        final requirement = entry.value;
        if (entry.key is! String || requirement is! Map) {
          throw const FormatException(
            'Task stat requirements contain an invalid entry.',
          );
        }
        final greaterThan = requirement['greaterThan'];
        if (greaterThan is! num ||
            !greaterThan.isFinite ||
            greaterThan != greaterThan.toInt()) {
          throw const FormatException(
            'Task stat requirement threshold must be an integer.',
          );
        }
        statRequirements[entry.key as String] = greaterThan.toInt();
      }
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
      statRequirements: Map<String, int>.unmodifiable(statRequirements),
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
