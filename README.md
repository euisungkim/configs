# configs

Personal configuration files.

## Setup

```bash
git clone git@github.com-personal:euisungkim/configs.git ~/personal/configs
```

Then create symlinks:

```bash
# Neovim
ln -sf ~/personal/configs/nvim ~/.config/nvim

# Claude status line
ln -sf ~/personal/configs/claude/statusline-daily-cost.sh ~/.claude/statusline-daily-cost.sh

# Wezterm
ln -sf ~/personal/configs/.wezterm.lua ~/.wezterm.lua
```

## What's included

- `nvim/` - Neovim configuration
- `claude/` - Claude Code status line script
- `.wezterm.lua` - Wezterm terminal configuration

## What's NOT synced

- Shell configs (`.zshrc`, `.bashrc`) - work-specific
- Git configs (`.gitconfig*`) - kept local due to work/personal split
- SSH configs - machine-specific and sensitive
- Any work-specific configurations

These stay on the local machine only.
