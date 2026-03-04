#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/insurance-customer-portal"

echo "--- Installing dependencies for insurance-customer-portal ---"
cd "$APP_DIR"
npm install

echo "--- Done! ---"
echo "Run 'npm run dev' inside insurance-customer-portal to start the app on port 3002"
