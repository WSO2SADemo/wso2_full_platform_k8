#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "--- Installing dependencies for ai-ui-app-insurance ---"
cd "$SCRIPT_DIR"
npm install

echo "--- Done! ---"
echo "Run 'npm run dev' to start the app on port 3003"
echo ""
echo "Configure your API endpoints and key via the ⚙ Settings button in the app."
