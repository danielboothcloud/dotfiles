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

`packages/container/Containerfile` builds a slim Fedora image (on the sundae-sandbox base)
with fd, ripgrep, pi, neovim (with plugins/LSPs/parsers), rootless podman and osewa/sshd.
Only the pi, nvim and mise configs are applied; the global mise tools are not installed,
so run `mise install` inside the container to reconcile them. No secrets are baked in.

```bash
# From the repo root; the token only avoids GitHub API rate limits while mise resolves "latest".
GITHUB_TOKEN="$(gh auth token)" podman build -f packages/container/Containerfile \
  --secret id=github_token,env=GITHUB_TOKEN -t dotfiles .
podman run --rm -it --userns=keep-id:uid=10001,gid=10001 -e COLORTERM=truecolor \
  --device /dev/fuse --security-opt label=disable -v "$PWD:/home/danielbooth/work" dotfiles
```

Rootless Podman works inside the container (Podman-in-Podman, no `--privileged`);
it needs `--device /dev/fuse --security-opt label=disable` on `podman run`.

`.github/workflows/container.yml` builds amd64 with buildah and publishes the
image to GHCR:

- `v*` tag push → `:v1.3.0` and `:latest`
- branch push → `:<branch>-<short-sha>` and `:<branch>` (e.g. `develop-480e5df`, `develop`;
  `/` in branch names becomes `-`)

```bash
git tag v1.3.0 && git push origin v1.3.0
podman run --rm -it --userns=keep-id:uid=10001,gid=10001 --device /dev/fuse --security-opt label=disable \
  -v "$PWD:/home/danielbooth/work" ghcr.io/danielboothcloud/dotfiles:v1.3.0
```

Secrets and identity are supplied at runtime, e.g.
`podman run ... -e GIT_AUTHOR_EMAIL -e GIT_COMMITTER_EMAIL -e ANTHROPIC_API_KEY -e CURSOR_API_KEY dotfiles`
(or `/login` inside pi; add `-v pi-auth:/home/danielbooth/.config/pi` to persist it).

## Daily Usage

```bash
dotfiles edit ~/.zshrc  # Edit config (alias for chezmoi edit)
dotfiles diff           # See pending changes
dotfiles apply          # Apply changes
dotfiles update         # Pull from git and apply
```

