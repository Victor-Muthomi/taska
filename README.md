# Taska

Taska is an offline-first Flutter app for flexible, slot-based task reminders. Instead of relying on one exact alarm time, it helps people stay on top of morning, afternoon, and evening time windows, then adapts reminders based on what they complete, snooze, or ignore.

## What It Does

- Organizes tasks into time windows: morning, afternoon, and evening
- Stores everything locally with SQLite
- Schedules local notifications with snooze support
- Adapts reminder timing and intensity from behavior
- Tracks lightweight analytics like completion rate and most active time
- Supports dark mode, JSON export/import, backup restore, and local settings

## Tech Stack

- Flutter
- Riverpod
- SQLite via `sqflite`
- `flutter_local_notifications`
- Local file storage via `path_provider`

## Project Structure

The app follows a clean, feature-first layout under [`lib/`](/home/frappe/taska/lib):

- `app/`: application shell and bootstrap
- `core/`: shared services such as database, reminders, notifications, analytics, export, theme, and settings
- `features/tasks/`: task domain, data layer, and presentation
- `features/settings/`: release-facing user preferences UI

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

Those permissions are already configured in [`AndroidManifest.xml`](/home/frappe/taska/android/app/src/main/AndroidManifest.xml). Device-level validation is still tracked in [`docs/release_checklist.md`](/home/frappe/taska/docs/release_checklist.md).

## Release Notes

- Android currently builds with debug signing for release configuration to simplify local testing.
- Play Store listing copy and permission messaging are documented in [`docs/play_store_metadata.md`](/home/frappe/taska/docs/play_store_metadata.md).
- The release checklist is documented in [`docs/release_checklist.md`](/home/frappe/taska/docs/release_checklist.md).

## Current Status

Taska is feature-complete for MVP and has passing static analysis and automated tests. The main work still pending before a public release is real-device validation of notification behavior across Android scenarios.
