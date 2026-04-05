# better-claude

An aggregation of Claude Code agents, skills, and scripts. This is not all original work — it pulls together tools from several open source projects into one place.

## Setup

```bash
git clone --recurse-submodules git@github.com:MClay0/better-claude.git
cd better-claude
bash install.sh
```

You'll be prompted to choose between two install modes:

**Global** (`~/.claude/`) — agents, skills, and CLAUDE.md are available across every project on your machine. Will warn before overwriting anything that already exists.

**Per-project** — installs into a specific project directory, doesn't touch your global Claude setup. Useful if you want to scope it to a specific repo or share the config with a team by committing `.claude/`. You'll be prompted for a target path (defaults to current directory), or pass it directly:

```bash
bash install.sh --project --path ~/projects/myapp
```

Restart Claude Code after installing.

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

### `ralph`
A bash script that runs Claude in a loop against a `PRD.md`. Each iteration picks the next incomplete user story, implements it, and updates `progress.txt`.

```bash
ralph         # runs up to 10 iterations
ralph 5       # runs up to 5 iterations
ralph 35      # runs up to 35 iterations
```
