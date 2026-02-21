#!/bin/sh
set -eu
PLUG_DIR=/var/www/html/plugins-enabled
mkdir -p "$PLUG_DIR"
# Remove any stale numeric stub wrappers
# find "$PLUG_DIR" -maxdepth 1 -type f -name '0*-auto-login.php' -delete || true
# Copy plugin source (mounted read-only from host)
cp /plugins-src/auto-login.php "$PLUG_DIR/auto-login.php"
chmod 0644 "$PLUG_DIR/auto-login.php"

# Start original image entrypoint+server
exec entrypoint.sh docker-php-entrypoint php -S [::]:8080 -t /var/www/html
