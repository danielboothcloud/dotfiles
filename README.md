# Dotfiles

Managed with chezmoi

Neovim (kickstart), Fish + Starship, Ghostty, Homebrew packages

## Setup

### Automated Setup 

**Important:** Ensure 1Password application and CLI are configured before running setup:
```bash
op account list
```

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


## Container

`packages/Containerfile` builds a portable Fedora image of the shell/editor/agent
workflow (fish + plugins, starship, mise, neovim with plugins/LSPs/parsers, pi,
tuicr, zellij, yazi, lazygit, atuin, kubectl/k9s/helm). 1Password-backed templates
(`env.fish`, gitconfigs, ssh, clones) are skipped via the `DOTFILES_CONTAINER`
block in `.chezmoiignore`, so no secrets are baked in.

```bash
cd packages
task container:build   # podman build -f packages/Containerfile -t dotfiles .
task container:run     # $PWD mounted at ~/work
```

Pushing a `v*` tag runs `.github/workflows/container.yml`, which builds amd64 and
arm64 with buildah on native runners and publishes a multi-arch image:

```bash
git tag v1.3.0 && git push origin v1.3.0
podman run --rm -it --userns=keep-id -v "$PWD:/home/danielbooth/work" ghcr.io/danielboothcloud/dotfiles:v1.3.0
```

Secrets and identity are supplied at runtime, e.g.
`podman run ... -e GIT_AUTHOR_EMAIL -e GIT_COMMITTER_EMAIL -e ANTHROPIC_API_KEY dotfiles`
(or `/login` inside pi; add `-v pi-auth:/home/danielbooth/.config/pi` to persist it).

## Daily Usage

```bash
dotfiles edit ~/.zshrc  # Edit config (alias for chezmoi edit)
dotfiles diff           # See pending changes
dotfiles apply          # Apply changes
dotfiles update         # Pull from git and apply
```

