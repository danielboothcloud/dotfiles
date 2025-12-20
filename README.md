# Dotfiles

Managed with chezmoi

**Stack:** Neovim (kickstart), Zsh (Oh My Zsh + Powerlevel10k), Ghostty, 100+ Homebrew packages

## Setup

```bash
brew install chezmoi
chezmoi init --apply --source=https://github.com/danielboothcloud/dotfiles.git
```

Ensure 1Password application and CLI are configured:
```
op account list
```

Auto-installs Homebrew, packages, Oh My Zsh, dotfiles, and scripts.

## Daily Usage

```bash
dotfiles edit ~/.zshrc  # Edit config (alias for chezmoi edit)
dotfiles diff           # See pending changes
dotfiles apply          # Apply changes
dotfiles update         # Pull from git and apply
```

