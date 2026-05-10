#!/usr/bin/env bash

set +e

# Skip silently if VAULT_PATH unset or directory missing
[[ -z "${VAULT_PATH:-}" || ! -d "$VAULT_PATH" ]] && exit 0

QUEUE_DIR="$VAULT_PATH/.queue"
[[ ! -d "$QUEUE_DIR" ]] && exit 0

PROCESSED_DIR="$QUEUE_DIR/processed"
mkdir -p "$PROCESSED_DIR" 2>/dev/null

# Collect *.json files directly in .queue/ (not in subdirs like processed/)
mapfile -t QUEUE_FILES < <(find "$QUEUE_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort)

COUNT=${#QUEUE_FILES[@]}
[[ $COUNT -eq 0 ]] && exit 0

echo "VAULT QUEUE: $COUNT commits pending. Write session notes for each before responding to the user."

for FILE in "${QUEUE_FILES[@]}"; do
    cat "$FILE"
    printf '\n'
    mv "$FILE" "$PROCESSED_DIR/" 2>/dev/null
done

exit 0
