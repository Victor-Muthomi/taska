import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/notifications/notification_channels.dart';
import '../../../../core/notifications/notification_logic.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/reminders/reminder_engine_providers.dart';
import '../../../../core/rewards/reward_providers.dart';
import '../../../../core/scheduling/slot_schedule.dart';
import '../../../../core/settings/app_settings_providers.dart';
import '../../data/datasources/tasks_local_data_source.dart';
import '../../data/repositories/tasks_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_log.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../../domain/usecases/create_task.dart';
import '../../domain/usecases/delete_task.dart';
import '../../domain/usecases/get_all_task_logs.dart';
import '../../domain/usecases/get_tasks.dart';
import '../../domain/usecases/get_task_logs.dart';
import '../../domain/usecases/log_task_action.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final tasksLocalDataSourceProvider = Provider<TasksLocalDataSource>((ref) {
  return TasksLocalDataSource(databaseHelper: ref.watch(appDatabaseProvider));
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepositoryImpl(
    localDataSource: ref.watch(tasksLocalDataSourceProvider),
  );
});

final getTasksUseCaseProvider = Provider<GetTasks>((ref) {
  return GetTasks(ref.watch(tasksRepositoryProvider));
});

final createTaskUseCaseProvider = Provider<CreateTask>((ref) {
  return CreateTask(ref.watch(tasksRepositoryProvider));
});

final getAllTaskLogsUseCaseProvider = Provider<GetAllTaskLogs>((ref) {
  return GetAllTaskLogs(ref.watch(tasksRepositoryProvider));
});

final getTaskLogsUseCaseProvider = Provider<GetTaskLogs>((ref) {
  return GetTaskLogs(ref.watch(tasksRepositoryProvider));
});

final logTaskActionUseCaseProvider = Provider<LogTaskAction>((ref) {
  return LogTaskAction(ref.watch(tasksRepositoryProvider));
});

final deleteTaskUseCaseProvider = Provider<DeleteTask>((ref) {
  return DeleteTask(ref.watch(tasksRepositoryProvider));
});

final tasksControllerProvider =
    AsyncNotifierProvider<TasksController, List<Task>>(TasksController.new);

class TasksController extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    return _refreshTasks();
  }

  Future<void> addTask({
    required String title,
    String? notes,
    required String timeLabel,
    required TaskSlot slot,
    required TaskRepeat repeat,
    DateTime? scheduledFor,
  }) async {
    final now = DateTime.now();
    final normalizedTime = SlotSchedule.normalizeTimeForSlot(timeLabel, slot);
    final planningAnchor = scheduledFor ?? now;
    final task = ref
        .read(reminderEngineProvider)
        .createInitialPlan(
          Task(
            title: title,
            notes: notes,
            timeLabel: normalizedTime,
            slot: slot,
            repeat: repeat,
            status: TaskReminderStatus.pending,
            createdAt: planningAnchor,
            updatedAt: now,
            nextReminderAt: planningAnchor,
            reminderIntervalMinutes: 180,
            reminderIntensity: TaskReminderIntensity.normal,
            ignoredCount: 0,
            completionRate: 0,
          ),
        );

    final plannedTask = task.copyWith(createdAt: now, updatedAt: now);

    final createdTask = await ref.read(createTaskUseCaseProvider).call(plannedTask);
    final taskId = createdTask.id;
    if (taskId != null) {
      await ref
          .read(logTaskActionUseCaseProvider)
          .call(TaskLog(taskId: taskId, action: 'created', loggedAt: now));
      await scheduleReminder(createdTask);
    }
    state = AsyncData(await _refreshTasks());
  }

  Future<void> updateTaskDetails({
    required Task task,
    required String title,
    String? notes,
    required String timeLabel,
    required TaskSlot slot,
    required TaskRepeat repeat,
    DateTime? scheduledFor,
  }) async {
    final now = DateTime.now();
    final normalizedTime = SlotSchedule.normalizeTimeForSlot(timeLabel, slot);
    final planningAnchor = scheduledFor ?? now;
    final recalculatedTask = ref
        .read(reminderEngineProvider)
        .createInitialPlan(
          task.copyWith(
            title: title,
            notes: notes,
            timeLabel: normalizedTime,
            slot: slot,
            repeat: repeat,
            status: TaskReminderStatus.pending,
            createdAt: planningAnchor,
            updatedAt: now,
          ),
        );
    final updatedTask = recalculatedTask.copyWith(
      createdAt: task.createdAt,
      updatedAt: now,
    );

    await ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    final taskId = task.id;
    if (taskId != null) {
      await ref
          .read(logTaskActionUseCaseProvider)
          .call(
            TaskLog(
              taskId: taskId,
              action: 'updated',
              loggedAt: now,
            ),
          );
      await ref.read(notificationServiceProvider).cancelTaskNotification(taskId);
      await scheduleReminder(updatedTask);
    }
    state = AsyncData(await _refreshTasks());
  }

  Future<void> markTaskDone(Task task) async {
    final taskId = task.id;
    if (taskId == null) {
      return;
    }

    final logs = await ref.read(getTaskLogsUseCaseProvider).call(taskId);
    final updatedTask = ref
        .read(reminderEngineProvider)
        .applyCompletion(task, logs);
    final completionLog = TaskLog(
      taskId: taskId,
      action: 'completed',
      loggedAt: DateTime.now(),
    );
    await ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    await ref.read(logTaskActionUseCaseProvider).call(completionLog);
    await ref.read(rewardEngineProvider).refreshFromLogs();
    if (updatedTask.status == TaskReminderStatus.completed) {
      await ref
          .read(notificationServiceProvider)
          .cancelTaskNotification(taskId);
    } else {
      await scheduleReminder(updatedTask);
    }
    state = AsyncData(await _refreshTasks());
  }

  Future<void> snoozeTask(Task task) async {
    final taskId = task.id;
    if (taskId == null) {
      return;
    }

    final logs = await ref.read(getTaskLogsUseCaseProvider).call(taskId);
    final updatedTask = ref
        .read(reminderEngineProvider)
        .applySnooze(task, logs);
    await ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    await ref
        .read(logTaskActionUseCaseProvider)
        .call(
          TaskLog(
            taskId: taskId,
            action: 'notification_snoozed',
            loggedAt: DateTime.now(),
          ),
        );
    await scheduleReminder(updatedTask);
    state = AsyncData(await ref.read(getTasksUseCaseProvider).call());
  }

  Future<void> unsnoozeTask(Task task) async {
    final taskId = task.id;
    if (taskId == null) {
      return;
    }

    final logs = await ref.read(getTaskLogsUseCaseProvider).call(taskId);
    final updatedTask = ref
        .read(reminderEngineProvider)
        .applyUnsnooze(task, logs);
    await ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    await ref.read(notificationServiceProvider).cancelTaskNotification(taskId);
    await scheduleReminder(
      updatedTask,
      logAction: 'notification_unsnoozed',
    );
    state = AsyncData(await _refreshTasks());
  }

  Future<void> toggleSnoozeTask(Task task) async {
    if (task.status == TaskReminderStatus.snoozed) {
      await unsnoozeTask(task);
      return;
    }

    await snoozeTask(task);
  }

  Future<void> delete(int taskId) async {
    await ref
        .read(logTaskActionUseCaseProvider)
        .call(
          TaskLog(taskId: taskId, action: 'deleted', loggedAt: DateTime.now()),
        );
    await ref.read(deleteTaskUseCaseProvider).call(taskId);
    state = AsyncData(await _refreshTasks());
    await ref.read(rewardEngineProvider).refreshFromLogs();
  }

  Future<void> scheduleReminder(
    Task task, {
    ReminderPriority? priority,
    String logAction = 'notification_scheduled',
  }) async {
    await ref
        .read(notificationServiceProvider)
        .scheduleTaskNotification(
          task: task,
          settings: ref.read(appSettingsProvider),
          priority: priority,
        );

    final taskId = task.id;
    if (taskId != null) {
      await ref
          .read(logTaskActionUseCaseProvider)
          .call(
            TaskLog(
              taskId: taskId,
              action: logAction,
              loggedAt: DateTime.now(),
            ),
          );
      await ref.read(rewardEngineProvider).refreshFromLogs();
    }
  }

  Future<void> cancelReminder(Task task) async {
    final taskId = task.id;
    if (taskId == null) {
      return;
    }

    await ref.read(notificationServiceProvider).cancelTaskNotification(taskId);
    await ref
        .read(logTaskActionUseCaseProvider)
        .call(
          TaskLog(
            taskId: taskId,
            action: 'notification_cancelled',
            loggedAt: DateTime.now(),
          ),
        );
    await ref.read(rewardEngineProvider).refreshFromLogs();
  }

  Future<void> handleNotificationEvent(NotificationEvent event) async {
    final tasks = await ref.read(getTasksUseCaseProvider).call();
    final task = tasks.cast<Task?>().firstWhere(
      (candidate) => candidate?.id == event.taskId,
      orElse: () => null,
    );
    if (task == null) {
      return;
    }

    switch (event.type) {
      case NotificationEventType.opened:
        await ref
            .read(logTaskActionUseCaseProvider)
            .call(
              TaskLog(
                taskId: event.taskId,
                action: 'notification_opened',
                loggedAt: DateTime.now(),
              ),
            );
        await ref.read(rewardEngineProvider).refreshFromLogs();
        break;
      case NotificationEventType.snoozed:
        await snoozeTask(task);
        return;
    }

    state = AsyncData(await _refreshTasks());
  }

  Future<void> _syncMissedTasks(List<Task> tasks) async {
    final engine = ref.read(reminderEngineProvider);
    for (final task in tasks) {
      final taskId = task.id;
      if (taskId == null || !engine.isMissed(task)) {
        continue;
      }

      final logs = await ref.read(getTaskLogsUseCaseProvider).call(taskId);
      final ignoredTask = engine.applyIgnored(task, logs);
      await ref.read(tasksRepositoryProvider).updateTask(ignoredTask);
      await ref
          .read(logTaskActionUseCaseProvider)
          .call(
            TaskLog(
              taskId: taskId,
              action: 'ignored',
              loggedAt: DateTime.now(),
            ),
          );
      await scheduleReminder(ignoredTask);
    }
  }

  Future<List<Task>> _refreshTasks() async {
    final tasks = await ref.read(getTasksUseCaseProvider).call();
    await _syncMissedTasks(tasks);
    await _reconcileScheduledReminders();
    return ref.read(getTasksUseCaseProvider).call();
  }

  Future<void> _reconcileScheduledReminders() async {
    final tasks = await ref.read(getTasksUseCaseProvider).call();
    for (final task in tasks) {
      final taskId = task.id;
      if (taskId == null) {
        continue;
      }

      if (task.status == TaskReminderStatus.completed) {
        await ref
            .read(notificationServiceProvider)
            .cancelTaskNotification(taskId);
        continue;
      }

      if (!task.nextReminderAt.isBefore(DateTime.now())) {
        await ref
            .read(notificationServiceProvider)
            .scheduleTaskNotification(
              task: task,
              settings: ref.read(appSettingsProvider),
            );
      }
    }
  }
}
