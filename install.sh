#!/bin/bash
set -e

MODE=${1:-""}
PROJECT_PATH=""
OBSIDIAN=0

usage() {
  echo "Usage: bash install.sh [--global | --project [--path <dir>]] [--obsidian]"
  echo ""
  echo "  --global        Install agents, skills, and CLAUDE.md to ~/.claude/ (affects all projects)"
  echo "  --project       Install agents and skills into a project directory"
  echo "  --path <dir>    Target directory for project install (default: current directory)"
  echo "  --obsidian      Also set up Obsidian vault integration (combinable with --global or --project)"
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
    --global)   MODE="--global"; shift ;;
    --project)  MODE="--project"; shift ;;
    --path)     PROJECT_PATH="$2"; shift 2 ;;
    --obsidian) OBSIDIAN=1; shift ;;
    --help|-h)  usage; exit 0 ;;
    *)          echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$MODE" ] && [ "$OBSIDIAN" -eq 0 ]; then
  echo "Where would you like to install?"
  echo "  1) Global (~/.claude/) — available in all projects"
  echo "  2) Project (.claude/)  — specific project directory"
  read -rp "Choose [1/2]: " choice
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

  # Prompt for vault path
  local default_vault="$HOME/vault"
  read -rp "Vault path [default: $default_vault]: " input_vault
  local vault_path
  if [ -n "$input_vault" ]; then
    vault_path="$(realpath -m "$input_vault")"
  else
    vault_path="$(realpath -m "$default_vault")"
  fi

  # Write env vars to ~/.bashrc (idempotent: replace existing exports)
  local bashrc="$HOME/.bashrc"
  if grep -qF "export VAULT_PATH=" "$bashrc" 2>/dev/null; then
    sed -i "s|export VAULT_PATH=.*|export VAULT_PATH=\"$vault_path\"|" "$bashrc"
  else
    echo "export VAULT_PATH=\"$vault_path\"" >> "$bashrc"
  fi
  if grep -qF "export CLAUDE_OBSIDIAN_DIR=" "$bashrc" 2>/dev/null; then
    sed -i "s|export CLAUDE_OBSIDIAN_DIR=.*|export CLAUDE_OBSIDIAN_DIR=\"$obsidian_dir\"|" "$bashrc"
  else
    echo "export CLAUDE_OBSIDIAN_DIR=\"$obsidian_dir\"" >> "$bashrc"
  fi
  echo "[OK] VAULT_PATH=$vault_path written to ~/.bashrc"
  echo "[OK] CLAUDE_OBSIDIAN_DIR=$obsidian_dir written to ~/.bashrc"

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

echo "Installing better-claude..."
echo ""

if [ "$MODE" = "--global" ]; then
  install_agents global
  install_skills global
  install_claude_md global
  install_ralph
elif [ "$MODE" = "--project" ]; then
  echo "Target: $PROJECT_DIR"
  echo ""
  install_agents project
  install_skills project
  install_claude_md project
  install_ralph
elif [ "$OBSIDIAN" -eq 0 ]; then
  usage
  exit 1
fi

if [ "$OBSIDIAN" -eq 1 ]; then
  install_obsidian
fi

echo ""
echo "Done! Restart Claude Code to pick up new skills and agents."
if [ "$OBSIDIAN" -eq 1 ]; then
  echo "Run: source ~/.bashrc  (or open a new terminal) to activate VAULT_PATH and CLAUDE_OBSIDIAN_DIR"
fi
