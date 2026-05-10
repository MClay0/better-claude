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
- **When a \`.queue/\` file is mentioned**, read all queued JSON entries and write proper session/decision/pattern notes for each before responding to the user.
- Use \`[[wikilink]]\` syntax for all cross-references between notes.
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
