#!/usr/bin/env bash
set -euo pipefail

HOOKS_DIR="$HOME/.git-hooks"
WRAPPER="$HOOKS_DIR/post-commit"

# CLAUDE_OBSIDIAN_DIR: directory containing this script (the obsidian/ dir)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${CLAUDE_OBSIDIAN_DIR:=$SCRIPT_DIR}"
: "${VAULT_PATH:=${VAULT_PATH:-}}"

mkdir -p "$HOOKS_DIR"

# Note if a pre-existing wrapper is being overwritten
if [[ -f "$WRAPPER" ]]; then
    echo "[OVERWRITE] Pre-existing $WRAPPER replaced."
fi

cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
set +e
export VAULT_PATH="${VAULT_PATH}"
export CLAUDE_OBSIDIAN_DIR="${CLAUDE_OBSIDIAN_DIR}"
bash "\$CLAUDE_OBSIDIAN_DIR/hooks/post-commit"
exit 0
EOF

chmod +x "$WRAPPER"

git config --global core.hooksPath "$HOOKS_DIR"

echo "[OK] Global git hook installed: $WRAPPER"
echo "[OK] core.hooksPath set to: $HOOKS_DIR"
echo "[OK] All future commits in any repo will queue a vault note."

# Register session-start hook in ~/.claude/settings.json
SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="bash ${CLAUDE_OBSIDIAN_DIR}/hooks/session-start.sh"
HOOK_ENTRY='{"matcher":"","hooks":[{"type":"command","command":"'"$HOOK_CMD"'"}]}'

mkdir -p "$(dirname "$SETTINGS")"

if [[ ! -f "$SETTINGS" ]]; then
    printf '{\n  "hooks": {\n    "UserPromptSubmit": [%s]\n  }\n}\n' "$HOOK_ENTRY" > "$SETTINGS"
    echo "[OK] Created ~/.claude/settings.json with session-start hook."
else
    # Check if command is already registered (idempotency)
    if jq -e --arg cmd "$HOOK_CMD" \
        '(.hooks.UserPromptSubmit // []) | .[] | .hooks // [] | .[] | select(.command == $cmd)' \
        "$SETTINGS" >/dev/null 2>&1; then
        echo "[SKIP] session-start hook already registered in ~/.claude/settings.json"
    else
        # Merge: append entry to UserPromptSubmit (create key if absent)
        UPDATED=$(jq --argjson entry "$HOOK_ENTRY" \
            '.hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // []) + [$entry]' \
            "$SETTINGS")
        printf '%s\n' "$UPDATED" > "$SETTINGS"
        echo "[OK] Added session-start hook to ~/.claude/settings.json"
    fi
fi
