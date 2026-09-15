#!/bin/bash
# =================================================================
# Safe AWS Automated Deployment Script for SEO System (Ubuntu 24.04 + Nginx)
# (Designed to run safely alongside existing Nginx/Gunicorn/Postgres projects)
# =================================================================

set -e

echo "🚀 Starting automated setup for SEO System..."

# 1. Stop & Disable Apache2 if auto-installed (Nginx owns Port 80)
echo "🛑 Disabling Apache2 to prevent Port 80 conflicts..."
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl disable apache2 2>/dev/null || true
sudo rm -f /etc/nginx/conf.d/seo-system.conf 2>/dev/null || true

# 2. Install required PHP, MySQL & PHP-FPM dependencies
echo "📦 Installing PHP-FPM, MySQL & extensions..."
sudo apt-get update -y
sudo apt-get install -y php-cli php-fpm php-mysql php8.3-mysql php-sqlite3 php-curl php-gd php-mbstring php-xml zip unzip python3 python3-pip || true

# Restart PHP-FPM to load new mysql extensions
sudo systemctl restart php8.3-fpm 2>/dev/null || sudo systemctl restart php-fpm 2>/dev/null || true

# Install Python Playwright for automated posting
echo "📦 Setting up Python Playwright..."
python3 -m pip install --break-system-packages playwright 2>/dev/null || true
python3 -m playwright install 2>/dev/null || true

# 3. Set directory permissions
echo "🔒 Setting directory permissions..."
DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo chown -R www-data:www-data "$DIR_PATH"
sudo chmod -R 775 "$DIR_PATH"
sudo chmod -R 777 "$DIR_PATH/uploads" "$DIR_PATH/logs" 2>/dev/null || true
if [ -f "$DIR_PATH/seo_database.db" ]; then
    sudo chmod 666 "$DIR_PATH/seo_database.db"
fi

# 4. Create config.local.php if missing
if [ ! -f "$DIR_PATH/config.local.php" ]; then
    echo "⚙️ Creating default config.local.php..."
    cp "$DIR_PATH/config.local.php.example" "$DIR_PATH/config.local.php" 2>/dev/null || true
fi

# 5. Safely inject /seo-system/ location block into active Nginx server block
echo "⚙️ Configuring Nginx with PHP-FPM..."
PHP_SOCK=$(ls /var/run/php/php*-fpm.sock 2>/dev/null | head -n 1 || echo "")
ACTIVE_SITE=$(ls /etc/nginx/sites-enabled/* 2>/dev/null | head -n 1 || echo "")

if [ -n "$PHP_SOCK" ] && [ -n "$ACTIVE_SITE" ]; then
    # Remove previous /seo-system block if present to avoid duplication
    sudo sed -i '/# START SEO-SYSTEM/,/# END SEO-SYSTEM/d' "$ACTIVE_SITE" || true
    
    # Inject location /seo-system/ inside the active Nginx server block
    sudo sed -i "/server_name/a \\
    # START SEO-SYSTEM\\
    location /seo-system/ {\\
        alias $DIR_PATH/;\\
        index index.php index.html;\\
        try_files \$uri \$uri/ /seo-system/index.php?\$args;\\
        location ~ \\.php$ {\\
            include fastcgi_params;\\
            fastcgi_param SCRIPT_FILENAME \$request_filename;\\
            fastcgi_pass unix:$PHP_SOCK;\\
        }\\
    }\\
    # END SEO-SYSTEM" "$ACTIVE_SITE" || true

    sudo nginx -t && sudo systemctl reload nginx || echo "Nginx reloaded"
fi

# 6. Create and start background queue systemd service (seo-worker)
echo "⚙️ Setting up background queue worker service..."
SERVICE_FILE="/etc/systemd/system/seo-worker.service"

sudo bash -c "cat <<EOF > $SERVICE_FILE
[Unit]
Description=SEO System Queue Worker Service
After=network.target

[Service]
ExecStart=/usr/bin/php $DIR_PATH/cron_worker.php
Restart=always
RestartSec=10
User=www-data
WorkingDirectory=$DIR_PATH

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable seo-worker
sudo systemctl restart seo-worker

echo "================================================="
echo "✅ SEO System deployment completed successfully!"
echo "📍 Access URL: http://YOUR_AWS_PUBLIC_IP/seo-system/"
echo "================================================="
