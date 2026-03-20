import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/analytics/behavior_analytics_providers.dart';
import '../../../../core/export/export_providers.dart';
import '../../presentation/providers/tasks_providers.dart';

Future<void> exportTasksJson(
  BuildContext context,
  WidgetRef ref, {
  required bool shareAfterExport,
}) async {
  final tasks = await ref.read(getTasksUseCaseProvider).call();
  final logs = await ref.read(getAllTaskLogsUseCaseProvider).call();
  final exportPath = await ref
      .read(exportServiceProvider)
      .exportToJson(tasks: tasks, logs: logs);

  if (shareAfterExport) {
    await Share.shareXFiles([XFile(exportPath)], text: 'Taska backup export');
  }

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exported JSON to $exportPath')));
  }
}

Future<void> importTasksJson(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  final path = result?.files.single.path;
  if (path == null) {
    return;
  }

  await ref.read(exportServiceProvider).importFromJsonFile(path);
  ref.invalidate(tasksControllerProvider);
  ref.invalidate(behaviorInsightProvider);

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Imported backup from $path')));
  }
}

Future<void> restoreLatestBackup(BuildContext context, WidgetRef ref) async {
  final restoredPath = await ref.read(exportServiceProvider).restoreLatestBackup();
  if (restoredPath == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No backup found to restore')),
      );
    }
    return;
  }

  ref.invalidate(tasksControllerProvider);
  ref.invalidate(behaviorInsightProvider);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restored latest backup from $restoredPath')),
    );
  }
}