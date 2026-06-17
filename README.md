# cz 🔱

Capture Claude Code **commands**, **skills**, and **plugins** the instant the
idea lands — and drop them in the right `.claude/` scope without breaking flow.

One portable `sh` engine, three muscle-memory names:

| Name | Makes | Lands at |
|------|-------|----------|
| `cmdz` | slash command | `<scope>/.claude/commands/<name>.md` |
| `sklz` | skill | `<scope>/.claude/skills/<name>/SKILL.md` |
| `plgz` | plugin | `<scope>/.claude/plugins/<name>/` |
| `cz`   | *asks which* | — |

## Install

```sh
git clone <this> ~/Projects/cz   # or wherever
sh ~/Projects/cz/install.sh       # symlinks cz/cmdz/sklz/plgz into PATH
```
Requires `fzf` (interactive pickers). `bat` (preview) and `$EDITOR` are optional
but nice. Uninstall: `sh install.sh --uninstall`. Check your setup any time:

```sh
cz --doctor      # deps, editor, generation model, and the scopes you'd write to
```

### Homebrew

```sh
brew install H0BB5/cz/cz
```
Publishing flow (one-time): push this repo + tag a release, run `./release.sh v0.2.0`
to get the `url`/`sha256`, paste into `homebrew/cz.rb`, and push it to your
`homebrew-cz` tap. See the header of `homebrew/cz.rb`.

## Use — three speeds

```sh
# 1. One-shot (zero prompts) — idea straight to disk
cmdz deploy -m 'Deploy $1 to $2. Confirm before prod.' -D 'deploy helper' -s project -y

# 2. Quick — editor opens prefilled, save, pick scope
cmdz deploy

# 3. Full — pick type, name, scope, then edit
cz
```

The name picker doubles as an editor: type a new name + Enter to create, or
highlight an existing artifact + Enter to reopen it in place.

## Ghostwrite with Claude (`-g`) ✦

Don't write the body — describe it, and Claude drafts the whole artifact
(frontmatter + prompt) headless via `claude -p` in ~10s, then opens it in your
editor to review:

```sh
cmdz scope-creep -g -i "flag changes in the branch diff that are out of scope for the PR"
sklz pr-explainer -g -i "explain a PR's risk and blast radius to a reviewer"
cmdz scope-creep -g                 # interactive: prompts 'what should it do?'
```
- `-i/--intent` is the brief (falls back to `-m`, then `--description`, then the name).
- Tools are disabled for the generation, so it's a fast single-shot completion — not an agentic run.
- Model: `--gen-model` (default `claude-sonnet-4-6`; `CZ_GEN_MODEL` to set globally).
- Pairs with `-y` (write straight to disk) or `-n` (preview the draft).

## Scopes

`user` (`~/.claude`) · `project` (nearest `.claude`/`.git`) · `workspace`
(monorepo root) · `here` (`$PWD`). Override with `--scope` or `--dir <path>`.

## Anywhere you live

- **tmux** — `prefix + C` capture popup, `prefix + G` ghostwrite popup (`integrations/tmux.conf.snippet`)
- **nvim** — `:Cz` / `:CzGen`, or visual-select a brief → `:CzGen` to have Claude draft it (`integrations/nvim/cz.lua`)
- **Raycast** — capture + "Draft Claude Artifact (AI)" script commands (`integrations/raycast/`)
- **Claude Code** — `!cmdz my-idea -g -i '...' -y`

## Develop

```sh
sh test/run.sh    # 45 pure-shell assertions, no TTY needed (claude is stubbed)
```
Architecture and rationale: see [DESIGN.md](./DESIGN.md).
