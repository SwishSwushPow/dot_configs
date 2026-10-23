#!/bin/bash
# sendit-mount: /Users/bjoern/.secrets/claude:/home/dev/.secrets/claude

# json_merge FILE JSON
#
# Deep-merges the JSON object JSON into the JSON object stored in FILE.
#   - Missing or empty FILE: it is created (mode 600) with JSON as its contents.
#   - Existing FILE: a timestamped backup is made, then the merge is written
#     atomically via a temp file that keeps the original's permissions.
#
# Examples:
#   json_merge "$HOME/.claude.json" '{"hasCompletedOnboarding": true}'
#   json_merge config.json '{"server": {"port": 8080}}'
#   json_merge config.json "$(cat patch.json)"
#
# Can be sourced (to use the function) or run directly as a script.
json_merge() {
    if [ $# -ne 2 ]; then
        echo "Usage: json_merge FILE JSON" >&2
        return 2
    fi
 
    local file=$1 patch=$2 backup tmp
 
    command -v jq >/dev/null 2>&1 || { echo "Error: jq is required." >&2; return 1; }
 
    # The contents to insert must themselves be a JSON object.
    if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$patch"; then
        echo "Error: contents must be a valid JSON object: $patch" >&2
        return 1
    fi
 
    # Missing or empty file: just create it.
    if [ ! -s "$file" ]; then
        mkdir -p "$(dirname "$file")" || return 1
        jq -n --argjson p "$patch" '$p' > "$file" || return 1
        chmod 600 "$file"
        echo "Created $file"
        return 0
    fi
 
    if ! jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
        echo "Error: $file is not a JSON object; leaving it unchanged." >&2
        return 1
    fi
 
    # Back up the original before changing anything.
    backup="$file.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "$file" "$backup" || return 1
 
    # Temp file in the same directory with the original's permissions,
    # so the final mv is atomic and keeps the file's mode.
    tmp=$(mktemp "$file.tmp.XXXXXX") || return 1
    if ! { cp -p "$file" "$tmp" && jq --argjson p "$patch" '. * $p' "$file" > "$tmp"; }; then
        rm -f "$tmp"
        echo "Error: failed to update $file; original unchanged (backup: $backup)" >&2
        return 1
    fi
 
    mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
    echo "Merged into $file (backup: $backup)"
}

# Claude token for GiGa account
LINE='[ -r /home/dev/.secrets/claude/token ] && export CLAUDE_CODE_OAUTH_TOKEN="$(cat /home/dev/.secrets/claude/token)"'
FILE="$HOME/.profile"
touch "$FILE"
grep -qxF "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

# We need to skip Claude onboarding if we set the token
json_merge "$HOME/.claude.json" '{"hasCompletedOnboarding": true}'

# proj needs the binary?
sudo apt-get -y install --no-install-recommends \
sqlite3

# we need all these?
sudo apt-get -y install --no-install-recommends \
libglib2.0-dev libgtk-3-dev capnproto libwebkit2gtk-4.1-dev
