import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/tasks/presentation/providers/tasks_providers.dart';
import 'export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(database: ref.watch(appDatabaseProvider));
});
