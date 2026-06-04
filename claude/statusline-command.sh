#!/usr/bin/env bash
# Claude Code status line — mirrors Powerlevel10k classic style
# Shows: user@host  cwd  [git branch]  model  context%
# Enterprise-ready: displays context usage to monitor model efficiency

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

# Colors (ANSI — terminal will dim them in the status line)
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
RESET='\033[0m'

# Shorten home directory to ~
short_cwd=$(echo "$cwd" | sed "s|^$HOME|~|")

# Build parts
user_host="${CYAN}$(whoami)@$(hostname -s)${RESET}"
dir_part="${GREEN}${short_cwd}${RESET}"

git_part=""
if [ -n "$git_branch" ]; then
  git_part=" ${YELLOW}(${git_branch})${RESET}"
fi

model_part=""
if [ -n "$model" ]; then
  model_part=" ${MAGENTA}[${model}]${RESET}"
fi

ctx_part=""
if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")
  if [ "$used_int" -ge 80 ]; then
    ctx_part=" ${RED}ctx:${used_int}%${RESET}"
  else
    ctx_part=" ctx:${used_int}%"
  fi
fi

printf "${user_host}  ${dir_part}${git_part}${model_part}${ctx_part}"
