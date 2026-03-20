import '../entities/task_log.dart';
import '../repositories/tasks_repository.dart';

class GetAllTaskLogs {
  const GetAllTaskLogs(this._repository);

  final TasksRepository _repository;

  Future<List<TaskLog>> call() {
    return _repository.getAllTaskLogs();
  }
}
