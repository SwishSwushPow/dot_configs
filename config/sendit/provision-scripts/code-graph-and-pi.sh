#!/bin/bash
# Install after other coding clients that should use this

set -euo pipefail

# install mcp adapter
pi install npm:pi-mcp-adapter

curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
codegraph install -y
codegraph telemetry off

# Registers the CodeGraph MCP server with pi-mcp-adapter, globally for all projects.
#
# Writes to the user-global shared MCP config (~/.config/mcp/mcp.json), which
# pi-mcp-adapter picks up automatically.
#
# Safe to re-run: existing servers and settings are preserved, the "codegraph"
# entry is updated in place, and a timestamped backup is made before writing.

CONFIG_DIR="$HOME/.config/mcp"
CONFIG="$CONFIG_DIR/mcp.json"

die() { echo "error: $*" >&2; exit 1; }

# Pi itself requires Node.js, so node is used for safe JSON merging (no jq needed).
command -v node >/dev/null 2>&1 || die "node not found on PATH (Pi requires Node.js)."

CODEGRAPH_BIN="$(command -v codegraph || true)"
[[ -n "$CODEGRAPH_BIN" ]] || die "codegraph not found on PATH. Install it first:
  npm i -g @colbymchenry/codegraph
  (or: curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh)
then open a new terminal and re-run this script."

mkdir -p "$CONFIG_DIR"

if [[ -f "$CONFIG" ]]; then
  BACKUP="$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG" "$BACKUP"
  echo "Backed up existing config to $BACKUP"
fi

CONFIG="$CONFIG" CODEGRAPH_BIN="$CODEGRAPH_BIN" node <<'EOF'
const fs = require('fs');
const file = process.env.CONFIG;

let cfg = {};
if (fs.existsSync(file)) {
  const raw = fs.readFileSync(file, 'utf8').trim();
  if (raw) {
    try {
      cfg = JSON.parse(raw);
    } catch (e) {
      console.error(`error: ${file} is not valid JSON (${e.message}). Fix or remove it, then re-run.`);
      process.exit(1);
    }
  }
}
if (typeof cfg !== 'object' || cfg === null || Array.isArray(cfg)) {
  console.error(`error: ${file} must contain a JSON object.`);
  process.exit(1);
}

cfg.mcpServers = cfg.mcpServers || {};
cfg.mcpServers.codegraph = {
  ...(cfg.mcpServers.codegraph || {}),   // keep any extra fields you added (e.g. env)
  command: process.env.CODEGRAPH_BIN,    // absolute path: works even if Pi's PATH differs
  args: ['serve', '--mcp'],
  lifecycle: 'keep-alive',               // keeps CodeGraph's file watcher running
  directTools: ['codegraph_explore'],    // show the tool directly, not behind the mcp proxy
};

const tmp = `${file}.tmp`;
fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2) + '\n');
fs.renameSync(tmp, file);                // atomic replace
EOF

echo "CodeGraph registered in $CONFIG (command: $CODEGRAPH_BIN)"
echo
echo "Next steps:"
echo "  1. Index each project once:  cd your-project && codegraph init"
echo "  2. Restart Pi, then run:     /mcp reconnect codegraph"
