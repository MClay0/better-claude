#!/bin/bash
set -e

MODE=${1:-""}
PROJECT_PATH=""
OBSIDIAN=0
UNINSTALL_OBSIDIAN=0

usage() {
  echo "Usage: bash install.sh [--global | --project [--path <dir>]] [--obsidian] [--uninstall-obsidian]"
  echo ""
  echo "  --global              Install agents, skills, and CLAUDE.md to ~/.claude/ (affects all projects)"
  echo "  --project             Install agents and skills into a project directory"
  echo "  --path <dir>          Target directory for project install (default: current directory)"
  echo "  --obsidian            Also set up Obsidian vault integration (combinable with --global or --project)"
  echo "  --uninstall-obsidian  Remove Obsidian integration (vault files are NOT deleted)"
  echo ""
  echo "If no flag is provided, you will be prompted to choose."
}

if [ "$MODE" = "--help" ] || [ "$MODE" = "-h" ]; then
  usage
  exit 0
fi

# Parse flags
while [ $# -gt 0 ]; do
  case "$1" in
    --global)             MODE="--global"; shift ;;
    --project)            MODE="--project"; shift ;;
    --path)               PROJECT_PATH="$2"; shift 2 ;;
    --obsidian)           OBSIDIAN=1; shift ;;
    --uninstall-obsidian) UNINSTALL_OBSIDIAN=1; shift ;;
    --help|-h)            usage; exit 0 ;;
    *)                    echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [ "$UNINSTALL_OBSIDIAN" -eq 1 ]; then
  echo "Uninstalling Obsidian integration..."
  echo "(Vault files will NOT be deleted)"
  echo ""

  # Remove global git hook
  if git config --global core.hooksPath 2>/dev/null | grep -q "\.git-hooks"; then
    git config --global --unset core.hooksPath 2>/dev/null && echo "[OK] Removed global core.hooksPath" || true
  else
    echo "[SKIP] core.hooksPath not pointing to ~/.git-hooks — left unchanged"
  fi
  if [ -f "$HOME/.git-hooks/post-commit" ]; then
    rm "$HOME/.git-hooks/post-commit"
    echo "[OK] Removed ~/.git-hooks/post-commit"
  fi

  # Remove session-start hook from settings.json
  SETTINGS="$HOME/.claude/settings.json"
  if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
    UPDATED=$(jq 'if .hooks.UserPromptSubmit then
      .hooks.UserPromptSubmit |= map(select(.hooks[]?.command | test("session-start.sh") | not))
    else . end' "$SETTINGS" 2>/dev/null)
    if [ -n "$UPDATED" ]; then
      printf '%s\n' "$UPDATED" > "$SETTINGS"
      echo "[OK] Removed session-start hook from ~/.claude/settings.json"
    fi
  else
    echo "[WARN] Could not update settings.json — remove session-start hook manually"
  fi

  # Strip vault block from ~/.claude/CLAUDE.md (assumes block is the last section)
  CLAUDE_MD="$HOME/.claude/CLAUDE.md"
  if [ -f "$CLAUDE_MD" ] && grep -qF "# Obsidian Vault" "$CLAUDE_MD"; then
    LINE=$(grep -n "^# Obsidian Vault" "$CLAUDE_MD" | cut -d: -f1 | head -1)
    head -n "$((LINE - 1))" "$CLAUDE_MD" > /tmp/claude_md_clean
    mv /tmp/claude_md_clean "$CLAUDE_MD"
    echo "[OK] Removed vault block from ~/.claude/CLAUDE.md"
  else
    echo "[SKIP] No vault block found in ~/.claude/CLAUDE.md"
  fi

  # Remove env vars from ~/.bashrc and ~/.profile
  for RC in "$HOME/.bashrc" "$HOME/.profile"; do
    [ -f "$RC" ] || continue
    sed -i '/export VAULT_PATH=/d' "$RC"
    sed -i '/export CLAUDE_OBSIDIAN_DIR=/d' "$RC"
    echo "[OK] Removed vault env vars from $RC"
  done

  echo ""
  echo "Done. Vault files untouched. Restart Claude Code to apply changes."
  exit 0
fi

if [ -z "$MODE" ] && [ "$OBSIDIAN" -eq 0 ]; then
  echo "┌─────────────────────────────────────────┐"
  echo "│         better-claude installer         │"
  echo "└─────────────────────────────────────────┘"
  echo ""
  echo "Step 1: Where would you like to install?"
  echo "  1) Global (~/.claude/)  — all projects"
  echo "  2) Project (.claude/)   — current project only"
  echo ""
  read -rp "Choice [1/2]: " choice
  case "$choice" in
    1) MODE="--global" ;;
    2)
      MODE="--project"
      read -rp "Project path [default: current directory]: " input_path
      if [ -n "$input_path" ]; then
        PROJECT_PATH="$input_path"
      fi
      ;;
    *) echo "Invalid choice."; exit 1 ;;
  esac

  echo ""
  echo "Step 2: What would you like to install?"
  echo "  1) Core only      — agents, skills, CLAUDE.md, ralph, note"
  echo "  2) Obsidian only  — vault integration, git hooks, session tracking"
  echo "  3) Everything     — core + Obsidian integration"
  echo ""
  read -rp "Choice [1/2/3]: " components
  case "$components" in
    1) OBSIDIAN=0 ;;
    2) OBSIDIAN=1; MODE="" ;;
    3) OBSIDIAN=1 ;;
    *) echo "Invalid choice."; exit 1 ;;
  esac
fi

# Resolve project target dir
if [ "$MODE" = "--project" ]; then
  if [ -z "$PROJECT_PATH" ]; then
    PROJECT_DIR="$(pwd)"
  else
    PROJECT_DIR="$(realpath "$PROJECT_PATH")"
  fi
fi

install_agents() {
  local dest="$1"
  if [ -d "agency-agents" ]; then
    if [ "$dest" = "global" ]; then
      mkdir -p ~/.claude/agents
      cd agency-agents && bash scripts/install.sh --tool claude-code 2>&1 | grep -E "OK|Error|agents" && cd ..
    else
      mkdir -p "$PROJECT_DIR/.claude/agents"
      cp -r agency-agents/engineering agency-agents/design agency-agents/marketing \
            agency-agents/product agency-agents/testing agency-agents/specialized \
            "$PROJECT_DIR/.claude/agents/" 2>/dev/null || true
      echo "[OK] Agents -> $PROJECT_DIR/.claude/agents/"
    fi
  else
    echo "Warning: agency-agents submodule not found. Run: git submodule update --init"
  fi
}

install_skills() {
  local dest="$1"
  local target
  if [ "$dest" = "global" ]; then
    target=~/.claude/skills
  else
    target="$PROJECT_DIR/.claude/skills"
  fi
  mkdir -p "$target"
  for skill_dir in skills/*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "$target/$skill_name"
    cp "$skill_dir/SKILL.md" "$target/$skill_name/SKILL.md"
    echo "[OK] Skill: $skill_name -> $target/$skill_name"
  done
}

install_claude_md() {
  local dest="$1"
  if [ ! -f "CLAUDE.md" ]; then return; fi

  if [ "$dest" = "global" ]; then
    if [ -f ~/.claude/CLAUDE.md ]; then
      echo ""
      echo "Warning: ~/.claude/CLAUDE.md already exists."
      read -rp "Overwrite? [y/N]: " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Skipped CLAUDE.md"
        return
      fi
    fi
    cp CLAUDE.md ~/.claude/CLAUDE.md
    echo "[OK] CLAUDE.md -> ~/.claude/CLAUDE.md"
  else
    local project_claude_md="$PROJECT_DIR/.claude/CLAUDE.md"
    local project_root_claude_md="$PROJECT_DIR/CLAUDE.md"
    if [ -f "$project_claude_md" ] || [ -f "$project_root_claude_md" ]; then
      echo ""
      echo "Warning: A CLAUDE.md already exists in $PROJECT_DIR."
      read -rp "Overwrite? [y/N]: " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Skipped CLAUDE.md"
        return
      fi
    fi
    mkdir -p "$PROJECT_DIR/.claude"
    cp CLAUDE.md "$project_claude_md"
    echo "[OK] CLAUDE.md -> $project_claude_md"
  fi
}

install_obsidian() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local obsidian_dir="$script_dir/obsidian"

  echo ""
  echo "Setting up Obsidian vault integration..."

  # Detect Windows home dir for default vault path (WSL only)
  # Vaults on the Windows filesystem (/mnt/c/...) work fully with Obsidian on Windows.
  # Vaults on the WSL filesystem (~/vault) trigger an EISDIR watcher error in Obsidian.
  local default_vault
  local win_home
  win_home=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null)
  if [ -n "$win_home" ] && [ -d "$win_home" ]; then
    default_vault="$win_home/Documents/vault"
  else
    default_vault="$HOME/vault"
  fi

  echo ""
  echo "Vault location: use a Windows filesystem path (/mnt/c/...) so Obsidian can open it natively."
  read -rp "Vault path [default: $default_vault]: " input_vault
  local vault_path
  if [ -n "$input_vault" ]; then
    vault_path="$(realpath -m "$input_vault")"
  else
    vault_path="$(realpath -m "$default_vault")"
  fi

  # Write env vars to ~/.bashrc and ~/.profile (idempotent: replace existing exports)
  for RC in "$HOME/.bashrc" "$HOME/.profile"; do
    [ -f "$RC" ] || continue
    if grep -qF "export VAULT_PATH=" "$RC" 2>/dev/null; then
      sed -i "s|export VAULT_PATH=.*|export VAULT_PATH=\"$vault_path\"|" "$RC"
    else
      echo "export VAULT_PATH=\"$vault_path\"" >> "$RC"
    fi
    if grep -qF "export CLAUDE_OBSIDIAN_DIR=" "$RC" 2>/dev/null; then
      sed -i "s|export CLAUDE_OBSIDIAN_DIR=.*|export CLAUDE_OBSIDIAN_DIR=\"$obsidian_dir\"|" "$RC"
    else
      echo "export CLAUDE_OBSIDIAN_DIR=\"$obsidian_dir\"" >> "$RC"
    fi
    echo "[OK] Env vars written to $RC"
  done

  # Export for current shell so sub-scripts can use them
  export VAULT_PATH="$vault_path"
  export CLAUDE_OBSIDIAN_DIR="$obsidian_dir"

  # Run sub-scripts
  bash "$obsidian_dir/vault-scaffold.sh"
  bash "$obsidian_dir/claude-md-block.sh"
  bash "$obsidian_dir/install-hooks.sh"
}

install_ralph() {
  mkdir -p ~/.local/bin
  cp ralph ~/.local/bin/ralph
  chmod +x ~/.local/bin/ralph
  echo "[OK] ralph -> ~/.local/bin/ralph"
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo "Note: Add ~/.local/bin to your PATH:"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
  fi
}

install_note() {
  mkdir -p ~/.local/bin
  cp note ~/.local/bin/note
  chmod +x ~/.local/bin/note
  echo "[OK] note  -> ~/.local/bin/note"
}

echo "Installing better-claude..."
echo ""

if [ "$MODE" = "--global" ]; then
  install_agents global
  install_skills global
  install_claude_md global
  install_ralph
  install_note
elif [ "$MODE" = "--project" ]; then
  echo "Target: $PROJECT_DIR"
  echo ""
  install_agents project
  install_skills project
  install_claude_md project
  install_ralph
  install_note
elif [ "$OBSIDIAN" -eq 0 ]; then
  usage
  exit 1
fi

if [ "$OBSIDIAN" -eq 1 ]; then
  install_obsidian
fi

echo ""
echo "Done!"
echo ""
echo "Next steps:"
echo "  • Restart Claude Code to pick up new skills and agents"
if [ "$OBSIDIAN" -eq 1 ]; then
  echo "  • Open a new terminal (or run: source ~/.bashrc) to activate VAULT_PATH"
  echo "  • Add a GitHub remote to your vault: cd \$VAULT_PATH && git remote add origin <url> && git push -u origin main"
fi
