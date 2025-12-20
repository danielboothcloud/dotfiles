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
6. Set up atuin with credentials from 1Password
7. Sync environment variables from 1Password to atuin
8. Apply all dotfiles (chezmoi installs remaining packages via Brewfile and applies configs with env vars available)

### Manual Setup

If you prefer to set up manually:

```bash
# Install chezmoi
brew install chezmoi

# Initialize repository (don't apply yet)
chezmoi init danielboothcloud/dotfiles

# Install all packages including atuin
brew bundle install --file="$(chezmoi source-path)/packages/Brewfile"

# Set up atuin (requires 1Password CLI configured)
"$(chezmoi source-path)/.chezmoiscripts/run_once_after_setup-atuin.sh"

# Sync 1Password secrets to atuin
chezmoi apply ~/.env
"$(chezmoi source-path)/bin/executable_atuin-1p-sync"

# Apply all dotfiles (now with env vars available)
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

