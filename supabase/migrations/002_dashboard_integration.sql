-- Read-only dashboard integration contract for Time Tracker.
-- The caller must be signed in with Supabase Auth. The function always scopes
-- data to auth.uid() and runs with the caller's RLS permissions.

create or replace function public.time_tracker_dashboard_snapshot(
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

  if p_start_date is null or p_end_date is null then
    raise exception 'Both start and end dates are required.'
      using errcode = '22023';
  end if;

  if p_start_date > p_end_date then
    raise exception 'Start date must be on or before end date.'
      using errcode = '22023';
  end if;

  if (p_end_date - p_start_date) > 366 then
    raise exception 'Dashboard date ranges cannot exceed 367 days.'
      using errcode = '22023';
  end if;

  with active_categories as (
    select
      category.id,
      category.name,
      category.color_value,
      category.sort_order,
      category.updated_at
    from public.time_categories as category
    where category.user_id = v_user_id
      and category.deleted_at is null
  ),
  active_entries as (
    select
      entry.entry_date,
      entry.hour_start,
      entry.task,
      category.id as category_id,
      coalesce(category.name, 'Uncategorized') as category_name,
      category.color_value as category_color_value,
      entry.updated_at
    from public.hour_entries as entry
    left join active_categories as category
      on category.id = entry.category_id
    where entry.user_id = v_user_id
      and entry.deleted_at is null
      and entry.entry_date between p_start_date and p_end_date
  ),
  date_range as (
    select generated_day::date as entry_date
    from generate_series(
      p_start_date::timestamp,
      p_end_date::timestamp,
      interval '1 day'
    ) as generated_day
  ),
  daily_completion as (
    select
      day.entry_date,
      count(entry.hour_start)::integer as logged_hours,
      round(count(entry.hour_start) * 100.0 / 24, 1) as completion_percent
    from date_range as day
    left join active_entries as entry
      on entry.entry_date = day.entry_date
    group by day.entry_date
  ),
  category_totals as (
    select
      entry.category_id,
      entry.category_name,
      entry.category_color_value,
      count(*)::integer as logged_hours
    from active_entries as entry
    group by
      entry.category_id,
      entry.category_name,
      entry.category_color_value
  ),
  category_summary as (
    select
      total.category_id,
      total.category_name,
      total.category_color_value,
      total.logged_hours,
      round(
        total.logged_hours * 100.0 /
          nullif(sum(total.logged_hours) over (), 0),
        1
      ) as percentage
    from category_totals as total
  )
  select jsonb_build_object(
    'schema_version', 1,
    'source', 'time_tracker',
    'generated_at', current_timestamp,
    'range', jsonb_build_object(
      'start_date', p_start_date,
      'end_date', p_end_date,
      'days', (p_end_date - p_start_date) + 1
    ),
    'entries', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'date', entry.entry_date,
          'hour_start', entry.hour_start,
          'hour_end', (entry.hour_start + 1) % 24,
          'task', entry.task,
          'category_id', entry.category_id,
          'category_name', entry.category_name,
          'category_color_value', entry.category_color_value,
          'updated_at', entry.updated_at
        )
        order by entry.entry_date, entry.hour_start
      )
      from active_entries as entry
    ), '[]'::jsonb),
    'categories', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', category.id,
          'name', category.name,
          'color_value', category.color_value,
          'sort_order', category.sort_order,
          'updated_at', category.updated_at
        )
        order by category.sort_order, category.name
      )
      from active_categories as category
    ), '[]'::jsonb),
    'daily_completion', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'date', daily.entry_date,
          'logged_hours', daily.logged_hours,
          'completion_percent', daily.completion_percent
        )
        order by daily.entry_date
      )
      from daily_completion as daily
    ), '[]'::jsonb),
    'category_summary', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'category_id', summary.category_id,
          'category_name', summary.category_name,
          'category_color_value', summary.category_color_value,
          'logged_hours', summary.logged_hours,
          'percentage', summary.percentage
        )
        order by summary.logged_hours desc, summary.category_name
      )
      from category_summary as summary
    ), '[]'::jsonb),
    'settings', coalesce((
      select jsonb_build_object(
        'reminders_enabled', settings.reminders_enabled,
        'reminder_start_hour', settings.reminder_start_hour,
        'reminder_end_hour', settings.reminder_end_hour,
        'timezone', settings.timezone,
        'updated_at', settings.updated_at
      )
      from public.user_settings as settings
      where settings.user_id = v_user_id
    ), jsonb_build_object(
      'reminders_enabled', false,
      'reminder_start_hour', 8,
      'reminder_end_hour', 23,
      'timezone', 'UTC',
      'updated_at', null
    ))
  ) into v_snapshot;

  return v_snapshot;
end;
$function$;

comment on function public.time_tracker_dashboard_snapshot(date, date) is
  'Version 1 read-only dashboard snapshot scoped to the signed-in user.';

revoke all on function public.time_tracker_dashboard_snapshot(date, date)
  from public;
revoke all on function public.time_tracker_dashboard_snapshot(date, date)
  from anon;
grant execute on function public.time_tracker_dashboard_snapshot(date, date)
  to authenticated;

-- Enable lightweight Postgres Changes notifications. Dashboard clients use the
-- events only as an invalidation signal, then refetch the versioned snapshot.
do $block$
declare
  v_table_name text;
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    foreach v_table_name in array array[
      'hour_entries',
      'time_categories',
      'user_settings'
    ] loop
      if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = v_table_name
      ) then
        execute format(
          'alter publication supabase_realtime add table public.%I',
          v_table_name
        );
      end if;
    end loop;
  end if;
end;
$block$;

notify pgrst, 'reload schema';
