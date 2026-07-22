#!/usr/bin/env sh
# Pure-shell test harness for kitz. No TTY, no external framework.
# Unit tests source kitz (KITZ_SOURCED=1) in subshells; integration tests run the
# real script non-interactively against a sandbox dir.
# shellcheck disable=SC2016  # tests deliberately assert on literal $1/$ARGUMENTS
# shellcheck disable=SC1090  # kitz is sourced dynamically via $KITZ
# shellcheck disable=SC2034  # KITZ_SOURCED is consumed by kitz's sourcing guard
HERE="$(cd "$(dirname "$0")" && pwd)"
KITZ="$HERE/../bin/kitz"
SB="$(mktemp -d)"
PASS=0; FAIL=0

trap 'rm -rf "$SB"' EXIT

pass() { PASS=$((PASS+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n    %s\n' "$1" "${2:-}"; }

# run a kitz function in an isolated subshell after sourcing the lib
call() { ( KITZ_SOURCED=1; . "$KITZ"; "$@" ); }

assert_eq()  { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "exp=[$2] got=[$3]"; fi; }
assert_has() { if printf '%s' "$2" | grep -qF -- "$3"; then pass "$1"; else fail "$1" "missing [$3] in: $2"; fi; }
assert_no()  { if printf '%s' "$2" | grep -qF -- "$3"; then fail "$1" "unexpected [$3]"; else pass "$1"; fi; }
assert_file(){ if [ -f "$2" ]; then pass "$1"; else fail "$1" "no file: $2"; fi; }
assert_code(){ if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "exp rc=$2 got=$3"; fi; }

echo "── unit: slugify ──────────────────────────"
assert_eq "spaces->dash"      "my-cool-command" "$(call slugify 'My Cool Command')"
assert_eq "keeps slash"       "git/sync-repo"   "$(call slugify 'git/Sync Repo')"
assert_eq "trim + collapse"   "trailing"        "$(call slugify '  Trailing-- ')"
assert_eq "underscores"       "foo-bar"         "$(call slugify 'Foo___Bar')"
assert_eq "strip leading /"   "a/b"             "$(call slugify '/a/b')"

echo "── unit: titlecase ────────────────────────"
assert_eq "title from slug"   "Git Sync Repo"   "$(call titlecase 'git/sync-repo')"

echo "── unit: resolve_scope ────────────────────"
mkdir -p "$SB/ws/app/src"
: > "$SB/ws/pnpm-workspace.yaml"
mkdir -p "$SB/ws/app/.git"
FROM="$SB/ws/app/src"
assert_eq "project=nearest .git" "$SB/ws/app" "$(call resolve_scope project "$FROM")"
assert_eq "workspace=pnpm root"  "$SB/ws"     "$(call resolve_scope workspace "$FROM")"
assert_eq "here=cwd"             "$FROM"      "$(call resolve_scope here "$FROM")"
assert_eq "user=HOME"            "$HOME"      "$(call resolve_scope user "$FROM")"
# project must NOT jump to $HOME just because ~/.claude exists (real bug, found via --doctor)
mkdir -p "$SB/fakehome/.claude" "$SB/fakehome/proj/sub"
assert_eq "project ignores home .claude" "$SB/fakehome/proj/sub" \
  "$(HOME="$SB/fakehome" call resolve_scope project "$SB/fakehome/proj/sub")"
# the $HOME guard must compare by inode, not string: a same-dir path that differs
# only as text (trailing slash here; case on a case-insensitive FS in the wild)
# must still be recognised as $HOME. (Regression: cwd /users vs $HOME /Users.)
mkdir -p "$SB/fh2/proj/sub"; : > "$SB/fh2/package.json"
assert_eq "project guard is inode-based, not string" "$SB/fh2/proj/sub" \
  "$(HOME="$SB/fh2/" call resolve_scope project "$SB/fh2/proj/sub")"

echo "── unit: target_path ──────────────────────"
assert_eq "cmd path"    "/b/.claude/commands/x.md"            "$(call target_path command /b x)"
assert_eq "skill path"  "/b/.claude/skills/x/SKILL.md"        "$(call target_path skill /b x)"
assert_eq "plugin path" "/b/.claude/plugins/x/.claude-plugin/plugin.json" "$(call target_path plugin /b x)"

echo "── unit: remove_target ────────────────────"
assert_eq "cmd = the file"   "/b/.claude/commands/x.md" "$(call remove_target command /b/.claude/commands/x.md)"
assert_eq "skill = its dir"  "/b/.claude/skills/x"      "$(call remove_target skill /b/.claude/skills/x/SKILL.md)"
assert_eq "plugin = its dir" "/b/.claude/plugins/x"     "$(call remove_target plugin /b/.claude/plugins/x/.claude-plugin/plugin.json)"

echo "── unit: _ver_ge (fzf capability gate) ──"
assert_code "0.74.0 >= 30"   "0" "$(call _ver_ge 0.74.0 30; echo $?)"
assert_code "0.30.0 >= 30"   "0" "$(call _ver_ge 0.30.0 30; echo $?)"
assert_code "1.0.0 >= 30"    "0" "$(call _ver_ge 1.0.0 30; echo $?)"
assert_code "0.29.9 < 30"    "1" "$(call _ver_ge 0.29.9 30; echo $?)"
assert_code "0.35.0 < 36"    "1" "$(call _ver_ge 0.35.0 36; echo $?)"
assert_code "0.36.0 >= 36"   "0" "$(call _ver_ge 0.36.0 36; echo $?)"
assert_code "empty -> no"    "1" "$(call _ver_ge '' 30; echo $?)"
assert_code "garbage -> no"  "1" "$(call _ver_ge 'x.y' 30; echo $?)"

echo "── unit: scan_type / list_all ─────────────"
mkdir -p "$SB/all/.claude/commands" "$SB/all/.claude/skills/rev" "$SB/all/.claude/plugins/kit/.claude-plugin"
: > "$SB/all/.claude/commands/dep.md"
: > "$SB/all/.claude/skills/rev/SKILL.md"
: > "$SB/all/.claude/plugins/kit/.claude-plugin/plugin.json"
TAB="$(printf '\t')"
assert_has "scan_type finds command" "$(call scan_type command "$SB/all")" "dep"
assert_has "scan_type skill = SKILL.md path" "$(call scan_type skill "$SB/all")" "rev/SKILL.md"
# home dashboard rows: type<TAB>scope<TAB>name<TAB>path (scope varies, so match loosely)
LA="$(HOME="$SB/nope" call list_all "$SB/all")"
row() { printf '%s\n' "$LA" | grep -q "^$1${TAB}.*${TAB}$2${TAB}"; }
if row command dep; then pass "list_all has command row"; else fail "list_all has command row" "$LA"; fi
if row skill rev;   then pass "list_all has skill row";   else fail "list_all has skill row" "$LA"; fi
if row plugin kit;  then pass "list_all has plugin row";  else fail "list_all has plugin row" "$LA"; fi
# a path resolving as two scopes appears once (dedup_by_path)
assert_eq "dedup keeps one per path" "1" \
  "$(printf 'command\there\tdep\t/p/x.md\ncommand\tproject\tdep\t/p/x.md\n' | call dedup_by_path | wc -l | tr -d ' ')"

echo "── unit: render_command ───────────────────"
RC="$(call render_command deploy 'Deploy helper' '[env]' '' '' 'Deploy $1')"
assert_has "cmd has desc"  "$RC" "description: Deploy helper"
assert_has "cmd has args"  "$RC" "argument-hint: [env]"
assert_has "cmd has body"  "$RC" 'Deploy $1'
RC2="$(call render_command deploy 'd' '' '' '' '')"
assert_no  "no empty args" "$RC2" "argument-hint:"

echo "── unit: render_skill ─────────────────────"
RS="$(call render_skill code-review 'Reviews code' '' '')"
assert_has "skill name"  "$RS" "name: code-review"
assert_has "skill desc"  "$RS" "description: Reviews code"
assert_has "skill title" "$RS" "# Code Review"

echo "── unit: plugin_manifest valid JSON ───────"
PM="$(call plugin_manifest my-plugin 'A "quoted" desc')"
if command -v jq >/dev/null 2>&1; then
  if printf '%s' "$PM" | jq -e . >/dev/null 2>&1; then pass "manifest is valid json"; else fail "manifest is valid json" "$PM"; fi
  assert_eq "manifest name" "my-plugin" "$(printf '%s' "$PM" | jq -r .name)"
else
  assert_has "manifest name (no jq)" "$PM" '"name": "my-plugin"'
fi

echo "── integration: non-interactive create ────"
# default type via multi-call symlinks
BIN="$SB/bin"; mkdir -p "$BIN"
ln -sf "$KITZ" "$BIN/cmdz"; ln -sf "$KITZ" "$BIN/sklz"; ln -sf "$KITZ" "$BIN/plgz"

"$BIN/cmdz" deploy -m 'Deploy $1 to staging' -D 'deploy helper' --dir "$SB/proj" -y >/dev/null 2>&1
assert_file "cmdz wrote command" "$SB/proj/.claude/commands/deploy.md"
assert_has  "command body saved" "$(cat "$SB/proj/.claude/commands/deploy.md" 2>/dev/null)" 'Deploy $1 to staging'

"$BIN/sklz" code-review -D 'reviews code' --dir "$SB/proj" -y >/dev/null 2>&1
assert_file "sklz wrote skill" "$SB/proj/.claude/skills/code-review/SKILL.md"

"$BIN/plgz" my-kit -D 'a kit' --dir "$SB/proj" -y >/dev/null 2>&1
assert_file "plgz wrote manifest" "$SB/proj/.claude/plugins/my-kit/.claude-plugin/plugin.json"
assert_file "plgz scaffolds (commands dir marker)" "$SB/proj/.claude/plugins/my-kit/.claude-plugin/plugin.json"
if [ -d "$SB/proj/.claude/plugins/my-kit/commands" ]; then pass "plugin commands/ scaffolded"; else fail "plugin commands/ scaffolded"; fi

echo "── integration: slugify on input name ─────"
"$BIN/cmdz" 'My Fancy Cmd' -m body --dir "$SB/proj" -y >/dev/null 2>&1
assert_file "name slugified" "$SB/proj/.claude/commands/my-fancy-cmd.md"

echo "── integration: namespaced command ────────"
"$BIN/cmdz" git/sync -m 'sync the repo' --dir "$SB/proj" -y >/dev/null 2>&1
assert_file "namespaced path"        "$SB/proj/.claude/commands/git/sync.md"
assert_has  "namespaced invoke hint" "$("$BIN/cmdz" git/sync -m x --dir "$SB/proj" -y -f 2>&1)" "/git:sync"

echo "── integration: --message-file ────────────"
printf 'line one\nline two with $1\n' > "$SB/body.txt"
"$BIN/sklz" from-file -M "$SB/body.txt" --dir "$SB/proj" -y >/dev/null 2>&1
assert_has "message-file body" "$(cat "$SB/proj/.claude/skills/from-file/SKILL.md" 2>/dev/null)" 'line two with $1'

echo "── integration: overwrite protection ──────"
"$BIN/cmdz" deploy -m 'changed' --dir "$SB/proj" -y >/dev/null 2>&1
assert_code "refuses overwrite" "3" "$?"
"$BIN/cmdz" deploy -m 'changed' --dir "$SB/proj" -y -f >/dev/null 2>&1
assert_code "force overwrites" "0" "$?"
assert_has  "content updated" "$(cat "$SB/proj/.claude/commands/deploy.md")" "changed"

echo "── integration: dry-run writes nothing ────"
OUT="$("$BIN/cmdz" ghost -m x --dir "$SB/proj" -y -n 2>&1)"
assert_has  "dry-run prints path" "$OUT" "ghost.md"
if [ -f "$SB/proj/.claude/commands/ghost.md" ]; then fail "dry-run wrote nothing"; else pass "dry-run wrote nothing"; fi

echo "── unit: strip_outer_fence ────────────────"
assert_eq "strips wrapping fence" "hi" "$(printf '```md\nhi\n```\n' | call strip_outer_fence)"
assert_eq "keeps inner fences"  "$(printf 'a\n```\nx\n```\nb')" "$(printf 'a\n```\nx\n```\nb\n' | call strip_outer_fence)"

echo "── unit: gen_prompt ───────────────────────"
GP="$(call gen_prompt command standup 'summarize my day' '' '')"
assert_has "prompt has name"     "$GP" 'named "standup"'
assert_has "prompt has intent"   "$GP" 'summarize my day'
assert_has "prompt cues \$ARGS"  "$GP" '$ARGUMENTS'

echo "── unit: revise_prompt ────────────────────"
RV="$(call revise_prompt command standup 'do standup' 'PRIOR_DRAFT_TEXT' 'make it shorter')"
assert_has "revise has prior"    "$RV" "PRIOR_DRAFT_TEXT"
assert_has "revise has feedback" "$RV" "make it shorter"
assert_has "revise has name"     "$RV" '"standup"'

echo "── integration: --generate (stubbed claude) ──"
# Stub echoes a marker that reveals whether it saw a revision prompt.
cat > "$SB/fakeclaude" <<'STUB'
#!/bin/sh
mode=fresh
for a in "$@"; do case "$a" in *"Revise it per this feedback"*) mode=revised ;; esac; done
cat <<OUT
\`\`\`markdown
---
description: canned generated description
argument-hint: [thing]
---

Generated body for \$ARGUMENTS. MARKER_OK mode=$mode
\`\`\`
OUT
STUB
chmod +x "$SB/fakeclaude"
KITZ_CLAUDE_BIN="$SB/fakeclaude" "$BIN/cmdz" gen-cmd -g -i "do a thing" --dir "$SB/proj" -y >/dev/null 2>&1
GF="$SB/proj/.claude/commands/gen-cmd.md"
assert_file "generate wrote file"     "$GF"
assert_has  "generated body kept"     "$(cat "$GF" 2>/dev/null)" "MARKER_OK"
assert_has  "generated frontmatter"   "$(cat "$GF" 2>/dev/null)" "canned generated description"
assert_no   "outer fence stripped"    "$(cat "$GF" 2>/dev/null)" '```markdown'
assert_has  "fresh draft (no revise)" "$(cat "$GF" 2>/dev/null)" "mode=fresh"

echo "── integration: --revise (stubbed claude) ──"
KITZ_CLAUDE_BIN="$SB/fakeclaude" "$BIN/cmdz" rev-cmd -g -i "do a thing" --revise "shorter" --dir "$SB/proj" -y >/dev/null 2>&1
RVF="$SB/proj/.claude/commands/rev-cmd.md"
assert_file "revise wrote file"       "$RVF"
assert_has  "revise pass happened"    "$(cat "$RVF" 2>/dev/null)" "mode=revised"

echo "── integration: --doctor ──────────────────"
DOUT="$("$KITZ" --doctor 2>&1)"
assert_has "doctor lists deps"   "$DOUT" "dependencies:"
assert_has "doctor shows fzf"    "$DOUT" "fzf"
assert_has "doctor shows scopes" "$DOUT" "scopes resolved from"
assert_has "doctor shows model"  "$DOUT" "generation model:"

echo "── integration: --yes guards ──────────────"
"$KITZ" --type command -y --dir "$SB/proj" >/dev/null 2>&1
assert_code "yes w/o name fails" "1" "$?"

echo "── integration: picker copy + delete ──────"
# clipboard stub captures whatever is piped to it.
printf '#!/bin/sh\ncat > "%s"\n' "$SB/clip.out" > "$SB/fakeclip"; chmod +x "$SB/fakeclip"
"$BIN/cmdz" trash-me -m 'BODY_TO_COPY' --dir "$SB/proj" -y >/dev/null 2>&1
CP="$SB/proj/.claude/commands/trash-me.md"
# copy: __copy subcommand + internal_copy honour the clipboard stub
KITZ_CLIP="$SB/fakeclip" "$BIN/cmdz" __copy "$CP" >/dev/null 2>&1
assert_has "ctrl-y copies file contents" "$(cat "$SB/clip.out" 2>/dev/null)" "BODY_TO_COPY"
# reveal: __reveal hands the file path to the file-manager stub
printf '#!/bin/sh\nprintf "%%s" "$1" > "%s"\n' "$SB/reveal.out" > "$SB/fakereveal"; chmod +x "$SB/fakereveal"
KITZ_REVEAL="$SB/fakereveal" "$BIN/cmdz" __reveal "$CP" >/dev/null 2>&1
assert_eq "ctrl-o reveals the file path" "$CP" "$(cat "$SB/reveal.out" 2>/dev/null)"
rm -f "$SB/reveal.out"
KITZ_REVEAL="$SB/fakereveal" "$BIN/cmdz" __reveal "$SB/proj/.claude/commands/gone.md" >/dev/null 2>&1
if [ -f "$SB/reveal.out" ]; then fail "ctrl-o no-op on missing file"; else pass "ctrl-o no-op on missing file"; fi
# delete a command = remove just the file
call do_remove command "$CP"
if [ -e "$CP" ]; then fail "ctrl-x deletes command file"; else pass "ctrl-x deletes command file"; fi
# delete a skill = remove the whole skill dir, not just SKILL.md
"$BIN/sklz" trash-skill -D 'x' --dir "$SB/proj" -y >/dev/null 2>&1
SK="$SB/proj/.claude/skills/trash-skill"
call do_remove skill "$SK/SKILL.md"
if [ -d "$SK" ]; then fail "ctrl-x deletes whole skill dir"; else pass "ctrl-x deletes whole skill dir"; fi

echo "── unit + integration: paste (clipboard -> new) ──"
# stub the clipboard-read command (KITZ_PASTE) to emit a full skill file.
printf '#!/bin/sh\nprintf "%%s\\n" "---" "name: pasted" "---" "" "BODY FROM CLIPBOARD"\n' > "$SB/fakepaste"; chmod +x "$SB/fakepaste"
assert_has "read_clipboard via KITZ_PASTE" "$(KITZ_PASTE="$SB/fakepaste" call read_clipboard)" "BODY FROM CLIPBOARD"
# --paste create: body is the clipboard verbatim, not wrapped in a template
KITZ_PASTE="$SB/fakepaste" "$BIN/sklz" from-clip -p --dir "$SB/proj" -y >/dev/null 2>&1
PF="$SB/proj/.claude/skills/from-clip/SKILL.md"
assert_file "paste wrote the skill"        "$PF"
assert_has  "paste = clipboard verbatim"   "$(cat "$PF" 2>/dev/null)" "BODY FROM CLIPBOARD"
assert_has  "paste keeps pasted name"      "$(cat "$PF" 2>/dev/null)" "name: pasted"
assert_no   "paste doesn't wrap template"  "$(cat "$PF" 2>/dev/null)" "drives auto-trigger"
# empty clipboard is refused
printf '#!/bin/sh\nprintf ""\n' > "$SB/emptypaste"; chmod +x "$SB/emptypaste"
KITZ_PASTE="$SB/emptypaste" "$BIN/cmdz" no-clip -p --dir "$SB/proj" -y >/dev/null 2>&1
assert_code "empty clipboard refused" "1" "$?"

echo "── integration: editor non-zero exit still saves ──"
# a real editor can exit non-zero (swap prompt, :cq, plugin) yet still have saved
# the file; set -e must not abort before write_artifact and drop the user's work.
printf '#!/bin/sh\nprintf "SAVED ANYWAY\\n" > "$1"\nexit 1\n' > "$SB/badexit"; chmod +x "$SB/badexit"
EDITOR="$SB/badexit" "$BIN/cmdz" exit-save --dir "$SB/proj" >/dev/null 2>&1
EF="$SB/proj/.claude/commands/exit-save.md"
assert_file "editor exit!=0 still writes the file" "$EF"
assert_has  "editor content is kept"               "$(cat "$EF" 2>/dev/null)" "SAVED ANYWAY"

echo "── lint: shellcheck (if present) ──────────"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -s sh "$KITZ" "$HERE/../install.sh" >"$SB/sc.txt" 2>&1; then
    pass "shellcheck clean (kitz + install.sh)"
  else
    fail "shellcheck" "$(cat "$SB/sc.txt")"
  fi
else
  printf '  ·    shellcheck not installed — skipped\n'
fi

echo
printf '════ %d passed, %d failed ════\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
