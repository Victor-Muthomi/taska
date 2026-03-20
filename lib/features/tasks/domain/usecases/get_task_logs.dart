import '../entities/task_log.dart';
import '../repositories/tasks_repository.dart';

class GetTaskLogs {
  const GetTaskLogs(this._repository);

  final TasksRepository _repository;

  Future<List<TaskLog>> call(int taskId) {
    return _repository.getTaskLogs(taskId);
  }
}
