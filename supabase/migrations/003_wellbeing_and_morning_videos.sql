-- Morning-video preferences and daily wellbeing reflections.

alter table public.user_settings
  add column if not exists morning_videos_enabled boolean not null default false,
  add column if not exists morning_videos_hour smallint not null default 8
    check (morning_videos_hour between 0 and 23);

create table if not exists public.daily_reflections (
  user_id uuid not null references auth.users(id) on delete cascade,
  reflection_date date not null,
  mood smallint not null check (mood between 1 and 5),
  energy smallint not null check (energy between 1 and 5),
  calm smallint not null check (calm between 1 and 5),
  note text not null default '' check (char_length(note) <= 10000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, reflection_date)
);

create index if not exists daily_reflections_user_updated_idx
  on public.daily_reflections (user_id, updated_at);

alter table public.daily_reflections enable row level security;

drop policy if exists "Users manage their own reflections"
  on public.daily_reflections;
create policy "Users manage their own reflections"
  on public.daily_reflections
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Version 2 keeps the v1 snapshot intact for existing consumers and adds the
-- wellbeing data plus morning-video preferences.
create or replace function public.time_tracker_dashboard_snapshot_v2(
  p_start_date date default (current_date - 6),
  p_end_date date default current_date
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_snapshot jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  v_snapshot := public.time_tracker_dashboard_snapshot(
    p_start_date,
    p_end_date
  );

  return v_snapshot || jsonb_build_object(
    'schema_version', 2,
    'daily_reflections', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'date', reflection.reflection_date,
          'mood', reflection.mood,
          'energy', reflection.energy,
          'calm', reflection.calm,
          'note', reflection.note,
          'updated_at', reflection.updated_at
        )
        order by reflection.reflection_date
      )
      from public.daily_reflections as reflection
      where reflection.user_id = v_user_id
        and reflection.reflection_date between p_start_date and p_end_date
    ), '[]'::jsonb),
    'settings', coalesce(v_snapshot -> 'settings', '{}'::jsonb) ||
      coalesce((
        select jsonb_build_object(
          'morning_videos_enabled', settings.morning_videos_enabled,
          'morning_videos_hour', settings.morning_videos_hour
        )
        from public.user_settings as settings
        where settings.user_id = v_user_id
      ), jsonb_build_object(
        'morning_videos_enabled', false,
        'morning_videos_hour', 8
      ))
  );
end;
$function$;

comment on function public.time_tracker_dashboard_snapshot_v2(date, date) is
  'Version 2 dashboard snapshot with daily wellbeing reflections.';

revoke all on function public.time_tracker_dashboard_snapshot_v2(date, date)
  from public;
revoke all on function public.time_tracker_dashboard_snapshot_v2(date, date)
  from anon;
grant execute on function public.time_tracker_dashboard_snapshot_v2(date, date)
  to authenticated;

do $block$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'daily_reflections'
  ) then
    alter publication supabase_realtime add table public.daily_reflections;
  end if;
end;
$block$;

notify pgrst, 'reload schema';
