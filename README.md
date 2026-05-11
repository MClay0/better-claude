# better-claude

An aggregation of Claude Code agents, skills, and scripts that turns Claude Code into a more capable daily driver — with an optional Obsidian vault integration that gives Claude persistent project memory across sessions and devices.

## Setup

```bash
git clone --recurse-submodules git@github.com:MClay0/better-claude.git
cd better-claude
bash install.sh
```

The installer walks you through two steps:

**Step 1 — Where to install:**
- `Global (~/.claude/)` — agents, skills, and CLAUDE.md available across every project. Warns before overwriting anything that already exists.
- `Project (.claude/)` — scoped to one repo. Useful for sharing config with a team via `.claude/` in version control. Prompts for a target path (defaults to current directory).

**Step 2 — What to install:**
- `Core only` — agents, skills, CLAUDE.md, ralph, note
- `Obsidian only` — vault integration, git hooks, session tracking, and sync (no core tools)
- `Everything` — core + Obsidian integration

Restart Claude Code after installing.

### Non-interactive flags

```bash
bash install.sh --global                  # core, global
bash install.sh --project --path ~/myapp  # core, project-scoped
bash install.sh --global --obsidian       # core + Obsidian, global
bash install.sh --obsidian                # Obsidian only
bash install.sh --uninstall-obsidian      # remove Obsidian integration (vault files untouched)
```

---

## What's included

### `agency-agents/` (submodule)
160+ specialized AI agent personas — engineering, design, marketing, product, QA, game dev, and more.

Full credit to [@msitarzewski](https://github.com/msitarzewski) — source: https://github.com/msitarzewski/agency-agents

---

### `skills/prd/` — `/prd`
Generates a structured Product Requirements Document designed for AI-driven implementation. Asks clarifying questions, sizes stories to fit a single context window, orders them by dependency, and writes verifiable acceptance criteria.

Pairs with `ralph` to go from idea to implementation autonomously.

---

### `skills/systematic-debugging/` — `/systematic-debugging`
A four-phase debugging framework: root cause investigation, pattern analysis, hypothesis testing, implementation. Core rule: no fixes without root cause first.

Full credit to [@ChrisWiles](https://github.com/ChrisWiles) — source: https://github.com/ChrisWiles/claude-code-showcase

---

### `skills/obsidian-init/` — `/obsidian-init`
One-time structured intake that bootstraps a fresh vault with your existing context. Walks through four sections — active projects, key people, recurring patterns, personal context — writing notes as you answer. Run this when first setting up a new vault.

---

### `skills/obsidian-log/` — explicit vault logging
Fallback for when you want to force a note mid-session. Triggered by "log this decision", "save this pattern", or "remember this". Useful when Claude hasn't picked something up automatically or you want to log something outside the normal triggers.

---

### `skills/obsidian-contacts/` — bulk contact extraction
Triggered by "extract contacts", "log meeting notes", or "process this email". Designed for pasting a block of content — meeting transcript, forwarded email, notes from a call — and having Claude extract and write all people mentioned in one pass. For individual people mentioned naturally in conversation, Claude creates the note automatically.

---

### `ralph`
Runs Claude in a loop against a `PRD.md`. Each iteration picks the next incomplete user story, implements it, and updates `progress.txt`. Pair with `/prd` to go from idea to working code autonomously.

```bash
ralph         # run up to 10 iterations
ralph 5       # run up to 5 iterations
ralph 35      # run up to 35 iterations
```

---

### `note`
CLI for all vault operations from the terminal — no Claude session required.

```bash
# Queue notes for writing at next session open
note log "switched to edge-first auth strategy"
note log --decision "chose Postgres over SQLite for multi-user concurrency"
note log --pattern "always use realpath -m for paths that may not exist yet"
note log --person "Sarah Chen: lead eng at Acme, met at conf"
note log                              # opens $EDITOR for multi-line input

# Backfill git history into the queue
note backfill                         # last 50 commits from current repo
note backfill --repo ~/code/myapp --last 100

# Vault status and sync
note status                           # queue depth + vault git status
note sync                             # commit and push all vault changes
```

---

## Obsidian integration

The Obsidian integration turns your vault into a persistent memory layer for Claude — project context, session history, decisions, patterns, and contacts — all in plain markdown, tracked by git, synced across devices.

### How it works

1. **Post-commit hook** — every `git commit` writes a lightweight JSON entry to `$VAULT_PATH/.queue/`. Zero latency added to commits.
2. **Periodic sync** — every 5 minutes during a session, Claude fetches from the remote and merges any new commits. On clean merge it continues silently. On conflict it reads the conflicted files, resolves them, and commits before responding to you. Interval configurable via `VAULT_SYNC_INTERVAL` (seconds).
3. **Queue processing** — queued commits are picked up at the next session prompt. Claude writes session notes, updates project notes, moves queue files to `processed/`, and commits the vault before responding to your first message.
4. **Durability** — queue files move to `processing/` when Claude starts writing, not after. If a session is interrupted, they're recovered automatically on the next open.
5. **Proactive note writing** — Claude writes notes automatically as things happen during conversation. No need to ask.
6. **Ambient context** — CLAUDE.md contains your vault path and structure. Claude reads the current project note at session start and pulls any other note on demand.
7. **Auto-commit** — Claude commits the vault after every write. No manual `git add` needed.

### What Claude writes automatically

Claude monitors conversation for these events and writes the corresponding note without being asked. After each write it prints one line confirming the file path, then continues.

| Event | Note written |
|---|---|
| A meaningful architectural or implementation decision is made | `Decisions/YYYY-MM-DD-<slug>.md` |
| A reusable pattern or convention is established | `Patterns/<slug>.md` |
| A person is mentioned with substantive context | Created or updated `People/<Name>.md` |
| Work starts in a repo with no existing project note | `Projects/<repo>.md` |
| Session ends naturally ("done", "thanks", "that's it") | `Sessions/YYYY-MM-DD-<repo>.md` |

Tactical implementation steps and one-off fixes are not logged — only things with a tradeoff or future reuse value.

For explicit logging mid-session use `/obsidian-log`, or paste meeting notes / emails and say "extract contacts" to trigger `/obsidian-contacts`.

### Initial setup — bootstrap your vault

After installing, run `/obsidian-init` in Claude Code to seed the vault with your existing context:
- Active projects (repo, stack, status, key decisions already made)
- Key people (colleagues, professors, contacts)
- Recurring patterns and conventions
- Personal context (courses, bills, scheduling)

For repos with existing history, backfill them after the intake:

```bash
note backfill --repo ~/code/my-project --last 100
```

### Vault structure

```
vault/
├── Projects/       # one note per repo; links to sessions and decisions
├── Sessions/       # per-session notes written by Claude
├── Decisions/      # architectural and design decisions
├── Patterns/       # reusable patterns discovered during work
├── People/         # contact notes built from meeting notes and emails
├── Templates/      # note templates (filled by Claude)
├── Personal/       # your notes — Claude reads but never writes here
│   ├── School/
│   ├── Bills/
│   └── Scheduling/
└── .queue/         # commit queue
    ├── processing/ # in-flight (auto-recovered if session interrupted)
    └── processed/  # completed
```

Every note has a `context` field — `work`, `school`, or `personal` — inferred by Claude from the content. Use Obsidian's search or a Dataview query to filter by context:

```
TABLE date, project FROM "" WHERE context = "school" SORT date DESC
```

### Opening in Windows Obsidian (WSL)

After running the installer, it prints a Windows UNC path:

```
\\wsl$\Ubuntu\home\you\vault
```

In Obsidian: **Open folder as vault** → paste that path. No plugin required — Obsidian reads the markdown natively.

### Syncing across devices

Add a GitHub remote to the vault after setup:

```bash
cd ~/vault
git remote add origin git@github.com:you/vault.git
git push -u origin main
```

Claude auto-commits after every write and the session hook fetches every 5 minutes, so the vault stays current across devices without manual intervention. Use `note sync` to force a push at any time.

### Removing the integration

```bash
bash install.sh --uninstall-obsidian
```

Removes the git hooks, Claude Code hook, and vault block from CLAUDE.md. Vault files are not touched.
