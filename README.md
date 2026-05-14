# Taska

Taska is an offline-first Flutter app focused on flexible reminders, task tracking, and shopping-list support.

The app is built around daily time windows (morning, afternoon, evening, night) instead of one fragile alarm timestamp. It keeps data local, adapts reminder behavior from user actions, and adds motivation through rewards and streak tracking.

## Current App Scope

The current codebase includes:

- Slot-based task planning (morning, afternoon, evening, night)
- Task snooze/unsnooze flows with date selection support
- Behavior-aware reminder scheduling and priority escalation options
- Local notifications and boot-time notification rescheduling on Android
- Reward engine with stats, streaks, and achievements
- Shopping lists (create/open/delete list sessions, list item workflows)
- Theme mode persistence (light/dark)
- Settings for currency, default snooze duration, reminder intensity, notification preference, and slot window definitions
- Local export/import and restore actions for task data

## Tech Stack

- Flutter
- Dart (SDK constraint: `^3.10.8`)
- Riverpod (`flutter_riverpod`)
- SQLite (`sqflite`)
- Local notifications (`flutter_local_notifications` + `timezone`)
- Local file and sharing support (`path_provider`, `file_picker`, `share_plus`)

## Project Structure

Main source layout under [lib/](lib/):

- `app/`: app shell and navigation scaffold
- `core/`: shared infrastructure
	- `analytics/`, `database/`, `notifications/`, `reminders/`, `rewards/`, `scheduling/`, `settings/`, `shopping/`, `theme/`, `export/`
- `features/tasks/`: task data, domain, and UI
- `features/shopping/`: shopping list data, domain, and UI
- `features/settings/`: settings UI

Release support docs:

- [docs/release_notes.md](docs/release_notes.md)
- [docs/play_store_metadata.md](docs/play_store_metadata.md)
- [docs/release_checklist.md](docs/release_checklist.md)

## Versioning

- App version in [pubspec.yaml](pubspec.yaml): `3.3.0+1`
- Current documented release line: 3.3
- Release name: Roaming Roaster
- Release tag: seasoned
- Release comparison notes are tracked in [docs/release_notes.md](docs/release_notes.md)

## Getting Started

### Prerequisites

- Flutter SDK compatible with Dart `^3.10.8`
- Android Studio or Android SDK CLI tools for Android builds
- Xcode for iOS/macOS builds (when building on macOS)

### Install Dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Quality Checks

```bash
flutter analyze
flutter test
```

## Android Notifications and Permissions

Android manifest permissions configured in [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml):

- `android.permission.POST_NOTIFICATIONS`
- `android.permission.SCHEDULE_EXACT_ALARM`
- `android.permission.USE_EXACT_ALARM`
- `android.permission.RECEIVE_BOOT_COMPLETED`
- `android.permission.VIBRATE`

The manifest also registers notification receivers from `flutter_local_notifications`, including boot/package-replaced handling for scheduled reminders.

Clock runtime reliability notes:

- Clock alarms and timer state are persisted locally to survive process death.
- Android exact alarm scheduling is requested/checked at runtime before scheduling.
- When clock alarms/timers are active on Android, Taska starts a foreground runtime service to reduce background kill interruptions.

## Build Notes

- Android `release` currently uses debug signing in [android/app/build.gradle.kts](android/app/build.gradle.kts) for local release-mode testing.
- Java/Kotlin target is configured to 17 in [android/app/build.gradle.kts](android/app/build.gradle.kts).

## Privacy and Data

- Core usage is local-first and account-free.
- Task and related data are persisted on device (SQLite).

## Release Tracking

For release details and readiness tracking, use:

- [docs/release_notes.md](docs/release_notes.md)
- [docs/play_store_metadata.md](docs/play_store_metadata.md)
- [docs/release_checklist.md](docs/release_checklist.md)
