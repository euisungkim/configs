# configs

Personal configuration files.

## Setup

```bash
git clone git@github.com-personal:euisungkim/configs.git ~/configs
```

Then create symlinks as needed:

```bash
# Example: symlink zsh config
ln -sf ~/configs/.zshrc ~/.zshrc

# Example: symlink nvim config
ln -sf ~/configs/nvim ~/.config/nvim
```

## What's NOT synced

- Git configs (`.gitconfig*`) - kept local due to work/personal split
- SSH configs - machine-specific and sensitive
- Any work-specific configurations

These stay on the local machine only.
