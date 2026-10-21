-- Explicit least-privilege grants for all user-data tables and dashboard RPCs.
-- RLS remains the per-row authorization boundary for authenticated users.

revoke all on table
  public.time_categories,
  public.hour_entries,
  public.user_settings,
  public.daily_reflections
from public, anon;

grant select, insert, update, delete on table
  public.time_categories,
  public.hour_entries,
  public.user_settings,
  public.daily_reflections
to authenticated;

grant all on table
  public.time_categories,
  public.hour_entries,
  public.user_settings,
  public.daily_reflections
to service_role;

revoke all on function public.time_tracker_dashboard_snapshot(date, date)
  from public, anon;
revoke all on function public.time_tracker_dashboard_snapshot_v2(date, date)
  from public, anon;

grant execute on function public.time_tracker_dashboard_snapshot(date, date)
  to authenticated, service_role;
grant execute on function public.time_tracker_dashboard_snapshot_v2(date, date)
  to authenticated, service_role;

notify pgrst, 'reload schema';
