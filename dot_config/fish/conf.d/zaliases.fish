status is-interactive; or exit 0

alias istio="istioctl"
alias vi="nvim"
alias pm="pnpm"
alias px="pnpx"
alias docker="podman"
alias dotfiles="chezmoi"
alias ll="eza --color=always --long --git --icons=always --no-user"
alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"
alias cat="bat --paging never --style=changes --theme base16"
alias less="bat --paging always --style=changes --theme base16"
alias top="btop"
alias todo="togo"

alias assume="source (brew --prefix)/bin/assume.fish"

abbr -e gup
abbr -a kb "kubectl"
abbr -a tf "terraform"
abbr -a mk "minikube"
abbr -a tg "terragrunt"
abbr -a tpe "telepresence"
