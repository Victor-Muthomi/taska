import '../entities/task.dart';
import '../repositories/tasks_repository.dart';

class UpdateTaskStatus {
  const UpdateTaskStatus(this._repository);

  final TasksRepository _repository;

  Future<void> call({required int taskId, required TaskReminderStatus status}) {
    return _repository.updateTaskStatus(taskId: taskId, status: status);
  }
}
