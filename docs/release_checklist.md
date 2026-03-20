# Release Checklist

## Before Shipping

- Run `flutter analyze`
- Run `flutter test`
- Build a release APK or App Bundle
- Validate notifications on a real Android device
- Validate reboot recovery and killed-app recovery on a real Android device
- Review exact alarm behavior on at least one current Android version

## Android Packaging

- Replace debug signing with a real release signing config
- Confirm app name and package metadata
- Review launcher icon and splash presentation
- Verify notification permissions and exact alarm messaging

## Store Readiness

- Finalize Play Store listing copy
- Capture production screenshots
- Confirm permission rationale text
- Add privacy policy or internal privacy statement if needed

## User-Facing Checks

- Confirm export/import works on a physical device
- Confirm dark mode and settings persistence after app restart
- Confirm recurring reminders behave correctly after completion and snooze
