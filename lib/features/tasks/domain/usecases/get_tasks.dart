import '../entities/task.dart';
import '../repositories/tasks_repository.dart';

class GetTasks {
  const GetTasks(this._repository);

  final TasksRepository _repository;

  Future<List<Task>> call() {
    return _repository.getTasks();
  }
}
