#!/bin/bash
# Install fisher (fish plugin manager) and sync plugins from fish_plugins.
# Runs after fish is installed via Brewfile.

set -e

if ! command -v fish &> /dev/null; then
    echo "fish not installed yet, skipping fisher setup"
    exit 0
fi

# Install fisher if missing
if ! fish -c 'functions -q fisher' 2>/dev/null; then
    echo "Installing fisher..."
    fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
    echo "fisher installed."
fi

# Sync plugins from fish_plugins
echo "Syncing fish plugins..."
fish -c 'fisher update'
echo "fish plugins synced."
