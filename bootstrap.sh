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

command -v gh &>/dev/null || { command -v brew &>/dev/null && brew install gh || { echo "Install gh: https://cli.github.com"; exit 1; }; }
gh auth status &>/dev/null || gh auth login -h github.com -p https -w
gh api "repos/$REPO/contents/$SCRIPT?ref=$BRANCH" --jq '.content' | base64 -d | bash
