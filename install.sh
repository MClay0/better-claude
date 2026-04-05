#!/bin/bash
set -e

MODE=${1:-""}

usage() {
  echo "Usage: bash install.sh [--global | --project]"
  echo ""
  echo "  --global   Install agents, skills, and CLAUDE.md to ~/.claude/ (affects all projects)"
  echo "  --project  Install agents and skills into .claude/ in the current directory"
  echo ""
  echo "If no flag is provided, you will be prompted to choose."
}

if [ "$MODE" = "--help" ] || [ "$MODE" = "-h" ]; then
  usage
  exit 0
fi

if [ -z "$MODE" ]; then
  echo "Where would you like to install?"
  echo "  1) Global (~/.claude/) — available in all projects"
  echo "  2) Project (.claude/)  — current directory only"
  read -rp "Choose [1/2]: " choice
  case "$choice" in
    1) MODE="--global" ;;
    2) MODE="--project" ;;
    *) echo "Invalid choice."; exit 1 ;;
  esac
fi

install_agents() {
  local dest="$1"
  if [ -d "agency-agents" ]; then
    if [ "$dest" = "global" ]; then
      mkdir -p ~/.claude/agents
      cd agency-agents && bash scripts/install.sh --tool claude-code 2>&1 | grep -E "OK|Error|agents" && cd ..
    else
      mkdir -p .claude/agents
      cp -r agency-agents/engineering agency-agents/design agency-agents/marketing \
            agency-agents/product agency-agents/testing agency-agents/specialized \
            .claude/agents/ 2>/dev/null || true
      echo "[OK] Agents -> .claude/agents/"
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
    target=.claude/skills
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
    if [ -f .claude/CLAUDE.md ] || [ -f CLAUDE.md ]; then
      echo ""
      echo "Warning: A CLAUDE.md already exists in this project."
      read -rp "Overwrite? [y/N]: " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Skipped CLAUDE.md"
        return
      fi
    fi
    mkdir -p .claude
    cp CLAUDE.md .claude/CLAUDE.md
    echo "[OK] CLAUDE.md -> .claude/CLAUDE.md"
  fi
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
  install_agents project
  install_skills project
  install_claude_md project
  install_ralph
else
  usage
  exit 1
fi

echo ""
echo "Done! Restart Claude Code to pick up new skills and agents."
