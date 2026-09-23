#!/usr/bin/env bash
# Connect Claude Code to Flippa's Superset MCP server.
#
#   setup.sh [--staging] [--check]
#
# Default: install cloudflared if missing, sign in to Cloudflare Access (browser),
# verify the server answers as you, and register it with Claude Code.
# --check: diagnose only, change nothing.
set -uo pipefail

ENV=production
MODE=setup
for arg in "$@"; do
  case "$arg" in
    --staging) ENV=staging ;;
    --check) MODE=check ;;
    -h|--help) sed -n 2,9p "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [ "$ENV" = staging ]; then
  HOST=superset-mcp.in.staging.flippa.com
  NAME=superset-staging
  WEB=https://superset.in.staging.flippa.com
else
  HOST=superset-mcp.in.flippa.com
  NAME=superset
  WEB=https://superset.in.flippa.com
fi
APP="https://$HOST"
URL="$APP/mcp"

ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$*"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }

step "1. cloudflared"
CF=$(command -v cloudflared || true)
if [ -z "$CF" ]; then
  if [ "$MODE" = check ]; then
    fail "cloudflared not installed"; exit 1
  fi
  if command -v brew >/dev/null; then
    echo "  installing with Homebrew..."
    brew install cloudflared >/dev/null || { fail "brew install cloudflared failed"; exit 1; }
    CF=$(command -v cloudflared)
  else
    fail "cloudflared not installed and Homebrew not found."
    echo "    Install it from https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/ and re-run."
    exit 1
  fi
fi
ok "$CF ($("$CF" --version 2>/dev/null | awk '{print $3}'))"

step "2. claude CLI"
if ! command -v claude >/dev/null; then
  fail "the claude CLI is not on PATH (needed to register the server)"; exit 1
fi
ok "$(command -v claude)"

step "3. Cloudflare Access sign-in"
if TOKEN=$("$CF" access token -app="$APP" 2>/dev/null) && [ -n "$TOKEN" ] && [[ "$TOKEN" != *"Unable"* ]]; then
  ok "cached token found"
elif [ "$MODE" = check ]; then
  fail "no valid token -- run setup without --check to sign in"; exit 1
else
  echo "  A browser window will open: sign in with your @flippa.com Google account."
  TOKEN=$("$CF" access login --no-verbose --auto-close --app "$APP" 2>/dev/null)
  if [ -z "$TOKEN" ]; then fail "sign-in did not complete"; exit 1; fi
  ok "signed in"
fi

step "4. Verify the server answers as you"
HDR=(-H "cf-access-token: $TOKEN" -H 'content-type: application/json' -H 'accept: application/json, text/event-stream')
BODY='{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_instance_info","arguments":{"request":{}}}}'
RESP=$(curl -s -m 30 -w '\n%{http_code}' "${HDR[@]}" "$URL" -d "$BODY")
CODE=${RESP##*$'\n'}
case "$CODE" in
  200)
    WHO=$(printf '%s' "$RESP" | grep -o '"current_user[^}]*}' | head -1 | sed 's/\\"/"/g')
    EMAIL=$(printf '%s' "$WHO" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
    ROLES=$(printf '%s' "$WHO" | grep -o '"roles":\[[^]]*\]' | cut -d: -f2)
    if [ -n "$EMAIL" ]; then ok "connected as $EMAIL, roles $ROLES"; else ok "server reachable (HTTP 200)"; fi
    ;;
  302|401)
    fail "HTTP $CODE: Cloudflare Access rejected the token. Re-run setup to sign in again."; exit 1 ;;
  403)
    fail "HTTP 403: Access let you in, but Superset refused your identity."
    echo "    Only @flippa.com accounts are accepted. If that is you, ask the platform team to"
    echo "    check the superset-mcp pod log (superset.mcp_service.identity) for the reason."
    exit 1 ;;
  000)
    fail "no response from $HOST (network/VPN/DNS?)"; exit 1 ;;
  *)
    fail "unexpected HTTP $CODE"; printf '%s\n' "${RESP%$'\n'*}" | head -5; exit 1 ;;
esac

step "5. Claude Code registration"
# Production is normally provided by the superset-mcp plugin itself; only
# register by hand when running outside the plugin, or for staging.
if [ "$ENV" = production ] && claude mcp get "plugin:superset-mcp:superset" >/dev/null 2>&1; then
  STATUS=$(claude mcp get "plugin:superset-mcp:superset" 2>&1 | sed -n 's/^ *Status: //p')
  ok "provided by the superset-mcp plugin: $STATUS"
else
  # Absolute cloudflared path: Claude Code may not inherit the shell's PATH
  # (e.g. when started from an IDE), and the helper must find it.
  HELPER="printf '{\"cf-access-token\":\"%s\"}' \"\$($CF access login --no-verbose --auto-close --app $APP)\""
  CONFIG=$(python3 -c 'import json,sys; print(json.dumps({"type":"http","url":sys.argv[1],"headersHelper":sys.argv[2]}))' "$URL" "$HELPER")
  if claude mcp get "$NAME" >/dev/null 2>&1; then
    if [ "$MODE" = check ]; then
      STATUS=$(claude mcp get "$NAME" 2>&1 | sed -n 's/^ *Status: //p')
      ok "registered as '$NAME': $STATUS"
      exit 0
    fi
    claude mcp remove "$NAME" -s user >/dev/null 2>&1 || true
  elif [ "$MODE" = check ]; then
    fail "not registered with Claude Code -- run setup without --check"; exit 1
  fi
  claude mcp add-json --scope user "$NAME" "$CONFIG" >/dev/null || { fail "claude mcp add-json failed"; exit 1; }
  STATUS=$(claude mcp get "$NAME" 2>&1 | sed -n 's/^ *Status: //p')
  ok "registered as '$NAME' (user scope): $STATUS"
fi
[ "$MODE" = check ] && exit 0

step "Done"
echo "  Restart Claude Code (or run /mcp) to load the Superset tools."
echo "  Web UI: $WEB"
