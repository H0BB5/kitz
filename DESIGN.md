# kitz — capture Claude artifacts on the fly

> One portable engine, three muscle-memory names. Capture a slash command,
> skill, or plugin the instant the idea lands — and drop it in the right
> `.claude/` scope without breaking flow.

## 0. Problem

Ideas for reusable Claude Code commands/skills arrive mid-task. The cost of
stopping to (a) remember the file format, (b) figure out the right directory,
(c) author frontmatter, kills the impulse. By the time you've context-switched,
the idea is gone or done badly.

`kitz` collapses that to a single muscle-memory keystroke from anywhere you live:
Raycast, tmux, nvim, or a Claude Code `!` shell-out.

## 1. Design principles

1. **Zero-friction default.** The fastest path is one word + Enter.
2. **Speed tiers, not modes.** The same command works one-shot, quick, or fully
   interactive depending on how much you type. You never "switch into" a mode.
3. **The name *is* the type.** Invoking `sklz` already means "skill" — no type
   prompt. (busybox-style multi-call dispatch on `$0`.)
4. **Portable core, thin shims.** All logic lives in one POSIX `sh` script.
   Raycast/tmux/nvim are <10-line adapters that call it.
5. **Interactive == sugar over flags.** Every interactive prompt has a flag
   equivalent, so the whole tool is scriptable and testable without a TTY.
6. **Match the godmux aesthetic.** fzf pickers + `bat` preview + tmux popups.
   No new heavy deps (`gum`/`charm` not required; used only if present).

## 2. The four entry points (multi-call binary)

A single script `bin/kitz`. `install.sh` symlinks four names to it; the script
reads `basename "$0"` to pick a default artifact type:

| Invoked as | Default type | Output |
|------------|--------------|--------|
| `kitz`   | *ask* (fzf type picker) | — |
| `cmdz` | command | `<scope>/.claude/commands/<name>.md` |
| `sklz` | skill   | `<scope>/.claude/skills/<name>/SKILL.md` |
| `plgz` | plugin  | `<scope>/.claude/plugins/<name>/` (+ manifest) |

`--type` overrides the default regardless of which name launched it.

## 3. Artifact formats (verified against live `.claude`)

### command — `.claude/commands/<name>.md`
```markdown
---
description: <one line>
argument-hint: <optional, e.g. "[pr-number]">
---
<body — free text; $ARGUMENTS, $1..$9, !bash, @file all supported>
```
`name` may contain `/` for namespacing: `git/sync` → `commands/git/sync.md`,
invoked as `/git:sync`.

### skill — `.claude/skills/<name>/SKILL.md`
```markdown
---
name: <name>
description: <one line — drives auto-trigger>
---
# <Title>
<body>
```

### plugin — `.claude/plugins/<name>/`
```
<name>/
  .claude-plugin/plugin.json   # { name, version, description, author }
  commands/                    # scaffold (empty, ready for cmdz)
  skills/
```
(Plugin is the stretch artifact; minimal valid scaffold for the POC.)

## 4. Scope resolution

Candidate `.claude` parents, discovered from `$PWD` and shown in the scope
picker with their resolved absolute path so the choice is unambiguous:

| Scope | Resolves to |
|-------|-------------|
| `user` | `~/.claude` (always present) |
| `project` | nearest ancestor with `.claude/`, else nearest with `.git`/`package.json` |
| `workspace` | outermost workspace root: `pnpm-workspace.yaml`, `turbo.json`, `lerna.json`, `nx.json`, `go.work`, else topmost `.git` |
| `here` | `$PWD/.claude` |

- Default selection: `project`.
- If the chosen scope has no `.claude/`, the picker entry is labelled
  `(will create)` and the dir is created on write.
- Non-interactive overrides: `--scope <s>` or `--dir <path>` (uses `<path>/.claude`).

## 5. Speed tiers (the whole point)

| Tier | Invocation | Interactions |
|------|-----------|--------------|
| One-shot | `cmdz deploy -m "Deploy $1 to staging" -D "deploy helper" -y` | 0 prompts |
| Quick | `cmdz deploy` → editor opens prefilled → save → scope pick | ~2 |
| Full | `kitz` → type → name → scope → editor | ~4 |
| Edit existing | `sklz` → fuzzy-pick existing skill → editor | reopens in place |

The name picker (fzf `--print-query` over existing artifacts) unifies
create-vs-edit: type a new name + Enter to create; highlight an existing one +
Enter to edit it where it lives (scope step skipped).

## 6. CLI surface

```
kitz [type] [name] [options]

  type   command | skill | plugin   (positional; overrides $0 default)
  name   artifact name (slugified to kebab-case; '/' allowed for commands)

Options
  -t, --type <t>           command|skill|plugin
  -s, --scope <s>          user|project|workspace|here
  -d, --dir <path>         explicit target; uses <path>/.claude
  -m, --message <text>     body content (skips editor)
  -D, --description <t>    frontmatter description
  -a, --args <hint>        argument-hint (commands only)
      --tools <csv>        allowed-tools
      --model <model>      model frontmatter
  -e, --edit               force editor open even with -m
  -y, --yes                non-interactive; defaults + no prompts
  -f, --force              overwrite if exists
  -n, --dry-run            print resolved path + rendered content, write nothing
  -o, --open               reopen the file in $EDITOR after writing
  -l, --list               list artifacts of this type across scopes
  -h, --help / -v, --version
```

## 7. Architecture (testability-first)

Split pure logic from IO so the core is unit-testable with no TTY:

**Pure functions** (deterministic, no side effects beyond stdout):
- `slugify <str>` → kebab-case
- `resolve_scope <scope> <pwd>` → absolute `.claude` parent dir
- `target_path <type> <claude_dir> <name>` → file path to write
- `render <type> <name> <desc> <args> <body>` → full file content
- `plugin_manifest <name> <desc>` → plugin.json content

**IO functions** (mocked/skipped in tests):
- `pick_type`, `pick_scope`, `pick_name` (fzf)
- `open_editor <file>` ($EDITOR)
- `write_artifact` (mkdir + write; honours `--dry-run`/`--force`)

Sourcing guard: `KITZ_SOURCED=1 . bin/kitz` defines functions without running
`main`, so tests call individual functions directly.

## 8. Testing strategy

`test/run.sh` — pure-shell, no external test framework (bats not installed):
- Runs in a sandbox `$HOME` (temp dir) so it never touches the real `~/.claude`.
- Unit: slugify edge cases, scope resolution from nested dirs, target paths,
  rendered frontmatter for all 3 types, plugin manifest JSON validity (`jq`).
- Integration (non-interactive): `kitz <type> <name> -m ... -y --dir <sandbox>`
  and `--dry-run`; assert file exists at expected path with expected content;
  assert overwrite protection (no `-f` → refuse) and idempotency.
- Exit non-zero on first failure; print a PASS/FAIL summary.

## 9. Portability / distribution

- `install.sh`: symlink `kitz`/`cmdz`/`sklz`/`plgz` into `~/.local/bin`
  (fallback `/opt/homebrew/bin`); verify `fzf` (required), warn if
  `bat`/`$EDITOR` missing; print PATH guidance.
- Homebrew (later): `Formula/kitz.rb` installs the script + the 4 symlinks.
- `integrations/`:
  - `raycast/` — Raycast Script Command with arguments → calls `kitz ... -y`.
  - `tmux.conf.snippet` — `bind C-k display-popup -E kitz` (godmux-style popup).
  - `nvim/kitz.lua` — `:Kitz` user command; visual selection becomes `--message`.

## 10. Non-goals (POC)

- No editing of *existing* frontmatter via a form (just reopen in `$EDITOR`).
- No sync/versioning across scopes.
- Plugin scaffold is minimal (manifest + empty command/skill dirs).
