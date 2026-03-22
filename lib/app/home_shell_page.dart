import 'package:flutter/material.dart';

import '../features/settings/presentation/pages/settings_page.dart';
import '../features/tasks/presentation/pages/all_tasks_page.dart';
import '../features/tasks/presentation/pages/stats_page.dart';
import '../features/tasks/presentation/pages/tasks_page.dart';
import '../features/tasks/presentation/widgets/task_sidebar_drawer.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      TasksPage(embedded: true),
      AllTasksPage(embedded: true),
      StatsPage(embedded: true),
      SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Taska')),
      drawer: const TaskSidebarDrawer(),
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButton: _currentIndex <= 1 ? const _AddTaskButton() : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: 'All Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => TasksPage.showTaskFormSheet(context),
      icon: const Icon(Icons.add_task_rounded),
      label: const Text('Add Task'),
    );
  }
}
