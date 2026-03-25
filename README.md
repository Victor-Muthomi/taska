# Taska

Taska is an offline-first Flutter app for flexible, slot-based task reminders with rewards, stats, and achievements.

It is designed around a simple idea: most tasks do not belong to one fragile alarm time. They belong to a window of the day. Taska helps you plan around the real flow of your schedule by organizing tasks into morning, afternoon, evening, and night slots, then adapting reminders based on what you complete, snooze, or ignore.

## Why Taska Exists

Many reminder apps assume you will always act at an exact minute. In practice, that is often the wrong model.

Taska focuses on:

- Reminder windows instead of one fixed point in time
- Local, private storage instead of a cloud-first workflow
- Behavior-aware scheduling that learns from completion and snooze patterns
- Lightweight planning tools that stay simple enough to use every day
- Progress feedback through rewards, user stats, and achievements

The result is a task manager that feels practical for real routines: flexible, private, and dependable even when your day shifts around.

## What It Does

- Organizes tasks into clear time windows: morning, afternoon, evening, and night
- Supports a night slot for late-day tasks and reminders
- Stores task data locally with SQLite
- Schedules local notifications for reminder delivery
- Supports snooze and unsnooze flows, including date selection in the task form
- Adapts reminder timing and intensity based on user behavior
- Tracks lightweight analytics such as completion rate and most active time
- Tracks user stats, streaks, and unlocked achievements
- Supports dark mode, JSON export/import, backup restore, and local settings persistence

## Core Experience

Taska is built to stay out of your way while still keeping your schedule visible.

You can:

- Add a task to the part of the day where it actually belongs
- Put late tasks into a dedicated night slot instead of forcing them into evening
- Let the app remind you locally without needing a server account
- Snooze tasks when the timing is off, then bring them back when it makes sense
- Export your data for backup or move it between devices
- Review basic trends to understand when you are most consistent
- See reward progress and achievements as you complete tasks

This makes Taska useful for people who want reminders that adapt to life instead of fighting it.

## Tech Stack

- Flutter
- Riverpod
- SQLite via `sqflite`
- `flutter_local_notifications`
- Local file storage via `path_provider`

## Project Structure

The app follows a feature-first layout under [`lib/`](lib/):

- `app/`: application shell and bootstrap
- `core/`: shared services such as database, reminders, notifications, analytics, export, theme, and settings
- `features/tasks/`: task domain, data layer, and presentation
- `features/settings/`: user preferences and release-facing settings UI

The repository also includes release support documents under [`docs/`](docs/):

- [`docs/release_notes.md`](docs/release_notes.md)
- [`docs/play_store_metadata.md`](docs/play_store_metadata.md)
- [`docs/release_checklist.md`](docs/release_checklist.md)

The latest release is 3.0, which adds night-slot scheduling and a rewards system with user stats and achievements.

## Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Dart SDK compatible with the Flutter version in this repo
- Android Studio or the Android SDK command-line tools for Android builds

### Install Dependencies

```bash
flutter pub get
```

### Run the App

```bash
flutter run
```

### Run Quality Checks

```bash
flutter analyze
flutter test
```

## Notifications and Permissions

Taska uses local notifications and exact alarms for reminder delivery. On Android, the app requests:

- `POST_NOTIFICATIONS`
- `SCHEDULE_EXACT_ALARM`
- `USE_EXACT_ALARM`
- `RECEIVE_BOOT_COMPLETED`

These permissions are configured in [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml). Device-level validation is still tracked in [`docs/release_checklist.md`](docs/release_checklist.md).

## Release Notes

- Current release notes are documented in [`docs/release_notes.md`](docs/release_notes.md).
- Play Store listing copy and permission messaging are documented in [`docs/play_store_metadata.md`](docs/play_store_metadata.md).
- The release checklist is documented in [`docs/release_checklist.md`](docs/release_checklist.md).

## Current Status

Taska is feature-complete for the current 3.0 release and has passing static analysis and automated tests.

The main work still pending before a public release is real-device validation of notification behavior across Android scenarios.

## Notes for Release

- Android currently builds with debug signing for release configuration to simplify local testing.
- Store listing copy and privacy-oriented messaging are already prepared in the release support docs.
- The app is designed to keep user data local on device and avoid an account requirement for core reminder features.