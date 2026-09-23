#!/usr/bin/env bash
# headersHelper for the Superset MCP server: prints the caller's Cloudflare
# Access token as a header. Reuses the cached token; opens a browser only when
# it has expired. Claude Code may not inherit the login shell's PATH, so look
# in the usual install locations too.
APP=${1:-https://superset-mcp.in.flippa.com}
CF=$(PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/usr/bin" command -v cloudflared) || {
  echo "cloudflared not installed: run the superset-mcp skill's setup" >&2
  exit 1
}
TOKEN=$("$CF" access login --no-verbose --auto-close --app "$APP" 2>/dev/null)
[ -n "$TOKEN" ] || { echo "Cloudflare Access sign-in did not complete" >&2; exit 1; }
printf '{"cf-access-token":"%s"}' "$TOKEN"
