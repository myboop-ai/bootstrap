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
    sudo -v
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        BREW_SHELLENV='eval "$(/opt/homebrew/bin/brew shellenv)"'
    elif [ -f /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
        BREW_SHELLENV='eval "$(/usr/local/bin/brew shellenv)"'
    fi

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
    gh auth login -h github.com -p https -w -s admin:public_key
    gh auth setup-git
fi

# Download a file from GitHub (handles large files via blob API)
download_file() {
    local repo="$1"
    local path="$2"
    local branch="$3"
    local output="$4"

    # Get file metadata (may include content for small files, sha for large files)
    local metadata
    metadata=$(gh api "repos/$repo/contents/$path?ref=$branch" 2>/dev/null)

    # Try to get content directly (works for files under ~1MB)
    local content
    content=$(echo "$metadata" | jq -r '.content // empty')

    if [ -n "$content" ]; then
        echo "$content" | base64 -d > "$output"
    else
        # Large file - use blob API with the sha
        local sha
        sha=$(echo "$metadata" | jq -r '.sha')
        gh api "repos/$repo/git/blobs/$sha" --jq '.content' | base64 -d > "$output"
    fi
}

# Download and run the target file
if [[ "$SCRIPT" == *.zip ]]; then
    echo ""
    echo "Downloading..."
    TMPDIR=$(mktemp -d)
    download_file "$REPO" "$SCRIPT" "$BRANCH" "$TMPDIR/download.zip"
    echo "[$TMPDIR/download.zip]"
    unzip -q "$TMPDIR/download.zip" -d "$TMPDIR"
    rm "$TMPDIR/download.zip"

    # Find the extracted app
    APP_PATH=$(find "$TMPDIR" -maxdepth 1 -name "*.app" -type d | head -1)
    if [ -n "$APP_PATH" ]; then
        # Install app to /Applications
        APP_NAME=$(basename "$APP_PATH")
        echo "Installing $APP_NAME..."
        sudo rm -rf "/Applications/$APP_NAME"
        sudo cp -R "$APP_PATH" "/Applications/"

        # Pass branch to the app via temp file (app reads and deletes it)
        echo "$BRANCH" > /tmp/bootstrap-app-branch

        # Open the installed app
        echo "Opening $APP_NAME..."
        open "/Applications/$APP_NAME"
    else
        echo "Error: No .app found in zip"
        exit 1
    fi
else
    TMPDIR=$(mktemp -d)
    download_file "$REPO" "$SCRIPT" "$BRANCH" "$TMPDIR/script.sh"
    bash "$TMPDIR/script.sh"
fi
