import '../repositories/tasks_repository.dart';

class DeleteTask {
  const DeleteTask(this._repository);

  final TasksRepository _repository;

  Future<void> call(int taskId) {
    return _repository.deleteTask(taskId);
  }
}
