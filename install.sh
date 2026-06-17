#!/usr/bin/env sh
# Install cz + its three muscle-memory aliases (cmdz/sklz/plgz) into PATH.
# Idempotent: re-run any time. Uninstall: pass --uninstall.
set -eu

SRC="$(cd "$(dirname "$0")" && pwd)/bin/cz"
NAMES="cz cmdz sklz plgz"

# Pick a bin dir already on PATH, preferring a user-writable one.
pick_bindir() {
  for d in "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin; do
    case ":$PATH:" in *":$d:"*) [ -w "$d" ] || mkdir -p "$d" 2>/dev/null || true
      if [ -w "$d" ]; then printf '%s' "$d"; return 0; fi ;;
    esac
  done
  mkdir -p "$HOME/.local/bin"; printf '%s' "$HOME/.local/bin"
}

uninstall() {
  bindir="$(pick_bindir)"
  for n in $NAMES; do rm -f "$bindir/$n" && printf 'removed %s/%s\n' "$bindir" "$n"; done
  exit 0
}

[ "${1:-}" = "--uninstall" ] && uninstall

[ -f "$SRC" ] || { printf 'install: cannot find %s\n' "$SRC" >&2; exit 1; }
chmod +x "$SRC"

BINDIR="$(pick_bindir)"
for n in $NAMES; do
  ln -sf "$SRC" "$BINDIR/$n"
  printf '✓ linked %s -> %s\n' "$BINDIR/$n" "$SRC"
done

# Dependency check
printf '\nDependencies:\n'
if command -v fzf >/dev/null 2>&1; then printf '  ✓ fzf\n'; else printf '  ✗ fzf (REQUIRED for interactive use): brew install fzf\n'; fi
if command -v bat >/dev/null 2>&1; then printf '  ✓ bat (preview)\n'; else printf '  · bat (optional, nicer preview): brew install bat\n'; fi
ed="${VISUAL:-${EDITOR:-}}"
# shellcheck disable=SC2016  # $EDITOR here is literal display text
if [ -n "$ed" ]; then printf '  ✓ editor: %s\n' "$ed"; else printf '  · $EDITOR unset (falls back to vi)\n'; fi

# $PATH below is intentionally literal — it's shell-rc text for the user to paste.
# shellcheck disable=SC2016
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) printf '\n⚠ %s is not on PATH. Add to your shell rc:\n    export PATH="%s:$PATH"\n' "$BINDIR" "$BINDIR" ;;
esac

printf '\nDone. Try:  cmdz --help   |   cmdz my-first-command\n'
