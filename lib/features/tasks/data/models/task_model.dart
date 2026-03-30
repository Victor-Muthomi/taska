import '../../domain/entities/task.dart';

class TaskModel extends Task {
  const TaskModel({
    super.id,
    required super.title,
    super.notes,
    required super.timeLabel,
    super.type,
    required super.slot,
    required super.repeat,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    required super.nextReminderAt,
    required super.reminderIntervalMinutes,
    required super.reminderIntensity,
    required super.ignoredCount,
    required super.completionRate,
    super.lastReminderAt,
  });

  factory TaskModel.fromMap(Map<String, Object?> map) {
    return TaskModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      timeLabel: map['time_label'] as String,
      type: map['type'] == null
          ? TaskType.normal
          : TaskType.values.byName(map['type'] as String),
      slot: TaskSlot.values.byName(map['slot'] as String),
      repeat: TaskRepeat.values.byName(map['repeat_pattern'] as String),
      status: TaskReminderStatus.values.byName(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      nextReminderAt: DateTime.parse(map['next_reminder_at'] as String),
      reminderIntervalMinutes: map['reminder_interval_minutes'] as int,
      reminderIntensity: TaskReminderIntensity.values.byName(
        map['reminder_intensity'] as String,
      ),
      ignoredCount: map['ignored_count'] as int,
      completionRate: (map['completion_rate'] as num).toDouble(),
      lastReminderAt: map['last_reminder_at'] == null
          ? null
          : DateTime.parse(map['last_reminder_at'] as String),
    );
  }

  factory TaskModel.fromEntity(Task task) {
    return TaskModel(
      id: task.id,
      title: task.title,
      notes: task.notes,
      timeLabel: task.timeLabel,
      type: task.type,
      slot: task.slot,
      repeat: task.repeat,
      status: task.status,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      nextReminderAt: task.nextReminderAt,
      reminderIntervalMinutes: task.reminderIntervalMinutes,
      reminderIntensity: task.reminderIntensity,
      ignoredCount: task.ignoredCount,
      completionRate: task.completionRate,
      lastReminderAt: task.lastReminderAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'time_label': timeLabel,
      'type': type.name,
      'slot': slot.name,
      'repeat_pattern': repeat.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'next_reminder_at': nextReminderAt.toIso8601String(),
      'reminder_interval_minutes': reminderIntervalMinutes,
      'reminder_intensity': reminderIntensity.name,
      'ignored_count': ignoredCount,
      'completion_rate': completionRate,
      'last_reminder_at': lastReminderAt?.toIso8601String(),
    };
  }

  @override
  TaskModel copyWith({
    int? id,
    String? title,
    String? notes,
    String? timeLabel,
    TaskType? type,
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
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      timeLabel: timeLabel ?? this.timeLabel,
      type: type ?? this.type,
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
