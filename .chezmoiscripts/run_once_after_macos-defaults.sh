#!/bin/bash
# This script runs once to set macOS defaults

set -e

# Only run on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Not running on macOS, skipping system defaults..."
    exit 0
fi

echo "Setting macOS defaults..."

# Dock settings
defaults write com.apple.dock orientation -string right
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-time-modifier -float 1.0
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 68
defaults write com.apple.dock wvous-tl-corner -int 2
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-tr-corner -int 2
defaults write com.apple.dock wvous-tr-modifier -int 0
defaults write com.apple.dock wvous-bl-corner -int 0
defaults write com.apple.dock wvous-bl-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 14
defaults write com.apple.dock wvous-br-modifier -int 0
killall Dock

echo "Dock settings applied and Dock restarted."

# Trackpad settings
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true

echo "Trackpad settings applied."
echo "macOS defaults configured successfully!"
