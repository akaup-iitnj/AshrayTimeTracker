# Dashboard and MCP integration

## Outcome

Time Tracker publishes versioned, read-only dashboard snapshots through Supabase. Any future dashboard can sign in as the same user, fetch the current v2 snapshot, and subscribe to change notifications. An optional local MCP server wraps that identical contract for AI clients.

```text
Android / Windows Time Tracker
            |
            | existing offline-first sync
            v
Supabase tables protected by RLS
            |
            +--> time_tracker_dashboard_snapshot_v2 RPC --> Dashboard app
            |                                         (same user session)
            |
            +--> Postgres Changes --> refetch snapshot automatically
            |
            +--> Local stdio MCP adapter --> AI tools
```

Supabase remains the source of truth. The dashboard and MCP server do not maintain a second database.

## Security model

- The dashboard uses the existing publishable key and signs in through Supabase Auth.
- The RPC runs as `security invoker`, checks `auth.uid()`, and returns only that user's rows.
- Anonymous execution is revoked; only the `authenticated` role can call it.
- The MCP adapter uses a signed-in user's access token and optional refresh token.
- Never place the Supabase secret or service-role key in a dashboard, desktop app, MCP configuration, or repository. It bypasses RLS.
- The integration is read-only. It exposes no MCP mutation tools.

## Version 2 snapshot

Call:

```ts
const { data, error } = await supabase.rpc(
  'time_tracker_dashboard_snapshot_v2',
  {
    p_start_date: '2026-07-01',
    p_end_date: '2026-07-31',
  },
)
```

The inclusive range can cover at most 367 days. The response contains:

- `schema_version`: currently `2`.
- `source`: `time_tracker`.
- `generated_at`: server timestamp.
- `range`: requested dates and number of days.
- `entries`: active hourly entries, resolved category information, and update timestamps.
- `categories`: active categories in display order.
- `daily_completion`: all requested days, including zero-hour days.
- `category_summary`: hours and percentage by category.
- `settings`: hourly reminder window, morning-video preference, and timezone.
- `daily_reflections`: mood, energy, calm, reflection text, and update time.

Version 1 remains available for compatibility but does not include wellbeing data or morning-video settings.

Deleted entries and categories are not exposed. Tasks whose category was deleted remain visible as `Uncategorized`.

## Dashboard authentication

Use the same account as the Time Tracker app:

```ts
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
)

await supabase.auth.signInWithPassword({
  email,
  password,
})
```

After authentication, every RPC and realtime subscription carries the user's JWT automatically.

## Automatic dashboard refresh

Migrations `002_dashboard_integration.sql` and `003_wellbeing_and_morning_videos.sql` add the four source tables to the `supabase_realtime` publication. Treat realtime events as an invalidation signal and refetch the snapshot:

```ts
async function refreshTimeTracker() {
  const { data, error } = await supabase.rpc(
    'time_tracker_dashboard_snapshot_v2',
    {
      p_start_date: rangeStart,
      p_end_date: rangeEnd,
    },
  )
  if (error) throw error
  setTimeTrackerSnapshot(data)
}

const { data: { user } } = await supabase.auth.getUser()
if (!user) throw new Error('Sign in before subscribing')

const channel = supabase
  .channel('time-tracker-dashboard')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'hour_entries',
      filter: `user_id=eq.${user.id}`,
    },
    refreshTimeTracker,
  )
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'time_categories',
      filter: `user_id=eq.${user.id}`,
    },
    refreshTimeTracker,
  )
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'user_settings',
      filter: `user_id=eq.${user.id}`,
    },
    refreshTimeTracker,
  )
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'daily_reflections',
      filter: `user_id=eq.${user.id}`,
    },
    refreshTimeTracker,
  )
  .subscribe()

// During dashboard teardown:
await supabase.removeChannel(channel)
```

This means an entry synced by the phone or PC can appear in the dashboard without a page refresh.

## Local MCP server

The MCP package lives in `mcp-server/` and exposes three read-only tools:

- `time_tracker.get_snapshot`
- `time_tracker.get_entries`
- `time_tracker.get_summary`

Build it:

```powershell
cd mcp-server
npm ci
npm run check
npm run build
```

Example stdio client configuration:

```json
{
  "mcpServers": {
    "time-tracker": {
      "command": "node",
      "args": [
        "C:/absolute/path/to/Time Tracker/mcp-server/build/src/index.js"
      ],
      "env": {
        "SUPABASE_URL": "https://your-project.supabase.co",
        "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_your_key",
        "TIME_TRACKER_ACCESS_TOKEN": "a-current-user-access-token",
        "TIME_TRACKER_REFRESH_TOKEN": "the-matching-refresh-token"
      }
    }
  }
}
```

Access and refresh tokens are sensitive. Keep them in the MCP client's encrypted/local configuration, never in source control or screenshots. If only an access token is supplied, restart the server with a current token after it expires.

## Why the dashboard should call Supabase directly

MCP tools are model-controlled integration points. A normal dashboard is simpler and more reliable when it calls the authenticated RPC directly. Both paths use the same versioned JSON contract, so the MCP adapter adds AI access without coupling the dashboard UI to MCP.

If this later becomes a hosted MCP service for multiple clients, add Streamable HTTP and standards-based OAuth. The initial stdio adapter deliberately avoids inventing a custom long-lived token system.

## Compatibility policy

- Additive fields can be introduced without changing `schema_version`.
- Renaming or removing fields requires a new RPC and a new schema version.
- Dashboard clients should reject unsupported versions instead of silently misreading data.
- The MCP adapter validates version `2` before returning tool results.
