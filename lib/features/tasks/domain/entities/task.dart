enum TaskSlot { morning, afternoon, evening, night }

enum TaskReminderStatus { pending, completed, snoozed, ignored }

enum TaskReminderIntensity { low, normal, high }

enum TaskRepeat { none, daily, weekdays, weekly }

class Task {
  const Task({
    this.id,
    required this.title,
    this.notes,
    required this.timeLabel,
    required this.slot,
    required this.repeat,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.nextReminderAt,
    required this.reminderIntervalMinutes,
    required this.reminderIntensity,
    required this.ignoredCount,
    required this.completionRate,
    this.lastReminderAt,
  });

  final int? id;
  final String title;
  final String? notes;
  final String timeLabel;
  final TaskSlot slot;
  final TaskRepeat repeat;
  final TaskReminderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime nextReminderAt;
  final int reminderIntervalMinutes;
  final TaskReminderIntensity reminderIntensity;
  final int ignoredCount;
  final double completionRate;
  final DateTime? lastReminderAt;

  Task copyWith({
    int? id,
    String? title,
    String? notes,
    String? timeLabel,
    TaskSlot? slot,
    TaskRepeat? repeat,
    TaskReminderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nextReminderAt,
    int? reminderIntervalMinutes,
    TaskReminderIntensity? reminderIntensity,
    int? ignoredCount,
    double? completionRate,
    DateTime? lastReminderAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      timeLabel: timeLabel ?? this.timeLabel,
      slot: slot ?? this.slot,
      repeat: repeat ?? this.repeat,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextReminderAt: nextReminderAt ?? this.nextReminderAt,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      reminderIntensity: reminderIntensity ?? this.reminderIntensity,
      ignoredCount: ignoredCount ?? this.ignoredCount,
      completionRate: completionRate ?? this.completionRate,
      lastReminderAt: lastReminderAt ?? this.lastReminderAt,
    );
  }
}
