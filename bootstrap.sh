#!/bin/bash
set -e

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo ""
    echo "This script currently only supports macOS."
    echo ""
    exit 1
fi

if [ -z "$1" ] || [ -z "$2" ]; then
    echo ""
    echo "Error: The command appears incomplete."
    echo "Please copy the full command and try again."
    echo ""
    exit 1
fi

REPO="$1"
SCRIPT="$2"
BRANCH="${3:-main}"

# Install Homebrew if needed
if ! command -v brew &>/dev/null; then
    echo ""
    echo "Installing Homebrew (you may be prompted for your password)..."
    echo ""
    # Cache sudo credentials before running Homebrew in non-interactive mode
    sudo -v
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add brew to PATH for this session and future sessions
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        BREW_SHELLENV='eval "$(/opt/homebrew/bin/brew shellenv)"'
    elif [ -f /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
        BREW_SHELLENV='eval "$(/usr/local/bin/brew shellenv)"'
    fi

    # Add to shell profile if not already there
    SHELL_PROFILE="$HOME/.zprofile"
    if [ -f "$HOME/.bash_profile" ] && [ ! -f "$HOME/.zprofile" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
    fi

    if ! grep -q 'brew shellenv' "$SHELL_PROFILE" 2>/dev/null; then
        echo "" >> "$SHELL_PROFILE"
        echo '# Homebrew' >> "$SHELL_PROFILE"
        echo "$BREW_SHELLENV" >> "$SHELL_PROFILE"
    fi
fi

# Install gh if needed
if ! command -v gh &>/dev/null; then
    echo "Installing GitHub CLI..."
    brew install gh
fi

# Auth if needed
if ! gh auth status &>/dev/null; then
    echo ""
    echo "To continue, you'll need to sign in to GitHub."
    echo ""
    echo "A code will appear below. Your browser will open - paste the code there."
    echo ""
    gh auth login -h github.com -p https -w -s admin:public_key
    gh auth setup-git
fi

# Run the private script
gh api "repos/$REPO/contents/$SCRIPT?ref=$BRANCH" --jq '.content' | base64 -d | bash
