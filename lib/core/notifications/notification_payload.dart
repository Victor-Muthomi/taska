import 'dart:convert';

import '../../features/tasks/domain/entities/task.dart';
import 'notification_channels.dart';

class NotificationPayload {
  const NotificationPayload({
    required this.taskId,
    required this.title,
    this.notes,
    required this.slot,
    required this.snoozeMinutes,
    required this.priority,
  });

  final int taskId;
  final String title;
  final String? notes;
  final TaskSlot slot;
  final int snoozeMinutes;
  final ReminderPriority priority;

  factory NotificationPayload.fromTask(
    Task task, {
    required int snoozeMinutes,
    required ReminderPriority priority,
  }) {
    return NotificationPayload(
      taskId: task.id!,
      title: task.title,
      notes: task.notes,
      slot: task.slot,
      snoozeMinutes: snoozeMinutes,
      priority: priority,
    );
  }

  factory NotificationPayload.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return NotificationPayload(
      taskId: map['taskId'] as int,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      slot: TaskSlot.values.byName(map['slot'] as String),
      snoozeMinutes: (map['snoozeMinutes'] as num?)?.toInt() ?? 10,
      priority: ReminderPriority.values.byName(
        map['priority'] as String? ?? ReminderPriority.normal.name,
      ),
    );
  }

  String toJson() {
    return jsonEncode({
      'taskId': taskId,
      'title': title,
      'notes': notes,
      'slot': slot.name,
      'snoozeMinutes': snoozeMinutes,
      'priority': priority.name,
    });
  }
}
