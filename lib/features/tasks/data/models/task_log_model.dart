import '../../domain/entities/task_log.dart';

class TaskLogModel extends TaskLog {
  const TaskLogModel({
    super.id,
    required super.taskId,
    required super.action,
    required super.loggedAt,
    super.metadata,
  });

  factory TaskLogModel.fromEntity(TaskLog log) {
    return TaskLogModel(
      id: log.id,
      taskId: log.taskId,
      action: log.action,
      loggedAt: log.loggedAt,
      metadata: log.metadata,
    );
  }

  factory TaskLogModel.fromMap(Map<String, Object?> map) {
    return TaskLogModel(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      action: map['action'] as String,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      metadata: map['metadata'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'action': action,
      'logged_at': loggedAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}
