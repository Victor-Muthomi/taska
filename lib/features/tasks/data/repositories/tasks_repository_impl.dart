import '../../domain/entities/task.dart';
import '../../domain/entities/task_log.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../datasources/tasks_local_data_source.dart';
import '../models/task_log_model.dart';
import '../models/task_model.dart';

class TasksRepositoryImpl implements TasksRepository {
  TasksRepositoryImpl({required TasksLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  final TasksLocalDataSource _localDataSource;

  @override
  Future<Task> createTask(Task task) {
    return _localDataSource.createTask(TaskModel.fromEntity(task));
  }

  @override
  Future<List<Task>> getTasks() {
    return _localDataSource.getTasks();
  }

  @override
  Future<List<TaskLog>> getAllTaskLogs() {
    return _localDataSource.getAllTaskLogs();
  }

  @override
  Future<List<TaskLog>> getTaskLogs(int taskId) {
    return _localDataSource.getTaskLogs(taskId);
  }

  @override
  Future<void> updateTaskStatus({
    required int taskId,
    required TaskReminderStatus status,
  }) {
    return _localDataSource.updateTaskStatus(
      taskId: taskId,
      status: status.name,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> logTaskAction(TaskLog log) {
    return _localDataSource.logTaskAction(TaskLogModel.fromEntity(log));
  }

  @override
  Future<void> updateTask(Task task) {
    return _localDataSource.updateTask(TaskModel.fromEntity(task));
  }

  @override
  Future<void> deleteTask(int taskId) {
    return _localDataSource.deleteTask(taskId);
  }
}
