#!/bin/zsh

kube() {
  if [[ -z "$1" ]]; then
    if [[ -n "$KUBECONFIG" ]]; then
      atuin dotfiles var delete KUBECONFIG &>/dev/null
      unset KUBECONFIG
      echo "KUBECONFIG unset"
    else
      export KUBECONFIG="/Users/$(whoami)/.kube/config"
      atuin dotfiles var set KUBECONFIG '/Users/danielbooth/.kube/config' &>/dev/null
      echo "Switched to $(kubectl config current-context) Kubernetes context"
    fi
  else
    export KUBECONFIG="/Users/$(whoami)/.kube/$1/config"
    atuin dotfiles var set KUBECONFIG '/Users/danielbooth/.kube/$1/config' &>/dev/null
    echo "Switched to Kubernetes context: $1"
  fi
}

