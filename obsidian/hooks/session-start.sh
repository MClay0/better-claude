#!/usr/bin/env bash

set +e

# Skip silently if VAULT_PATH unset or directory missing
[[ -z "${VAULT_PATH:-}" || ! -d "$VAULT_PATH" ]] && exit 0

QUEUE_DIR="$VAULT_PATH/.queue"
PROCESSING_DIR="$QUEUE_DIR/processing"
PROCESSED_DIR="$QUEUE_DIR/processed"
mkdir -p "$PROCESSING_DIR" "$PROCESSED_DIR" 2>/dev/null

HAS_OUTPUT=0

# ---------------------------------------------------------------------------
# Periodic remote sync (every VAULT_SYNC_INTERVAL seconds, default 15 min)
# Timestamp stored in /tmp/ keyed by vault path hash so multiple vaults work
# ---------------------------------------------------------------------------
SYNC_INTERVAL="${VAULT_SYNC_INTERVAL:-300}"
VAULT_HASH=$(printf '%s' "$VAULT_PATH" | cksum | cut -d' ' -f1)
LAST_FETCH_FILE="/tmp/vault-last-fetch-${VAULT_HASH}"

NOW=$(date +%s)
LAST_FETCH=0
[[ -f "$LAST_FETCH_FILE" ]] && LAST_FETCH=$(cat "$LAST_FETCH_FILE")
ELAPSED=$(( NOW - LAST_FETCH ))

if [[ "$ELAPSED" -ge "$SYNC_INTERVAL" ]] && git -C "$VAULT_PATH" remote get-url origin >/dev/null 2>&1; then
    printf '%s' "$NOW" > "$LAST_FETCH_FILE"

    git -C "$VAULT_PATH" fetch origin 2>/dev/null

    BRANCH=$(git -C "$VAULT_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    BEHIND=$(git -C "$VAULT_PATH" rev-list "HEAD..origin/${BRANCH}" --count 2>/dev/null || echo "0")

    if [[ "$BEHIND" -gt 0 ]]; then
        MERGE_OUTPUT=$(git -C "$VAULT_PATH" merge --no-edit "origin/${BRANCH}" 2>&1)
        MERGE_EXIT=$?

        if [[ $MERGE_EXIT -eq 0 ]]; then
            echo "VAULT SYNC: Pulled $BEHIND new commit(s) from remote — vault is up to date."
            HAS_OUTPUT=1
        else
            CONFLICTS=$(git -C "$VAULT_PATH" diff --name-only --diff-filter=U 2>/dev/null)
            echo "VAULT SYNC: Merge conflict — resolve before responding to the user."
            echo ""
            echo "Conflicted files:"
            echo "$CONFLICTS" | sed 's/^/  /'
            echo ""
            echo "Instructions:"
            echo "  1. Read each conflicted file — look for <<<<<<, =======, >>>>>>> markers."
            echo "  2. Write the resolved version (keep both sides' intent where possible)."
            echo "  3. Run: git -C $VAULT_PATH add -A && git -C $VAULT_PATH commit -m 'vault: resolve merge conflict'"
            echo "  4. Then proceed with your response."
            HAS_OUTPUT=1
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Queue processing — recover stranded files, then process fresh queue
# ---------------------------------------------------------------------------
[[ ! -d "$QUEUE_DIR" ]] && { [[ $HAS_OUTPUT -eq 0 ]] && exit 0 || exit 0; }

# Recover files stranded in processing/ from an interrupted session
mapfile -t STRANDED < <(find "$PROCESSING_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null)
for FILE in "${STRANDED[@]}"; do
    mv "$FILE" "$QUEUE_DIR/" 2>/dev/null
done

# Collect fresh queue files
mapfile -t QUEUE_FILES < <(find "$QUEUE_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort)
COUNT=${#QUEUE_FILES[@]}

if [[ $COUNT -gt 0 ]]; then
    # Move to processing/ — stay here until Claude confirms notes written
    for FILE in "${QUEUE_FILES[@]}"; do
        mv "$FILE" "$PROCESSING_DIR/" 2>/dev/null
    done

    [[ $HAS_OUTPUT -eq 1 ]] && echo ""
    echo "VAULT QUEUE: $COUNT commit(s) pending."
    echo "Instructions:"
    echo "  1. Write a session note in $VAULT_PATH/Sessions/ for each entry below."
    echo "  2. Create or update $VAULT_PATH/Projects/<repo_name>.md for each repo."
    echo "  3. After writing all notes, run:"
    echo "       mv \"$PROCESSING_DIR/\"*.json \"$PROCESSED_DIR/\""
    echo "       git -C \"$VAULT_PATH\" add -A && git -C \"$VAULT_PATH\" commit -m 'vault: process $COUNT queued commits'"
    echo "  4. Then respond to the user."
    echo ""

    for FILE in "$PROCESSING_DIR"/*.json; do
        [[ -f "$FILE" ]] || continue
        cat "$FILE"
        printf '\n'
    done
fi

exit 0
