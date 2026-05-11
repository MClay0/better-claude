#!/usr/bin/env bash
set +e

# Backfill git commit history into the vault queue.
# Each commit becomes a queue file processed by Claude on next session open.
#
# Usage: bash backfill.sh [--repo <path>] [--last N]

REPO=""
LAST=50

_help() {
  cat <<'EOF'
Usage: backfill.sh [--repo <path>] [--last N]

Options:
  --repo <path>   Path to the git repo to backfill (default: current directory)
  --last N        Number of most recent commits to queue (default: 50)
  --help, -h      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO="$2"; shift 2 ;;
    --last)    LAST="$2"; shift 2 ;;
    --help|-h) _help; exit 0 ;;
    *)         echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

REPO="${REPO:-$(pwd)}"
REPO="$(realpath "$REPO" 2>/dev/null || echo "$REPO")"

if [ -z "${VAULT_PATH:-}" ] || [ ! -d "$VAULT_PATH" ]; then
  echo "Error: VAULT_PATH is not set or does not exist" >&2
  exit 1
fi

if [ ! -d "$REPO/.git" ]; then
  echo "Error: $REPO is not a git repository" >&2
  exit 1
fi

QUEUE_DIR="$VAULT_PATH/.queue"
mkdir -p "$QUEUE_DIR"

# Derive repo name
REMOTE_URL=$(git -C "$REPO" remote get-url origin 2>/dev/null)
if [ -n "$REMOTE_URL" ]; then
  REPO_NAME=$(basename "$REMOTE_URL" .git)
else
  REPO_NAME=$(basename "$REPO")
fi

echo "Backfilling last $LAST commits from: $REPO_NAME"
echo ""

# Get SHAs oldest-first so Claude processes them in chronological order
mapfile -t SHAS < <(git -C "$REPO" log --format="%H" -n "$LAST" | tac)

COUNT=0
SKIPPED=0

for SHA in "${SHAS[@]}"; do
  [ -z "$SHA" ] && continue

  # Skip if already in any queue state
  if find "$QUEUE_DIR" -name "${SHA}.json" -type f 2>/dev/null | grep -q .; then
    echo "[SKIP] ${SHA:0:8} already queued"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  SHORT_MSG=$(git -C "$REPO" log -1 --format="%s" "$SHA" 2>/dev/null)
  TIMESTAMP=$(git -C "$REPO" log -1 --format="%aI" "$SHA" 2>/dev/null)

  # Best-effort branch name from reflog decorations
  BRANCH=$(git -C "$REPO" log -1 --format="%D" "$SHA" 2>/dev/null \
    | grep -oE 'origin/[^,)]+' | head -1 | sed 's|origin/||')
  BRANCH="${BRANCH:-main}"

  CHANGED_FILES=$(git -C "$REPO" diff-tree --no-commit-id -r --name-only "$SHA" 2>/dev/null \
    | awk 'BEGIN{printf "["} NR>1{printf ","} {gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); printf "\"" $0 "\""} END{printf "]"}')
  [ -z "$CHANGED_FILES" ] && CHANGED_FILES="[]"

  SHA_ESC=$(printf '%s' "$SHA" | sed 's/\\/\\\\/g; s/"/\\"/g')
  MSG_ESC=$(printf '%s' "$SHORT_MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
  BRANCH_ESC=$(printf '%s' "$BRANCH" | sed 's/\\/\\\\/g; s/"/\\"/g')
  REPO_ESC=$(printf '%s' "$REPO_NAME" | sed 's/\\/\\\\/g; s/"/\\"/g')

  printf '{"sha":"%s","short_message":"%s","branch":"%s","repo_name":"%s","changed_files":%s,"timestamp":"%s"}\n' \
    "$SHA_ESC" "$MSG_ESC" "$BRANCH_ESC" "$REPO_ESC" "$CHANGED_FILES" "$TIMESTAMP" \
    > "$QUEUE_DIR/${SHA}.json"

  echo "[OK] ${SHA:0:8} — $SHORT_MSG"
  COUNT=$((COUNT + 1))
done

echo ""
echo "$COUNT commits queued${SKIPPED:+, $SKIPPED skipped (already queued)}."
echo "Open Claude Code and send any message — the session-start hook will process them."
