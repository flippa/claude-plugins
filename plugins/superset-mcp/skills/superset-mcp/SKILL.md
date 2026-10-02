---
name: superset-mcp
description: Connect Claude Code to Flippa's Superset MCP server (superset-mcp.in.flippa.com) and fix it when it breaks. Use when someone wants to set up, install, connect to or "add" Superset/the Superset MCP, query Superset dashboards, charts or datasets from Claude, or when Superset MCP tools are missing, fail to connect, or return 401/403 -- even if they just say "set me up with Superset" or "the superset tools aren't working".
---

# Superset MCP setup

Flippa's Superset exposes an MCP server. Tools run **as the user's own Superset
account**, identified by their Cloudflare Access (Google @flippa.com) sign-in. There
is no shared password or API key to hand out, and nothing to install.

## Set up

This skill ships in the `superset-mcp` plugin, which **already registers the
production server** (`plugin:superset-mcp:superset`). Sign-in is standard MCP OAuth,
served by Cloudflare Access. Tell the user to:

1. Run `/mcp`, select **superset** (`plugin:superset-mcp:superset`), choose **Authenticate**.
2. Complete the Google @flippa.com sign-in in the browser that opens. It ends on a
   localhost page confirming success.

Then call `get_instance_info` and report who the server thinks they are, and their
roles. Claude Code refreshes the token in the background; a new browser sign-in is
needed about every two weeks.

Staging, or outside the plugin:

```sh
claude mcp add --transport http -s user superset-staging https://superset-mcp.in.staging.flippa.com/mcp
claude mcp add --transport http -s user superset https://superset-mcp.in.flippa.com/mcp
```

then `/mcp` → Authenticate as above.

## Troubleshoot

`claude mcp get <name>` shows "Needs authentication" until the user authenticates
from the interactive `/mcp` menu; the CLI cannot start the sign-in.

| Symptom | Meaning | Fix |
|---|---|---|
| "Needs authentication", or HTTP 401 | no token, or the ~2-week grant expired | `/mcp` → superset → Authenticate |
| Sign-in page denies them | not in the "Flippa Employees" Access group | platform team |
| HTTP 403 | Access admitted them, Superset refused the identity (non-@flippa.com account) | platform team checks the `superset-mcp` pod log, `superset.mcp_service.identity` |
| Tool call returns an `Error ID: err_...` | arguments not wrapped | tools take `{"request": {...}}`; see below |
| Listings come back empty | their role cannot see that content | see Access below |

To check the server side is up without signing in, an unauthenticated request should
get a 401 pointing at OAuth metadata:

```sh
curl -s -o /dev/null -D - -X POST https://superset-mcp.in.flippa.com/mcp | grep -i -E '^HTTP|www-authenticate'
```

## Access

The first sign-in creates the user's Superset account with the **Analyst** role: SQL
Lab, charts and datasets on the `iceberg` and `trino` databases. Anything more (other
databases, admin) is granted by a Superset admin. It is not something this skill can
change.

## Using the tools

- Wrap tool arguments in `request`: `get_dataset_info(request={"identifier": 12})`.
- Start with `get_instance_info` to see the user's identity and roles.
- Put business logic (e.g. "live listings") in a **saved dataset metric**, not in chart
  filters. `get_chart_data` on an MCP-created chart ignores its filters and returns the
  unfiltered number while reporting success.
- MCP can create datasets and charts but cannot edit dataset metrics or column
  descriptions. That curation happens in the Superset UI.
