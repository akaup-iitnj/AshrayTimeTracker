# Phase 2: Supabase handoff

The database contract is ready in `supabase/migrations/001_initial_schema.sql`. It creates entries, categories, settings, useful indexes, soft-deletion fields, and row-level-security policies that restrict every row to its signed-in owner.

Status: applied successfully to the configured TimeTracker project on July 10, 2026. All three REST endpoints return HTTP 200 with anonymous access correctly limited to empty results by row-level security.

## One-time project setup

1. Open the existing Supabase project.
2. Open its SQL editor and start a new query.
3. Paste and run `supabase/migrations/001_initial_schema.sql`.
4. Confirm that `time_categories`, `hour_entries`, and `user_settings` appear in the Table Editor.

The Project URL and publishable key are safe to embed in a mobile client. Do not copy or share the secret/service-role key; it bypasses row-level security and must never be included in the app.

## Recommended authentication choice

Use email and password for the first personal version. Supabase enables this provider by default. For the quickest private test, email confirmation can be temporarily disabled in the project's Auth settings. Before wider distribution, confirmation should be enabled and the redirect/deep-link flow configured.

## Implemented app integration

The version 0.4 client includes:

1. `supabase_flutter` initialization with the project's publishable client values.
2. Email/password sign-up, sign-in, sign-out, and account status.
3. First-sign-in upload of existing on-device data without deleting it.
4. Pull-and-merge by `updated_at`, where the newest version wins.
5. Tombstones using `deleted_at`, preventing an older device from reviving deletions.
6. Sync on app start, app resume, sign-in, and after each local edit.
7. Last-sync and retryable-error status in Settings.
8. Automated merge, seed-conflict, deletion, and missing-schema tests.

Local data remains the source available to the UI, so the app continues working offline while synchronization retries in the background.
