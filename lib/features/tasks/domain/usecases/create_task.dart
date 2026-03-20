import '../entities/task.dart';
import '../repositories/tasks_repository.dart';

class CreateTask {
  const CreateTask(this._repository);

  final TasksRepository _repository;

  Future<Task> call(Task task) {
    return _repository.createTask(task);
  }
}
