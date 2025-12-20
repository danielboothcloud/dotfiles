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
5. Install atuin (required for environment variable management)
6. Apply dotfiles which automatically:
   - Logs into atuin with credentials from 1Password and syncs env vars
   - Installs all packages via Brewfile
   - Applies all configs with environment variables available
   - Runs macOS defaults and other setup scripts

### Manual Setup

If you prefer to set up manually:

```bash
# Install chezmoi
brew install chezmoi

# Initialize repository
chezmoi init danielboothcloud/dotfiles

# Install atuin (needed for env var management before applying dotfiles)
brew install atuin

# Apply all dotfiles (this automatically sets up atuin, installs packages, and applies configs)
chezmoi apply
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

