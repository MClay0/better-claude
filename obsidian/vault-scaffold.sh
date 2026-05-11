#!/bin/bash
set -e

VAULT_PATH="${VAULT_PATH:-$HOME/vault}"
VAULT_PATH="$(realpath -m "$VAULT_PATH")"

# Distro name (for WSL UNC paths)
DISTRO=$(grep ^NAME= /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "Ubuntu")

# Compute the Windows-side path for Obsidian:
# - /mnt/c/... paths → C:\... (native Windows filesystem, preferred)
# - /home/... paths  → \\wsl$\<distro>\home\... (WSL network share, limited Obsidian support)
if echo "$VAULT_PATH" | grep -q "^/mnt/[a-z]/"; then
  DRIVE=$(echo "$VAULT_PATH" | sed 's|^/mnt/\([a-z]\)/.*|\1|' | tr '[:lower:]' '[:upper:]')
  WIN_PATH=$(echo "$VAULT_PATH" | sed "s|^/mnt/[a-z]/|${DRIVE}:\\\\|" | sed 's|/|\\|g')
  OBSIDIAN_PATH="$WIN_PATH"
  OBSIDIAN_NOTE="Windows filesystem path (recommended — full Obsidian support)"
else
  OBSIDIAN_PATH=$(echo "$VAULT_PATH" | sed "s|^/home/|\\\\\\\\wsl\$\\\\${DISTRO}\\\\home\\\\|" | sed 's|/|\\|g')
  OBSIDIAN_NOTE="WSL network share path (limited — file watcher may not work in Obsidian)"
fi

echo "Scaffolding vault at: $VAULT_PATH"

# Create directory structure (idempotent)
mkdir -p \
  "$VAULT_PATH/Projects" \
  "$VAULT_PATH/Sessions" \
  "$VAULT_PATH/Decisions" \
  "$VAULT_PATH/Patterns" \
  "$VAULT_PATH/Templates" \
  "$VAULT_PATH/People" \
  "$VAULT_PATH/Personal/School" \
  "$VAULT_PATH/Personal/Bills" \
  "$VAULT_PATH/Personal/Scheduling" \
  "$VAULT_PATH/.queue/processing" \
  "$VAULT_PATH/.queue/processed" \
  "$VAULT_PATH/.obsidian"

# .obsidian/app.json — enable wikilinks (idempotent)
if [ ! -f "$VAULT_PATH/.obsidian/app.json" ]; then
  echo '{"useMarkdownLinks": false}' > "$VAULT_PATH/.obsidian/app.json"
  echo "[OK] .obsidian/app.json created"
else
  echo "[SKIP] .obsidian/app.json already exists"
fi

# .gitignore (idempotent)
GITIGNORE="$VAULT_PATH/.gitignore"
if [ ! -f "$GITIGNORE" ]; then
  cat > "$GITIGNORE" <<'EOF'
.obsidian/workspace.json
.obsidian/cache
.obsidian/workspace-mobile.json
.obsidian/graph.json
EOF
  echo "[OK] .gitignore created"
else
  echo "[SKIP] .gitignore already exists"
fi

# README.md (idempotent)
README="$VAULT_PATH/README.md"
if [ ! -f "$README" ]; then
  cat > "$README" <<EOF
# Vault

This vault is managed by Claude via the better-claude Obsidian integration.

## Structure

- **Projects/** — one note per git repo; links to sessions and decisions
- **Sessions/** — per-coding-session notes auto-written by Claude
- **Decisions/** — architectural and design decisions
- **Patterns/** — reusable code patterns and conventions
- **Templates/** — note templates (do not edit by hand)
- **Personal/** — personal notes: School, Bills, Scheduling
- **.queue/** — commit queue processed by Claude at session start

## Opening in Windows Obsidian

1. Open Obsidian on Windows
2. Choose **Open folder as vault**
3. Paste this path:

\`\`\`
${UNC_PATH}
\`\`\`

## Syncing across devices

Create a private GitHub repo, then run:

\`\`\`bash
git remote add origin <your-repo-url>
git push -u origin main
\`\`\`
EOF
  echo "[OK] README.md created"
else
  echo "[SKIP] README.md already exists"
fi

# Copy templates if the SKILL/template dir exists alongside this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_SRC="$SCRIPT_DIR/templates"
if [ -d "$TEMPLATES_SRC" ]; then
  for tmpl in "$TEMPLATES_SRC"/*.md; do
    [ -f "$tmpl" ] || continue
    dest="$VAULT_PATH/Templates/$(basename "$tmpl")"
    if [ ! -f "$dest" ]; then
      cp "$tmpl" "$dest"
      echo "[OK] Template: $(basename "$tmpl")"
    else
      echo "[SKIP] Template $(basename "$tmpl") already exists"
    fi
  done
fi

# git init (idempotent)
if [ ! -d "$VAULT_PATH/.git" ]; then
  git -C "$VAULT_PATH" init -q
  echo "[OK] git init"
else
  echo "[SKIP] git repo already initialised"
fi

# Initial commit if there are changes to stage
git -C "$VAULT_PATH" add -A 2>/dev/null || true
if ! git -C "$VAULT_PATH" diff --cached --quiet 2>/dev/null; then
  git -C "$VAULT_PATH" commit -m "init: vault scaffold" -q 2>/dev/null \
    && echo "[OK] Initial commit: init: vault scaffold" \
    || echo "[WARN] Could not create initial commit (check git config user.name/user.email)"
else
  echo "[SKIP] Nothing to commit"
fi

echo ""
echo "Vault ready: $VAULT_PATH"
echo ""
echo "Open in Obsidian ($OBSIDIAN_NOTE):"
echo "  $OBSIDIAN_PATH"
echo ""
echo "To sync across devices: create a private GitHub repo, then run:"
echo "  git remote add origin <url> && git push -u origin main"
echo ""
echo "To open in Obsidian: Open Obsidian → Open folder as vault → paste the path above"
