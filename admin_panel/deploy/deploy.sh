#!/bin/bash
set -e

echo "Building WordRise Admin Panel..."
npm run build

echo "Archiving dist folder..."
tar -czvf admin_panel.tar.gz -C dist .

echo "Build complete. Ready to upload admin_panel.tar.gz to server."
echo "On server: extract to /var/www/wordrise/admin_panel/dist/"
