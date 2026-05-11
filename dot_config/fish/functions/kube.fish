function kube
  if test -z "$argv[1]"
    if test -n "$KUBECONFIG"
      atuin dotfiles var delete KUBECONFIG &>/dev/null
      set -e KUBECONFIG
      echo "KUBECONFIG unset"
    else
      set -gx KUBECONFIG "/Users/$(whoami)/.kube/config"
      atuin dotfiles var set KUBECONFIG "/Users/$(whoami)/.kube/config" &>/dev/null
      echo "Switched to $(kubectl config current-context) Kubernetes context"
    end
  else
    set -gx KUBECONFIG "/Users/$(whoami)/.kube/$argv[1]/config"
    atuin dotfiles var set KUBECONFIG "/Users/$(whoami)/.kube/$argv[1]/config" &>/dev/null
    echo "Switched to Kubernetes context: $argv[1]"
  end
end
