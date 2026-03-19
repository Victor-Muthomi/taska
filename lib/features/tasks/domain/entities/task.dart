enum TaskSlot { morning, afternoon, evening }

enum TaskReminderStatus { pending, completed, snoozed, ignored }

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.slot,
    required this.status,
  });

  final int id;
  final String title;
  final TaskSlot slot;
  final TaskReminderStatus status;
}
