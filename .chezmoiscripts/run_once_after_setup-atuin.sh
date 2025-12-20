#!/bin/bash
# This script runs once to configure atuin with credentials from 1Password

set -e

echo "Configuring atuin..."

# Check if atuin is installed
if ! command -v atuin &> /dev/null; then
    echo "Error: atuin is not installed. Install it via Homebrew first."
    exit 1
fi

# Check if 1Password CLI is installed
if ! command -v op &> /dev/null; then
    echo "Error: 1Password CLI (op) is not installed."
    exit 1
fi

# Check if already logged in
if atuin status 2>&1 | grep -q "Username:"; then
    echo "Atuin is already configured and logged in, skipping setup..."
    exit 0
fi

# Retrieve credentials from 1Password
echo "Retrieving atuin credentials from 1Password..."

ATUIN_USERNAME=$(op item get Atuin --fields label=username 2>&1)
if [[ $? -ne 0 ]] || [[ -z "$ATUIN_USERNAME" ]]; then
    echo "Error: Failed to retrieve atuin username from 1Password"
    echo "Please ensure you're signed into 1Password CLI with: op signin"
    exit 1
fi

ATUIN_PASSWORD=$(op item get Atuin --fields label=password --reveal 2>&1)
if [[ $? -ne 0 ]] || [[ -z "$ATUIN_PASSWORD" ]]; then
    echo "Error: Failed to retrieve atuin password from 1Password"
    exit 1
fi

ATUIN_KEY=$(op item get Atuin --fields label=Key --reveal 2>&1)
if [[ $? -ne 0 ]] || [[ -z "$ATUIN_KEY" ]]; then
    echo "Error: Failed to retrieve atuin encryption key from 1Password"
    exit 1
fi

# Login to atuin
echo "Logging into atuin..."
if atuin login -u "${ATUIN_USERNAME}" -p "${ATUIN_PASSWORD}" -k "${ATUIN_KEY}"; then
    echo "Atuin login successful!"

    # Run initial sync
    echo "Running initial sync..."
    if atuin sync; then
        echo "Atuin sync completed successfully!"
    else
        echo "Warning: Initial sync failed, but you can run 'atuin sync' manually later"
    fi
else
    echo "Error: Failed to login to atuin"
    echo "You can try manually with: atuin login -u ${ATUIN_USERNAME}"
    exit 1
fi

echo "Atuin configuration complete!"
