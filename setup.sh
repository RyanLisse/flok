#!/bin/bash
set -euo pipefail

# Setup script for Pigeon project
# Run from any directory with access to ~/Developer

STAGING="$HOME/clawd/staging/pigeon"
REPO_DIR="$HOME/Developer/OutlookCLI"

echo "=== Step 1: Clone repo ==="
cd ~/Developer
if [ -d OutlookCLI ]; then
    echo "OutlookCLI already exists, pulling latest..."
    cd OutlookCLI && git pull
else
    gh repo clone RyanLisse/OutlookCLI
    cd OutlookCLI
fi

echo "=== Step 2: Rename repo to Pigeon ==="
gh repo rename Pigeon --yes 2>/dev/null || echo "Rename may have already happened or needs manual intervention"

echo "=== Step 3: Copy staged files ==="
# Remove old files (keep .git)
find . -maxdepth 1 ! -name '.git' ! -name '.' -exec rm -rf {} +

# Copy everything from staging
cp -R "$STAGING"/* .
cp "$STAGING"/.gitignore .

echo "=== Step 4: Generate icon ==="
uv run ~/clawd/skills/nano-banana-pro/scripts/generate_image.py \
    --prompt "App icon for 'Pigeon' — a cute stylized carrier pigeon holding a small envelope in its beak, minimal flat design, bold colors (teal and orange accents on white), rounded square app icon shape, modern vector style, no text" \
    --filename "$REPO_DIR/icon.png" \
    --resolution 1K || echo "Icon generation failed, continuing without icon"

echo "=== Step 5: Remove setup script from repo ==="
rm -f setup.sh

echo "=== Step 6: Commit and push ==="
git add -A
git commit -m "feat: initial agent-native architecture with Peekaboo pattern

- 🐦 Renamed to Pigeon (carrier pigeon for Microsoft 365)
- Swift 6 with StrictConcurrency, ExistentialAny
- Core: GraphClient with retry/pagination, device code auth, Keychain storage
- MCP: 20+ tools with handler pattern, resources, prompts, escape hatch
- CLI: auth, mail, serve commands
- Agent-native: resources, prompts, graph-api escape hatch, completion signals, read-only mode"

git push

echo "=== Step 7: Verify ==="
git status

echo "=== Done! ==="
