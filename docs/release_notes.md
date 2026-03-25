# Taska Release Notes

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
