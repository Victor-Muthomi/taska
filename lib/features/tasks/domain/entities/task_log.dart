class TaskLog {
  const TaskLog({
    this.id,
    required this.taskId,
    required this.action,
    required this.loggedAt,
    this.metadata,
  });

  final int? id;
  final int taskId;
  final String action;
  final DateTime loggedAt;
  final String? metadata;
}
