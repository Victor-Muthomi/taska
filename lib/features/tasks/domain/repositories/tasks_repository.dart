import '../entities/task.dart';
import '../entities/task_log.dart';

abstract class TasksRepository {
  Future<Task> createTask(Task task);
  Future<List<Task>> getTasks();
  Future<List<TaskLog>> getAllTaskLogs();
  Future<List<TaskLog>> getTaskLogs(int taskId);
  Future<void> updateTaskStatus({
    required int taskId,
    required TaskReminderStatus status,
  });
  Future<void> logTaskAction(TaskLog log);

  Future<void> updateTask(Task task);
  Future<void> deleteTask(int taskId);
}
