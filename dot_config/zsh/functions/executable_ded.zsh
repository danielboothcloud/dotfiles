#!/bin/zsh
# Dotfile editor - Edit and apply chezmoi-managed files
# Fuzzy find a managed file, edit it with chezmoi, and apply changes

ded() {
  local selected

  selected=$(chezmoi managed -i files | fzf \
    --preview='bat --color=always --theme base16 "$HOME/$(printf "%s" {} | sed "s/^'\''//; s/'\''$//")"'
  ) || return

  # unquote once, for real
  selected=$(printf "%s\n" "$selected" | sed "s/^'\(.*\)'$/\1/")

  chezmoi edit "$HOME/$selected" && chezmoi apply "$HOME/$selected" -v --no-pager
}
