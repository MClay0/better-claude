# PRD: better-claude + Obsidian Integration

## Introduction

Expand better-claude to include a pure-bash Obsidian vault integration. Claude gains ambient awareness of projects, sessions, and decisions stored in a local Obsidian vault (WSL filesystem, opened by Windows Obsidian via `\\wsl$\...` UNC path). Commits are queued asynchronously and processed by Claude at the next session open — zero commit latency. The vault is a standalone git repo pushable to GitHub for multi-device sync. Everything installs via a single `bash install.sh --obsidian` flag.

The existing `claude-obsidian-integration` TypeScript project is used as reference context only — the new implementation is pure bash with no Node.js dependency.

## Goals

- Single-command setup: `bash install.sh --global --obsidian` configures everything
- Vault lives in WSL, accessible from Windows Obsidian via `\\wsl$\...` UNC path
- Every `git commit` queues a note asynchronously; Claude processes the queue at next session open
- CLAUDE.md gives Claude ambient vault awareness (vault path + current project context)
- Vault is a standalone git repo, pushable to GitHub for multi-device sync
- On-demand note logging via both natural language mid-session skill and `ralph log` CLI command

## User Stories

### US-001: Vault scaffold script
**Description:** As a user, I want a script that creates the vault folder structure so I have a consistent, git-tracked place for all note types.

**Acceptance Criteria:**
- [x] `obsidian/vault-scaffold.sh` creates: `Projects/`, `Sessions/`, `Decisions/`, `Patterns/`, `Templates/`, `Personal/School/`, `Personal/Bills/`, `Personal/Scheduling/`, `.queue/`, `.queue/processed/`
- [x] Creates `.obsidian/app.json` with `{ "useMarkdownLinks": false }` to enable wikilinks
- [x] Creates `.gitignore` excluding `.obsidian/workspace.json`, `.obsidian/cache`, `.obsidian/workspace-mobile.json`, `.obsidian/graph.json`
- [x] Runs `git init` in vault directory if not already a git repo
- [x] Creates initial `README.md` at vault root explaining the structure and how to open it in Windows Obsidian
- [x] Script is idempotent — safe to re-run without overwriting existing notes or files
- [x] Script reads vault path from `$VAULT_PATH` env var (default: `~/vault`)

### US-002: Vault note templates
**Description:** As a developer, I want template markdown files for each note type so that Claude always writes consistent, graph-compatible notes using `[[wikilink]]` syntax.

**Acceptance Criteria:**
- [x] `obsidian/templates/session.md` — frontmatter: `type: session`, `date`, `project` (wikilink), `commits`. Sections: Summary, Files Changed, Decisions Made (link list), Loose Ends
- [x] `obsidian/templates/project.md` — frontmatter: `type: project`, `repo`, `status: active`. Sections: Overview, Key Decisions (link list), Recent Sessions (link list)
- [x] `obsidian/templates/decision.md` — frontmatter: `type: decision`, `date`, `project` (wikilink). Sections: Context, Decision, Tradeoffs
- [x] `obsidian/templates/pattern.md` — frontmatter: `type: pattern`, `tags`. Sections: Description, Example, Gotchas
- [x] `obsidian/templates/personal-note.md` — frontmatter: `type: personal`, `date`, `tags`. Free-form body
- [x] All templates use `[[wikilink]]` syntax for cross-references
- [x] `vault-scaffold.sh` copies all templates into `$VAULT_PATH/Templates/` when run

### US-003: GitHub remote setup and Windows UNC path output
**Description:** As a user, I want the setup script to create an initial git commit and print actionable next steps for GitHub sync and opening the vault in Windows Obsidian.

**Acceptance Criteria:**
- [x] After scaffolding, `vault-scaffold.sh` runs `git add -A && git commit -m "init: vault scaffold"` if working tree is clean
- [x] Script prints the Windows UNC path: `\\wsl$\<distro>\<vault-path>` computed from `$VAULT_PATH`
- [x] Distro name is auto-detected from `/etc/os-release` (`$NAME` field)
- [x] Script prints: "To sync across devices: create a private GitHub repo, then run: `git remote add origin <url> && git push -u origin main`"
- [x] Script prints: "To open in Obsidian: Open Obsidian → Open folder as vault → paste the path above"

### US-004: CLAUDE.md vault context block
**Description:** As Claude, I want a vault context section in CLAUDE.md so I have ambient awareness of the vault location and know how to load project context on demand.

**Acceptance Criteria:**
- [x] `obsidian/claude-md-block.sh` appends an `# Obsidian Vault` section to `~/.claude/CLAUDE.md`
- [x] Block contains: vault path (`$VAULT_PATH`), vault structure overview (one line per folder), instruction to read `$VAULT_PATH/Projects/<current-git-repo-name>.md` when starting work on a known project
- [x] Block instructs Claude: never delete vault files, never overwrite — append and create only
- [x] Block instructs Claude: when a `.queue/` file is mentioned, write proper notes before answering
- [x] Script is idempotent — checks for `# Obsidian Vault` heading before appending; does not duplicate
- [x] If `~/.claude/CLAUDE.md` does not exist, creates it with just the vault block

### US-005: Post-commit queue hook
**Description:** As a user, I want every git commit to queue a lightweight note entry so no commit is ever lost, without adding any latency to the commit itself.

**Acceptance Criteria:**
- [ ] `obsidian/hooks/post-commit` is a bash script that exits in <100ms (no Claude invocation)
- [ ] Writes `$VAULT_PATH/.queue/<sha>.json` with fields: `sha`, `short_message`, `branch`, `repo_name`, `changed_files` (array), `timestamp` (ISO 8601)
- [ ] `repo_name` is derived from git remote URL if present, else `basename $(git rev-parse --show-toplevel)`
- [ ] Script exits 0 always — never blocks or errors a commit
- [ ] Script silently skips (no output, no file written) if `$VAULT_PATH` is unset or does not exist

### US-006: Global git hook installation
**Description:** As a user, I want the post-commit hook to apply to all my repos automatically so I never have to configure individual repos.

**Acceptance Criteria:**
- [ ] `obsidian/install-hooks.sh` creates `~/.git-hooks/` directory
- [ ] Writes a `post-commit` wrapper at `~/.git-hooks/post-commit` that exports `VAULT_PATH` and `CLAUDE_OBSIDIAN_DIR` then delegates to `$CLAUDE_OBSIDIAN_DIR/hooks/post-commit`
- [ ] Wrapper is chmod +x
- [ ] Runs `git config --global core.hooksPath ~/.git-hooks`
- [ ] Prints confirmation message and notes any pre-existing `~/.git-hooks/post-commit` that was overwritten

### US-007: Session-start queue processor (Claude Code hook)
**Description:** As a user, I want Claude to see and process any queued commit notes at the start of my next session so vault notes are written automatically.

**Acceptance Criteria:**
- [ ] `obsidian/hooks/session-start.sh` checks for `*.json` files in `$VAULT_PATH/.queue/` (excluding `processed/`)
- [ ] If queue is empty, script exits silently with no output
- [ ] If queue has files, script prints a context block to stdout: `VAULT QUEUE: N commits pending. Write session notes for each before responding to the user.` followed by newline-separated JSON of each queued commit
- [ ] Script moves processed queue files to `$VAULT_PATH/.queue/processed/` immediately after reading them (so Claude Code picks them up only once)
- [ ] `install-hooks.sh` registers this hook in `~/.claude/settings.json` under `hooks.UserPromptSubmit` with an empty matcher
- [ ] If `~/.claude/settings.json` does not exist, creates it with just the hook entry
- [ ] If `hooks.UserPromptSubmit` already exists, appends the entry rather than overwriting

### US-008: install.sh --obsidian flag
**Description:** As a user, I want a single command to set up the entire Obsidian integration so I don't have to run scripts manually or remember any steps.

**Acceptance Criteria:**
- [ ] `install.sh` accepts `--obsidian` flag, combinable with `--global` or `--project`
- [ ] When `--obsidian` is passed: prompts for vault path (default `~/vault`), writes `export VAULT_PATH=<path>` and `export CLAUDE_OBSIDIAN_DIR=<path-to-obsidian-dir>` to `~/.bashrc`
- [ ] Runs `obsidian/vault-scaffold.sh` (creates structure + git init + initial commit)
- [ ] Runs `obsidian/claude-md-block.sh` (appends vault context to CLAUDE.md)
- [ ] Runs `obsidian/install-hooks.sh` (global git hook + Claude Code UserPromptSubmit hook)
- [ ] Prints Windows UNC path and GitHub remote instructions at the end
- [ ] Full setup completes successfully with: `bash install.sh --global --obsidian`

### US-009: Obsidian log skill (mid-session natural language)
**Description:** As a user, I want to say "log this decision" mid-session and have Claude write the appropriate vault note immediately without breaking flow.

**Acceptance Criteria:**
- [ ] `skills/obsidian-log/SKILL.md` defines trigger phrases: "log this", "log this decision", "log this pattern", "save this", "remember this", "save this pattern", "save this decision"
- [ ] Skill instructs Claude to: identify note type from phrasing, fill the appropriate template from `$VAULT_PATH/Templates/`, write to the correct vault folder (`Decisions/`, `Patterns/`, `Sessions/`)
- [ ] Skill instructs Claude to append a wikilink to the new note in `Projects/<current-repo>.md` under the relevant section
- [ ] Skill instructs Claude to confirm the write with: file path written and one-line summary
- [ ] `install.sh` installs this skill alongside existing skills in the appropriate target directory

### US-010: ralph log CLI command
**Description:** As a user, I want to run `ralph log "..."` outside a Claude session to queue a note that will be written at the next session open.

**Acceptance Criteria:**
- [ ] `ralph log "<text>"` writes `$VAULT_PATH/.queue/manual-<timestamp>.json` with: `type: manual`, `text`, `timestamp`
- [ ] `ralph log --decision "<text>"` sets `type: decision` in the queue file
- [ ] `ralph log --pattern "<text>"` sets `type: pattern` in the queue file
- [ ] `ralph log --session "<text>"` sets `type: session` in the queue file
- [ ] `ralph log` with no text argument opens `$EDITOR` for multi-line input; saves result on exit
- [ ] Prints error `VAULT_PATH is not set` and exits 1 if env var is missing
- [ ] `ralph log --help` prints usage summary

### US-011: People note template
**Description:** As a user, I want a consistent template for person notes so Claude always captures contact context in a structured, queryable format.

**Acceptance Criteria:**
- [ ] `obsidian/templates/person.md` — frontmatter: `type: person`, `name`, `role`, `company`, `first-met` (date), `tags`. Sections: Background, Interactions (date + one-liner list), Notes
- [ ] `vault-scaffold.sh` creates `People/` folder at vault root
- [ ] `vault-scaffold.sh` copies `person.md` template into `$VAULT_PATH/Templates/`
- [ ] Person note filenames: `People/<Firstname-Lastname>.md` (hyphens, title case)

### US-012: Contact extraction skill
**Description:** As a user, I want to paste meeting notes or an email and have Claude automatically extract people and create or update their vault notes so I build a living contacts graph over time.

**Acceptance Criteria:**
- [ ] `skills/obsidian-contacts/SKILL.md` defines triggers: "extract contacts", "log meeting notes", "process this email", "update contacts from this"
- [ ] Skill instructs Claude to: identify all named people in the pasted content, check if `People/<Name>.md` exists, create from template if not, append a new entry under Interactions with date and one-line summary if it does
- [ ] Skill instructs Claude to link each person note to any relevant `Projects/` or `Decisions/` note mentioned in the content
- [ ] Skill instructs Claude to confirm: list of names processed and whether each was created or updated
- [ ] Claude never overwrites existing Background or Notes sections — only appends to Interactions
- [ ] `install.sh` installs this skill alongside other skills

## Non-Goals

- No TypeScript or Node.js — pure bash only
- No Obsidian plugin development — vault is plain markdown, Obsidian reads it natively
- No MCP server — Claude reads vault files directly via file tools
- No automatic weekly summaries or AI-generated reviews
- No sync mechanism beyond standard `git push / git pull`
- Claude never deletes or overwrites existing vault notes — append and create only
- No Windows-side scripting — Obsidian opens via UNC path, nothing else needed on Windows
- No per-repo hook installation — global hook only via `core.hooksPath`
- No support for multiple vaults in v1

## Technical Considerations

- `$VAULT_PATH` written to `~/.bashrc`; `$CLAUDE_OBSIDIAN_DIR` points to `better-claude/obsidian/`
- Queue file schema: `{ "sha": "", "short_message": "", "branch": "", "repo_name": "", "changed_files": [], "timestamp": "" }`
- Manual queue file schema: `{ "type": "decision|pattern|session|manual", "text": "", "timestamp": "" }`
- WSL distro detection: `grep ^NAME= /etc/os-release | cut -d= -f2 | tr -d '"'`
- UNC path construction: replace `/home/` prefix with `\\wsl$\<distro>\home\`
- `.obsidian/app.json` minimal content: `{"useMarkdownLinks": false}`
- Claude Code hook registration format in `~/.claude/settings.json`:
  ```json
  {
    "hooks": {
      "UserPromptSubmit": [
        {
          "matcher": "",
          "hooks": [{ "type": "command", "command": "bash $CLAUDE_OBSIDIAN_DIR/hooks/session-start.sh" }]
        }
      ]
    }
  }
  ```
- `ralph` is an existing bash CLI in `better-claude/` — add `log` as a new subcommand block
- Wikilinks use note name only (no folder prefix) — Obsidian resolves them by name automatically
- Session note filenames: `Sessions/YYYY-MM-DD-<repo>-<sha-short>.md`
- Decision note filenames: `Decisions/YYYY-MM-DD-<slug>.md`
- Pattern note filenames: `Patterns/<slug>.md`
- Person note filenames: `People/<Firstname-Lastname>.md` (title case, hyphens between names)
- Contact extraction: Claude checks for existing person note before creating — update beats create
