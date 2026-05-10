function ded
  set -l selected (chezmoi managed -i files | fzf \
    --preview='bat --color=always --theme base16 "$HOME/{}"')
  or return

  chezmoi edit "$HOME/$selected"; and chezmoi apply "$HOME/$selected" -v --no-pager
end
