-- Phase 2 cloud schema for Time Tracker.
-- Run this in a new Supabase project's SQL editor or with the Supabase CLI.

create table if not exists public.time_categories (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  name text not null check (char_length(name) between 1 and 80),
  color_value bigint not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);

create table if not exists public.hour_entries (
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  hour_start smallint not null check (hour_start between 0 and 23),
  task text not null default '' check (char_length(task) <= 1000),
  category_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, entry_date, hour_start),
  foreign key (user_id, category_id)
    references public.time_categories(user_id, id)
    deferrable initially deferred
);

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reminders_enabled boolean not null default false,
  reminder_start_hour smallint not null default 8
    check (reminder_start_hour between 0 and 23),
  reminder_end_hour smallint not null default 23
    check (reminder_end_hour between 1 and 24),
  timezone text not null default 'UTC',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (reminder_start_hour < reminder_end_hour)
);

create index if not exists hour_entries_user_date_idx
  on public.hour_entries (user_id, entry_date);

create index if not exists hour_entries_user_updated_idx
  on public.hour_entries (user_id, updated_at);

create index if not exists time_categories_user_updated_idx
  on public.time_categories (user_id, updated_at);

alter table public.time_categories enable row level security;
alter table public.hour_entries enable row level security;
alter table public.user_settings enable row level security;

drop policy if exists "Users manage their own categories"
  on public.time_categories;
create policy "Users manage their own categories"
  on public.time_categories
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users manage their own entries"
  on public.hour_entries;
create policy "Users manage their own entries"
  on public.hour_entries
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users manage their own settings"
  on public.user_settings;
create policy "Users manage their own settings"
  on public.user_settings
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
