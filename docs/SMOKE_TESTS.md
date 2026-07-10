# Release Smoke Tests

Run this checklist before distributing a new Android APK or Windows build. Use a clearly labeled test date so the checks do not disturb real history.

## Automated checks

```powershell
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart 60
flutter test integration_test -d windows
flutter build apk --debug
flutter build windows --release
```

## Android installation and persistence

- Install the APK on a clean device and confirm the app opens to the current day.
- Log one hour, close the app from the recent-apps screen, reopen it, and confirm the entry remains.
- Install the next APK over the existing version and confirm entries, categories, reminder settings, and sign-in state remain.
- Create, rename, recolor, and delete a test category. Confirm deleting a used category keeps its task text as uncategorized.
- Export CSV and open the result in a spreadsheet app. Confirm quotes, commas, and multiline tasks stay in one cell.

## Reminders

- Enable prompts and approve Android's notification permission.
- Set a short test window around the current hour and confirm a prompt arrives after the hour ends.
- Tap the prompt and confirm it opens the exact previous-hour editor.
- Fill that hour before its reminder and confirm the pending prompt is cancelled.
- Restart the phone and confirm future scheduled prompts still arrive.
- Change the device timezone, reopen the app, and confirm newly scheduled prompts use local time.

## Offline and cloud sync

- Sign in on both Android and Windows with the same account.
- Enable airplane mode on Android, log a test hour, close and reopen the app, and confirm the local entry remains.
- Disable airplane mode and use **Sync now**. Confirm the entry appears on Windows.
- Edit the same test hour on Windows, sync, then confirm the newer edit appears on Android.
- Delete a test hour on one device and confirm it is not revived by the other device.
- Change a category and reminder window on one device and confirm both changes reach the other device.
- Confirm a failed sync shows an error without blocking local logging, then confirm **Sync now** clears it after connectivity returns.

## Windows

- Launch the release executable from its complete Release folder.
- Sign in and confirm Android history appears.
- Create, edit, and clear an hour using mouse and keyboard.
- Open the calendar and reports at narrow and wide window sizes.
- Export CSV, choose a destination in the Windows save dialog, and open the file in Excel or another spreadsheet tool.

## Release evidence

Record the version, Android device/OS, Windows version, test date, and any failed step in the GitHub pull request before merging.
