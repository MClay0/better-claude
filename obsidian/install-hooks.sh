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
