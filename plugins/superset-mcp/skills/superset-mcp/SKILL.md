---
name: superset-mcp
description: Connect Claude Code to Flippa's Superset MCP server (superset-mcp.in.flippa.com) and fix it when it breaks. Use when someone wants to set up, install, connect to or "add" Superset/the Superset MCP, query Superset dashboards, charts or datasets from Claude, or when Superset MCP tools are missing, fail to connect, or return 401/403 -- even if they just say "set me up with Superset" or "the superset tools aren't working".
---

# Superset MCP setup

Flippa's Superset exposes an MCP server. Tools run **as the user's own Superset
account**, identified by their Cloudflare Access (Google @flippa.com) sign-in. There
is no shared password or API key to hand out.

## Set up

This skill ships in the `superset-mcp` plugin, which **already registers the
production server** (`plugin:superset-mcp:superset`). What a new user is missing is
`cloudflared` and an Access sign-in. Run the bundled script from this skill's
directory. It is idempotent, so it is safe to re-run:

```sh
bash <this skill's directory>/scripts/setup.sh            # production
bash <this skill's directory>/scripts/setup.sh --staging  # staging, registered as "superset-staging"
```

It prints ✔/✘ for each of five steps:

1. Installs `cloudflared` with Homebrew if missing.
2. Checks the `claude` CLI is on PATH.
3. Signs in to Cloudflare Access. **This opens a browser.** Tell the user to
   complete the Google sign-in there before you run it, because the script waits for it.
4. Calls `get_instance_info` and prints who the server thinks they are, and their roles.
5. Confirms the plugin's server is connected. Outside the plugin, or for staging,
   it registers the server at user scope instead.

Then tell the user to **run `/mcp` and reconnect `superset`, or restart Claude
Code**. The first connection before sign-in fails, and Claude Code does not retry
it on its own.

## Troubleshoot

Run `setup.sh --check` first. It diagnoses without changing anything. What the
failures mean:

| Symptom | Meaning | Fix |
|---|---|---|
| ✘ no valid token / HTTP 401/302, or `/mcp` shows "Unexpected content type: text/html" | no Access session (Access served its login page) | re-run `setup.sh` |
| HTTP 403 | Access admitted them, Superset refused the identity (non-@flippa.com account) | platform team checks the `superset-mcp` pod log, `superset.mcp_service.identity` |
| `/mcp` shows the server failed right after the token expired | the helper opened a browser, but Claude Code gives helpers only 10s | finish the sign-in, then `/mcp` → reconnect |
| Tool call returns an `Error ID: err_...` | arguments not wrapped | tools take `{"request": {...}}`; see below |
| Listings come back empty | their role cannot see that content | see Access below |

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

## Scope

Claude Code only. Claude Desktop and claude.ai cannot run the token helper, so this
setup does not apply to them.
