function fvi
  set -l selected (fzf -m --preview="bat --color=always {}")
  and nvim $selected
end
