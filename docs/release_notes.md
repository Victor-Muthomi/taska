# Taska Release Notes

## Version 3.3 - Roaming Roaster (seasoned)

Release date: 2026-04-19

Taska 3.3 (Roaming Roaster, tag: seasoned) builds on 3.0 by widening daily workflow support and polishing task management across reminders, settings, and shopping flows.

Compared with 3.0, this release adds a dedicated shopping-list experience, stronger reminder preference controls, and smoother in-app navigation between planning and list management.

### Highlights

- Added shopping-list sessions with create, open, and guarded delete flows
- Added dedicated shopping screens integrated from the task sidebar
- Added a dedicated Clock screen with alarm, timer, and stopwatch services
- Expanded settings controls for slot windows, reminder intensity, and notification channel preference
- Improved theme/settings persistence in the main app flow
- Continued focus on local-first storage and account-free usage

### Comparison with 3.0

- 3.0 introduced night-slot scheduling and rewards; 3.3 extends the product into shopping-list management
- 3.0 focused on rewards and scheduling depth; 3.3 focuses on everyday workflow breadth and settings control
- 3.0 improved stats and achievements; 3.3 improves cross-feature navigation and operational tooling for daily use

### Validation

- Static analysis expected as part of release checks
- Automated tests expected as part of release checks
- Android release readiness still depends on real-device notification and alarm validation

### Notes

- Release name: Roaming Roaster
- Release tag: seasoned
- Taska stores user data locally on device and does not require an account for core usage.

## Version 3.0

Release date: 2026-03-25

Taska 3.0 expands the app beyond flexible reminders into a more complete daily task system. Compared with 2.7, it adds a night slot to the scheduling model and a rewards layer with user stats and achievements.

### Highlights

- Night slot scheduling alongside morning, afternoon, and evening
- Rewards system with user stats, streaks, and achievements
- Stats page updates to surface progress and unlocked achievements
- Reminder and settings updates to support the expanded slot schedule
- Expanded test coverage for rewards, scheduling, and task flow integration

### Recent Improvements

- Added night slot support to task scheduling and related UI flows
- Added a rewards engine and persistence for user stats and achievements
- Updated the stats view to show achievement progress and unlocks
- Refreshed task completion and deletion flows to keep reward data in sync
- Added tests for reward logic, database schema, and task provider behavior

### Validation

- Static analysis passes
- Automated tests pass
- Android release readiness still depends on real-device notification and alarm validation

### Notes

- Taska stores user data locally on device and does not require an account for core usage.
- Some Android release packaging details, such as final signing and store listing copy, are still tracked in the release checklist.

## Version 2.7

Release date: 2026-03-21

Taska 2.7 is the first public release of the app. It introduces the core offline-first task reminder experience built around flexible time windows instead of a single fixed alarm time.

### Highlights

- Slot-based task scheduling for morning, afternoon, and evening
- Offline-first local storage with SQLite
- Local notifications for task reminders
- Snooze and unsnooze support, including date picking in the task form
- Adaptive reminder behavior based on completed, snoozed, and ignored tasks
- Lightweight analytics for completion rate and active time patterns
- JSON export and import for backup and restore
- Dark mode and local settings persistence

### Recent Improvements

- Added task snooze and unsnooze functionality
- Added a date picker in the task form for more precise rescheduling
- Improved reminder engine behavior for snoozed tasks
- Expanded provider and widget test coverage for task management flows

### Validation

- Static analysis passes
- Automated tests pass
- Android release readiness still depends on real-device notification and alarm validation

### Notes

- Taska stores user data locally on device and does not require an account for core usage.
- Some Android release packaging details, such as final signing and store listing copy, are still tracked in the release checklist.
