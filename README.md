# Time Tracker

A clean hourly time catalog for Android and Windows, built with Flutter. Each day has 24 rows. Every row records only a task and a category, and the report screen turns those entries into a category breakdown.

## Current status

The Android MVP, cloud sync, and native Windows client are complete. Version 0.4 adds automated reliability checks and portable CSV backups.

- Browse any day as 24 one-hour blocks.
- Open a month calendar to jump directly to another day.
- Add, edit, or clear a task and category for an hour.
- Track daily completion out of 24 hours.
- View a daily donut chart and category totals.
- Add, rename, recolor, and delete categories.
- Create a custom category without leaving the hour editor.
- Enable Android prompts for a chosen time window.
- Open the relevant hour directly from a reminder.
- Keep entries and settings on-device between launches.
- Create an email/password account from Settings.
- Merge entries, categories, settings, and deletions across signed-in devices.
- Continue logging offline and retry synchronization in the background.
- Use the same responsive interface in the generated Windows target.
- Export every non-deleted entry to a spreadsheet-ready CSV file.
- Run a native smoke test that covers logging, reporting, restart persistence, and deletion.
- Validate every GitHub change with Android and Windows CI builds.
- Publish a versioned, read-only dashboard snapshot with realtime refresh signals.
- Offer optional MCP tools for snapshots, entries, and summaries.

The Supabase project is configured and its Phase 2 migration has been applied. Open **Settings → Data → Cloud sync** to create an account or sign in.

## Run it on Android

Flutter is installed at `C:\Users\CNC\flutter` on the current development machine. In a new PowerShell window:

```powershell
$env:Path="$env:USERPROFILE\flutter\bin;$env:Path"
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:ANDROID_HOME="$env:LOCALAPPDATA\Android\Sdk"

flutter pub get
flutter devices
flutter run
```

To use the included emulator:

```powershell
flutter emulators --launch Medium_Phone_API_36.1
flutter run -d emulator-5554
```

To build an installable debug APK:

```powershell
flutter build apk --debug
```

The result is `build/app/outputs/flutter-apk/app-debug.apk`. With USB debugging enabled on a phone, install it using:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r `
  "build\app\outputs\flutter-apk\app-debug.apk"
```

When updating an existing installation, open the new APK and choose **Update**. Because the package and signing key are unchanged, Android keeps the app's local entries, categories, and settings.

## Verify the project

```powershell
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart 60
flutter test integration_test -d windows
flutter build apk --debug
flutter build windows --release
```

The automated suite covers hour formatting, persistence recovery, category behavior, CSV escaping, calendar and report interactions, account UI, bidirectional conflict resolution, tombstone deletion, offline retry, edits during synchronization, account linkage, schema errors, and the complete log-report-restart-delete smoke flow. See `docs/SMOKE_TESTS.md` for the Android and cross-device release checklist.

To check the app version from PowerShell:

```powershell
(Select-String -Path pubspec.yaml -Pattern '^version:').Line
```

The current result is `version: 0.4.0+4`—version 0.4.0, Android build 4.

## Reminder behavior

The reminder window describes hours to catalog. With the default `8am–11pm` window, a prompt arrives after each hour in that range. Tapping a notification opens the editor for that exact hour. The app schedules a rolling 14-day window when it opens and cancels the prompt for an hour as soon as that hour is completed.

Android uses inexact idle-safe alarms. This avoids asking for the more sensitive exact-alarm permission while remaining appropriate for hourly check-ins.

## Local data

Entries, categories, and reminder preferences always use Flutter's cross-platform local preferences store, so the UI remains available offline. After sign-in, the app maintains a private Supabase copy and uses the newest `updated_at` value during conflicts. Deleting the app before a successful sync can still delete unsynchronized local data.

## Project map

- `lib/src/models.dart` — entries, categories, settings, and date/hour helpers.
- `lib/src/local_repository.dart` — local JSON persistence.
- `lib/src/app_store.dart` — application state and editing operations.
- `lib/src/account_screen.dart` — account creation, sign-in, and sync status.
- `lib/src/cloud_config.dart` — Supabase client configuration.
- `lib/src/cloud_repository.dart` — authenticated reads, writes, and remote mapping.
- `lib/src/csv_export.dart` — chronological CSV generation and platform export.
- `lib/src/category_editor_dialog.dart` — reusable custom-category editor.
- `lib/src/reminder_service.dart` — Android permission, scheduling, and reminder deep links.
- `lib/src/today_screen.dart` — 24-hour daily catalog.
- `lib/src/edit_hour_screen.dart` — focused task/category editor.
- `lib/src/report_screen.dart` — donut chart and category breakdown.
- `lib/src/settings_screen.dart` — reminder and category controls.
- `docs/PRODUCT_PLAN.md` — product scope and phased roadmap.
- `docs/SUPABASE_PHASE_2.md` — cloud project handoff and integration sequence.
- `docs/SMOKE_TESTS.md` — automated commands and manual release checks.
- `docs/DASHBOARD_INTEGRATION.md` — dashboard API, realtime, and MCP setup.
- `supabase/migrations/001_initial_schema.sql` — Phase 2 tables and ownership policies.
- `supabase/migrations/002_dashboard_integration.sql` — versioned dashboard RPC and realtime publication.
- `mcp-server/` — read-only stdio MCP adapter for AI clients.
- `.github/workflows/flutter.yml` — Android and Windows continuous integration.

## Use Phase 2

Install the version 0.4 APK, then open **Settings → Data → Cloud sync** and create an account. Email confirmation is enabled by default in hosted Supabase projects; after confirming, return to the app and sign in.

## Run it on Windows

The Windows toolchain is installed on the current development PC. Build and launch the optimized desktop app with:

```powershell
flutter build windows --release
& "build\windows\x64\runner\Release\hourly_time_tracker.exe"
```

Keep the executable with the DLLs and data folders beside it. Sign in with the same account used on Android to download the shared history.
