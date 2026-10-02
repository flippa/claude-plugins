---
name: metabase-mcp
description: Connect Claude Code to Flippa's Metabase MCP server (metabase.in.flippa.com) and fix it when it breaks. Use when someone wants to set up, install, connect to or "add" Metabase/the Metabase MCP, query Metabase questions, dashboards, tables or run SQL through Metabase from Claude, or when Metabase MCP tools are missing, fail to connect, time out or return 401/403 -- even if they just say "set me up with Metabase" or "the metabase tools aren't working".
---

# Metabase MCP setup

Flippa's Metabase has a built-in MCP server. Tools run **as the user's own Metabase
account** with their normal Metabase permissions. There is no shared password or API
key, and nothing to install.

## Set up

This skill ships in the `metabase-mcp` plugin, which **already registers the
production server** (`plugin:metabase-mcp:metabase`). Tell the user to:

1. Run `/mcp`, select **metabase** (`plugin:metabase-mcp:metabase`), choose **Authenticate**.
2. In the browser that opens: pass Cloudflare Access (Google @flippa.com), sign in to
   Metabase if asked, then **approve** the connection on Metabase's consent page. It
   ends on a localhost page confirming success.

Then call `search` (e.g. `term_queries: ["listings"]`) to confirm it works.

Staging, or outside the plugin:

```sh
claude mcp add --transport http -s user metabase-staging https://metabase.in.staging.flippa.com/api/metabase-mcp
claude mcp add --transport http -s user metabase https://metabase.in.flippa.com/api/metabase-mcp
```

then `/mcp` → Authenticate as above.

## Troubleshoot

`claude mcp get <name>` shows "Needs authentication" until the user authenticates
from the interactive `/mcp` menu; the CLI cannot start the sign-in.

| Symptom | Meaning | Fix |
|---|---|---|
| "Needs authentication", or HTTP 401 | no token, or it expired | `/mcp` → metabase → Authenticate |
| Browser stops at a Cloudflare page | not in the Access group for Metabase | platform team |
| Tool call "timed out" on a big query | Claude Code gives up after ~60s; Metabase keeps running it | narrow the query (filters, `LIMIT`, a date range) |
| Permission error, or a database is missing | their Metabase groups do not cover it | a Metabase admin grants access |

## Using the tools

- `search` finds tables, questions, dashboards and metrics; results include each
  table's `database_id`.
- Prefer `construct_query` / `query` over `execute_sql`; raw SQL needs native-query
  permission on that database.
- Results are capped at 2,000 rows (200 per page).
- The **Trino** database reads the CDC mirror of production, with quoted nested
  schemas: `iceberg."core.flippa".listings`.
- `create_question`, `create_dashboard` and the `update_*` tools write to Metabase as
  the user. Confirm with the user before creating or changing anything.
