#!/bin/bash
set -e
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
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
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
    gh auth login -h github.com -p https -w
    gh auth setup-git
fi

# Run the private script
gh api "repos/$REPO/contents/$SCRIPT?ref=$BRANCH" --jq '.content' | base64 -d | bash
