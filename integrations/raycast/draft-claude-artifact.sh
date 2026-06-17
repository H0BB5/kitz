#!/bin/bash
# Raycast Script Command — describe what you want, Claude drafts the artifact.
# Copy into your Raycast script-commands dir and make executable.
#
# @raycast.schemaVersion 1
# @raycast.title Draft Claude Artifact (AI)
# @raycast.mode fullOutput
# @raycast.packageName cz
# @raycast.icon ✦
# @raycast.argument1 { "type": "text", "placeholder": "name" }
# @raycast.argument2 { "type": "dropdown", "placeholder": "type", "data": [ { "title": "command", "value": "command" }, { "title": "skill", "value": "skill" } ] }
# @raycast.argument3 { "type": "text", "placeholder": "what should it do?" }
# @raycast.argument4 { "type": "dropdown", "placeholder": "scope", "data": [ { "title": "user", "value": "user" }, { "title": "project", "value": "project" }, { "title": "workspace", "value": "workspace" } ] }
#
# @raycast.description Claude ghostwrites a command/skill from a one-line brief.
# @raycast.author dylan
set -euo pipefail

NAME="$1"; TYPE="$2"; INTENT="$3"; SCOPE="$4"
ROOT="${CZ_RAYCAST_ROOT:-$HOME/Documents}"
CZ="$(command -v cz || echo "$HOME/Projects/cz/bin/cz")"

echo "✦ drafting with Claude…"
OUT="$("$CZ" --type "$TYPE" "$NAME" -g -i "$INTENT" --scope "$SCOPE" --dir "$ROOT" -y -f 2>&1)"
PATH_OUT="$(printf '%s\n' "$OUT" | sed -n 's/^✓ wrote //p')"

if [ -n "$PATH_OUT" ]; then
  echo "✓ $PATH_OUT"; echo; sed 's/^/  /' "$PATH_OUT"
  [ -n "${EDITOR:-}" ] && command -v "$EDITOR" >/dev/null 2>&1 && open -a "$EDITOR" "$PATH_OUT" 2>/dev/null || true
else
  echo "$OUT"; exit 1
fi
