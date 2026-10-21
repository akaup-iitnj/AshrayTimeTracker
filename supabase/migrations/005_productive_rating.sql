-- Quick productive/unproductive rating answered from the hourly notification.
-- Null means the hour has not been rated.

alter table public.hour_entries
  add column if not exists productive boolean;
