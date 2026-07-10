# Product Plan: Hourly Time Tracker

## Goal

Build a very simple time tracker that helps Ashray record what happened during every hour of the day, from phone or PC, with minimal friction and a daily category summary.

The app should feel calm, fast, and sticky. It should not become a project-management tool, calendar replacement, or analytics dashboard. The successful version is the one that is easy enough to keep using every day.

## Implementation Status

Phase 1 is implemented and verified on an Android emulator. The local app includes the 24-hour timeline, month-calendar navigation, task/category editing, in-editor custom-category creation, category management, daily report, persistent on-device data, notification permission flow, scheduled hourly prompts, and reminder deep-link payloads. The Android debug APK builds successfully.

Phase 2 is implemented with email/password accounts, offline-first local data, last-write-wins merging, tombstone deletions, background retries, and sync status. The configured Supabase project has the migration and row-level-security policies applied, and all three REST endpoints are reachable.

Phase 3 is complete. The native Windows release builds and runs on the development PC, shares the responsive Android interface, and synchronizes through the same Supabase account.

The version 0.4 reliability milestone adds CSV backup, persistence recovery, expanded sync and UI tests, a native restart smoke test, a manual Android/cross-device checklist, a 60% coverage floor, and Android/Windows GitHub Actions builds.

## Core User Story

Every hour, the app prompts the user to answer one question: "What did I do in the last hour?"

The user records:

1. Time block, such as `12am-1am` or `1pm-2pm`.
2. Task, as short free text.
3. Category, selected from a small reusable list.

At the end of the day, the user can see how many hours were spent in each category, shown as a simple pie chart or list.

## Recommended Product Approach

### Recommendation

Start with a Flutter Android app, then add a Flutter Windows desktop app once the mobile workflow is working well.

This approach fits the requirement that the product should not primarily feel browser-based. It also keeps the codebase simpler than building separate native Android and PC apps.

### Why Not Start With Only a Web App?

A web app would be faster to build and easier to deploy, but it may be less sticky because browser tabs are easy to ignore. Notifications, app-launch behavior, and home-screen presence are usually stronger in a mobile app.

A Progressive Web App could still be considered later, especially if sharing with other users becomes important. For the first personal version, native-feeling Android notifications are more important than broad web availability.

### Sync Strategy

Use Supabase for cross-device sync:

- Authentication: one account across phone and PC.
- Database: hourly entries, categories, and user preferences.
- Offline-friendly local cache: the app should remain usable if the internet is temporarily unavailable.
- Sync behavior: when a device reconnects, entries are uploaded and refreshed from the server.

## MVP Scope

### Must Have

- Android app.
- Simple daily timeline with 24 hourly blocks.
- Add or edit task text for each hour.
- Assign a category to each hour.
- Create, rename, and delete categories.
- Hourly notification prompt on Android.
- Daily summary by category.
- Basic pie chart or category-hours list.
- Cloud sync between Android and PC-ready backend.

### Should Have

- Windows desktop app using the same Flutter codebase.
- Offline entry editing with later sync.
- Yesterday/today navigation.
- Default categories, such as Work, Learning, Health, Sleep, Admin, Leisure, Social, and Other.
- Streak or completion indicator showing how many hourly blocks were filled today.

### Not in MVP

- Team collaboration.
- Invoicing.
- GPS tracking.
- Automatic app or website tracking.
- Complex animations.
- AI categorization.
- Calendar integrations.
- Detailed project management features.

## Screen Plan

### 1. Today Screen

The main screen shows the current date and a vertical list of 24 hour blocks.

Each row contains:

- Hour label.
- Task text preview.
- Category chip.
- Completion state.

Tapping a row opens the edit screen for that hour.

### 2. Edit Hour Screen

The edit screen contains only the essentials:

- Hour label.
- Task text box.
- Category selector.
- Save button.

The save action should be fast and obvious. No extra fields should be added until the simple version is proven useful.

### 3. Report Screen

The report screen shows the selected day and category totals.

The first version can show a list like:

- Sleep: 8 hours.
- Work: 6 hours.
- Learning: 2 hours.

A pie chart can be added after the data model is stable.

### 4. Settings Screen

Settings should stay small:

- Notification schedule.
- Category management.
- Account and sync status.
- Export data.

## Notification Behavior

The Android app should send a notification once per hour asking the user to update the previous hour.

Example: at `2:00pm`, the notification asks, "What did you do from 1pm-2pm?"

The notification should open directly to the edit screen for that hour. This is the primary stickiness feature.

Recommended controls:

- Enable or disable reminders.
- Choose active reminder hours, such as `8am-11pm`.
- Optionally skip reminders during sleep hours.
- If an hour has already been filled, avoid sending a duplicate reminder for that hour.

## Data Model

### Entry

An entry represents one hour of one day.

Fields:

- `id`
- `user_id`
- `date`
- `hour_start`
- `hour_end`
- `task`
- `category_id`
- `created_at`
- `updated_at`
- `sync_status`

### Category

A category is a reusable label for grouping hours.

Fields:

- `id`
- `user_id`
- `name`
- `color`
- `sort_order`
- `created_at`
- `updated_at`

### User Settings

User settings control reminders and display preferences.

Fields:

- `user_id`
- `reminders_enabled`
- `reminder_start_hour`
- `reminder_end_hour`
- `timezone`
- `created_at`
- `updated_at`

## Suggested Technical Stack

### App

- Flutter for Android and Windows.
- Dart for app logic.
- `flutter_local_notifications` for Android reminder notifications.
- `sqflite` or Drift for local storage.
- Supabase Flutter SDK for authentication and cloud sync.
- A simple chart package only after the report data is working.

### Backend

- Supabase Postgres database.
- Supabase Auth for login.
- Row Level Security so each user can only access their own data.

## Build Phases

### Phase 1: Local Android MVP

Build the app without cloud sync first.

Deliverables:

- Today screen.
- Edit hour flow.
- Local categories.
- Daily category totals.
- Local Android hourly notifications.

### Phase 2: Cloud Sync

Add account login and Supabase sync.

Deliverables:

- Sign in.
- Upload local entries.
- Download entries on another device.
- Conflict rule: latest `updated_at` wins.

### Phase 3: PC App

Enable Flutter Windows desktop support.

Deliverables:

- Same timeline and report screens on PC.
- Sync with Android through Supabase.
- Keyboard-friendly editing.

### Phase 4: Polish

Improve the experience without adding complexity.

Deliverables:

- Better empty states.
- Export to CSV.
- Category colors.
- Pie chart.
- Completion streak or daily fill score.

Current status: CSV export, category colors, the donut chart, empty report state, and daily completion score are implemented. The next product-focused improvements should reduce logging friction with range filling and previous-hour copying before adding broader analytics.

## First Implementation Tasks

1. [x] Create a Flutter project.
2. [x] Define the `Entry`, `Category`, and `UserSettings` models.
3. [x] Build a Today screen with 24 hour rows.
4. [x] Add local save and edit behavior.
5. [x] Add category totals and a donut chart for the selected day.
6. [x] Add Android hourly notifications.
7. [x] Add Supabase schema and sync after the local MVP works.
8. [x] Build and validate the native Windows client.
9. [x] Add CSV export for portable backups.
10. [x] Add expanded sync, persistence, account, and UI tests.
11. [x] Add native smoke testing and GitHub Actions for Android and Windows.

## Product Principles

- One hour equals one row.
- Three inputs only: time, task, category.
- Optimize for daily habit formation before analytics.
- Prefer simple text and lists over fancy UI.
- Add features only if they make logging faster or review clearer.
