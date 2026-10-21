# Time Tracker MCP adapter

This package exposes the read-only `time_tracker_dashboard_snapshot_v2` Supabase RPC as MCP tools over stdio, including daily wellbeing reflections.

```powershell
npm ci
npm run check
npm run build
```

The server requires a Supabase user session through environment variables. It must never receive a secret or service-role key. See [`../docs/DASHBOARD_INTEGRATION.md`](../docs/DASHBOARD_INTEGRATION.md) for setup, tool descriptions, dashboard code, authentication guidance, and the realtime refresh pattern.
