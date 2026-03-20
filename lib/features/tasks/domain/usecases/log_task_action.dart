import '../entities/task_log.dart';
import '../repositories/tasks_repository.dart';

class LogTaskAction {
  const LogTaskAction(this._repository);

  final TasksRepository _repository;

  Future<void> call(TaskLog log) {
    return _repository.logTaskAction(log);
  }
}
