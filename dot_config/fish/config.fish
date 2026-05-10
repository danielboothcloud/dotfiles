# PATH setup
fish_add_path /opt/homebrew/bin
fish_add_path $HOME/bin
fish_add_path $HOME/.local/bin
fish_add_path /usr/local/bin
fish_add_path $HOME/go/bin
fish_add_path $HOME/Library/pnpm
fish_add_path $HOME/.krew/bin

# Environment variables
set -gx GOBIN $HOME/go/bin
set -gx PNPM_HOME $HOME/Library/pnpm

# Load .env if it exists (fish syntax, populated by chezmoi from 1Password)
if test -f ~/.env
  source ~/.env
end

# Inside an SSH session, prefer ghostty terminfo if the remote has it,
# else fall back to xterm-256color
if test -n "$SSH_CONNECTION"
  if infocmp ghostty &>/dev/null
    set -gx TERM ghostty
  else
    set -gx TERM xterm-256color
  end
end

set -g __fish_start_time (command perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000')

if status is-interactive
  # When local TERM is ghostty, downgrade outbound ssh to xterm-256color
  # so remote hosts without ghostty terminfo don't choke
  if test "$TERM" = "ghostty"; or test "$TERM" = "xterm-ghostty"
    function ssh --wraps=ssh
      env TERM=xterm-256color command ssh $argv
    end
  end

  # Auto-mosh into bluefin (mosh-off / mosh-on to toggle persistently)
  alias mosh-off='touch ~/.no-automosh; and echo "auto-mosh disabled"'
  alias mosh-on='rm -f ~/.no-automosh; and echo "auto-mosh enabled"'

  if test -z "$SSH_CONNECTION"; and not test -e ~/.no-automosh
    mosh bluefin-vm
  end

  starship init fish | source
  atuin init fish | source
  zoxide init fish --cmd cd | source

  function __fish_startup_time --on-event fish_prompt
    set -l now (command perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000')
    set -l elapsed (math $now - $__fish_start_time)
    echo "── fish startup: {$elapsed}ms ──"
    functions -e __fish_startup_time
  end
end

mise activate fish | source
