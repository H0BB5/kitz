#!/bin/bash
# Raycast Script Command — capture a Claude artifact from anywhere.
# Copy this into your Raycast script-commands dir (e.g. ~/Documents/RaycastScripts)
# and make it executable. Raycast runs non-interactively, so it passes
# everything via flags + --yes; refine the body afterward in your editor.
#
# @raycast.schemaVersion 1
# @raycast.title New Claude Artifact
# @raycast.mode compact
# @raycast.packageName cz
# @raycast.icon 🔱
# @raycast.argument1 { "type": "text", "placeholder": "name" }
# @raycast.argument2 { "type": "dropdown", "placeholder": "type", "data": [ { "title": "command", "value": "command" }, { "title": "skill", "value": "skill" }, { "title": "plugin", "value": "plugin" } ] }
# @raycast.argument3 { "type": "dropdown", "placeholder": "scope", "data": [ { "title": "user (~/.claude)", "value": "user" }, { "title": "project", "value": "project" }, { "title": "workspace", "value": "workspace" } ] }
# @raycast.argument4 { "type": "text", "placeholder": "description", "optional": true }
#
# @raycast.description Create a Claude command/skill/plugin in a chosen scope.
# @raycast.author dylan
set -euo pipefail

NAME="$1"; TYPE="$2"; SCOPE="$3"; DESC="${4:-}"
# Raycast has no $PWD context, so default project/workspace to your code root.
ROOT="${CZ_RAYCAST_ROOT:-$HOME/Documents}"

# Resolve cz on PATH or fall back to the repo.
CZ="$(command -v cz || echo "$HOME/Projects/cz/bin/cz")"

PATH_OUT="$("$CZ" --type "$TYPE" "$NAME" --scope "$SCOPE" --dir "$ROOT" \
  --description "$DESC" -y -f 2>&1 | sed -n 's/^✓ wrote //p')"

if [ -n "$PATH_OUT" ]; then
  echo "✓ $PATH_OUT"
  # Open in your GUI editor for refinement (adjust to taste).
  [ -n "${EDITOR:-}" ] && command -v "$EDITOR" >/dev/null 2>&1 && open -a "$EDITOR" "$PATH_OUT" 2>/dev/null || true
else
  echo "cz: failed to create artifact"; exit 1
fi
