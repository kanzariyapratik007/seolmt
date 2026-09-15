#!/bin/bash
# =================================================================
# Safe AWS Automated Deployment Script for SEO System (Nginx & Apache compatible)
# (Designed to run safely alongside existing Nginx/Gunicorn/Postgres projects)
# =================================================================

set -e

echo "🚀 Starting automated setup for SEO System..."

# 1. Install required PHP dependencies
echo "📦 Installing PHP & PHP-FPM dependencies..."
sudo apt-get update -y
sudo apt-get install -y php php-fpm php-sqlite3 php-curl php-gd php-mbstring php-xml zip unzip python3 python3-pip || true

# Install Python Playwright for automated posting if needed
python3 -m pip install playwright || true
python3 -m playwright install || true

# 2. Set directory permissions
echo "🔒 Setting directory permissions..."
DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo chown -R www-data:www-data "$DIR_PATH"
sudo chmod -R 775 "$DIR_PATH"
sudo chmod -R 777 "$DIR_PATH/uploads" "$DIR_PATH/logs" 2>/dev/null || true
if [ -f "$DIR_PATH/seo_database.db" ]; then
    sudo chmod 666 "$DIR_PATH/seo_database.db"
fi

# 3. Create config.local.php if missing
if [ ! -f "$DIR_PATH/config.local.php" ]; then
    echo "⚙️ Creating default config.local.php..."
    cp "$DIR_PATH/config.local.php.example" "$DIR_PATH/config.local.php" 2>/dev/null || true
fi

# 4. Configure Nginx safely if Nginx is active
if systemctl is-active --quiet nginx; then
    echo "⚙️ Nginx detected! Configuring PHP-FPM location for SEO System..."
    PHP_SOCK=$(ls /var/run/php/php*-fpm.sock 2>/dev/null | head -n 1 || echo "")
    
    if [ -n "$PHP_SOCK" ]; then
        sudo bash -c "cat <<EOF > /etc/nginx/conf.d/seo-system.conf
location /seo-system {
    alias $DIR_PATH;
    index index.php index.html;
    try_files \$uri \$uri/ /seo-system/index.php?\$args;

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
        fastcgi_pass unix:$PHP_SOCK;
    }
}
EOF"
        sudo nginx -t && sudo systemctl reload nginx || echo "Nginx reload warning ignored"
    fi
fi

# 5. Create and start background queue systemd service (seo-worker)
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
echo "📍 Access path: http://YOUR_AWS_PUBLIC_IP/seo-system/"
echo "================================================="
