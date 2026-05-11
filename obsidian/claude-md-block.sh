#!/bin/bash
set -e

VAULT_PATH="${VAULT_PATH:-$HOME/vault}"
VAULT_PATH="$(realpath -m "$VAULT_PATH")"

CLAUDE_MD="$HOME/.claude/CLAUDE.md"

BLOCK_HEADING="# Obsidian Vault"

# Build the block content with the resolved VAULT_PATH
read -r -d '' VAULT_BLOCK <<EOF || true
# Obsidian Vault

**Vault path:** ${VAULT_PATH}

## Structure

- **Projects/** — one note per git repo; links to sessions and decisions
- **Sessions/** — per-coding-session notes auto-written by Claude
- **Decisions/** — architectural and design decisions
- **Patterns/** — reusable code patterns and conventions
- **Templates/** — note templates
- **Personal/** — personal notes: School, Bills, Scheduling
- **.queue/** — commit queue processed at session start

## Project context

When starting work on a known project, read \`${VAULT_PATH}/Projects/<current-git-repo-name>.md\` for prior decisions and session history. Derive the repo name from \`basename \$(git rev-parse --show-toplevel)\` when inside a git repo.

## Rules

- **Never delete or overwrite vault files** — append to existing notes and create new ones only.
- **Queue processing**: when the session-start hook reports pending commits in \`.queue/processing/\`, write the session notes first, then move each JSON from \`processing/\` to \`processed/\`, then commit the vault (see below).
- **Auto-commit after writing**: after writing any notes to the vault, run \`git -C ${VAULT_PATH} add -A && git -C ${VAULT_PATH} commit -m "vault: <brief description>"\`. Never leave vault changes uncommitted.
- **Merge conflicts**: when the session-start hook reports a conflict, read each conflicted file, resolve the markers (keeping both sides' intent where possible), write the resolved file, then commit before responding to the user.
- **Context tagging**: every note must have a \`context\` field set to one of \`work\`, \`school\`, or \`personal\`. Infer it from the content — \`work\` for code, engineering, professional projects, and business contacts; \`school\` for courses, assignments, professors, and academic deadlines; \`personal\` for life admin, friends, family, and hobbies. When ambiguous, prefer \`work\`.
- Use \`[[wikilink]]\` syntax for all cross-references between notes.

## Proactive note writing

Write vault notes automatically during conversation — do not wait to be asked. After writing, mention it in one short line and move on. Never interrupt the conversation just to discuss note-writing.

| Trigger | Action |
|---|---|
| A meaningful architectural or implementation decision is made | Write \`Decisions/YYYY-MM-DD-<slug>.md\` |
| A reusable pattern or convention is established or discovered | Write \`Patterns/<slug>.md\` |
| A person is mentioned with substantive context (role, relationship, anything worth remembering) | Create or update \`People/<Firstname-Lastname>.md\` |
| Work begins in a git repo with no existing project note | Create \`Projects/<repo-name>.md\` from the project template |
| A natural stopping point is reached (user says "done", "thanks", "that's it", ends the session) | Write \`Sessions/YYYY-MM-DD-<repo>-<slug>.md\` summarising what was accomplished, decisions made, and loose ends |

**What counts as a meaningful decision:** anything with a tradeoff — choosing a library, picking an architecture, deciding on a naming convention, resolving a design question. Tactical implementation steps do not need a decision note.

**What counts as a reusable pattern:** something you would want to apply again in a future session or a different repo. One-off fixes do not need a pattern note.

**Tone when mentioning a write:** one line, lowercase, no fuss. Examples:
- \`logged decision → vault/Decisions/2026-05-10-postgres-over-sqlite.md\`
- \`updated Sarah Chen's contact note\`
- \`created project note for better-claude\`
EOF

# Create CLAUDE.md if it does not exist
if [ ! -f "$CLAUDE_MD" ]; then
  mkdir -p "$(dirname "$CLAUDE_MD")"
  printf '%s\n' "$VAULT_BLOCK" > "$CLAUDE_MD"
  echo "[OK] Created $CLAUDE_MD with vault block"
  exit 0
fi

# Check for existing heading — skip if already present (idempotent)
if grep -qF "$BLOCK_HEADING" "$CLAUDE_MD"; then
  echo "[SKIP] Vault block already present in $CLAUDE_MD"
  exit 0
fi

# Append the block with a blank line separator
printf '\n%s\n' "$VAULT_BLOCK" >> "$CLAUDE_MD"
echo "[OK] Vault block appended to $CLAUDE_MD"
