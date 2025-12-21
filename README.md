# Dotfiles

Managed with chezmoi

**Stack:** Neovim (kickstart), Zsh (Oh My Zsh + Powerlevel10k), Ghostty, 100+ Homebrew packages

## Setup

### Automated Setup (Recommended)

Run the init script which handles the complete setup in the correct order:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/danielboothcloud/dotfiles/main/init)
```

This will:
1. Install Homebrew (if not present)
2. Install 1Password CLI and verify configuration
3. Install chezmoi
4. Clone the dotfiles repository
5. Apply dotfiles which automatically:
   - Installs all packages via Brewfile (including atuin)
   - Applies all configs (reads secrets directly from 1Password)
   - Sets up atuin with credentials from 1Password
   - Runs macOS defaults and other setup scripts

### Manual Setup

If you prefer to set up manually:

```bash
# Install chezmoi
brew install chezmoi

# Initialize and apply dotfiles
chezmoi init --apply danielboothcloud/dotfiles
```

**Important:** Ensure 1Password application and CLI are configured before running setup:
```bash
op account list
```

## Daily Usage

```bash
dotfiles edit ~/.zshrc  # Edit config (alias for chezmoi edit)
dotfiles diff           # See pending changes
dotfiles apply          # Apply changes
dotfiles update         # Pull from git and apply
```

