# Flippa Claude Code plugins

Internal plugin marketplace for Claude Code.

| Plugin | What it does |
|---|---|
| `superset-mcp` | Connects Claude Code to Superset's MCP server as your own Superset user, signed in through Cloudflare Access. After installing, ask Claude to "set me up with Superset". |

## Install

Most people get these through the Flippa Claude organization and need no GitHub
access. With read access to this repo, you can also install by hand:

```
/plugin marketplace add flippa/claude-plugins
/plugin install superset-mcp@flippa
```

## Adding a plugin

Put it under `plugins/<name>/`, list it in `.claude-plugin/marketplace.json` with a
`./plugins/<name>` source (organization sync rejects bare names), and run
`claude plugin validate .`. Bump `version` in the plugin's `plugin.json` on every
change, or installed copies will not update.
