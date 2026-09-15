#!/bin/bash
# =================================================================
# Safe AWS Automated Deployment Script for SEO System (Ubuntu 24.04 + Nginx + MySQL)
# (Designed to run safely alongside existing Nginx/Gunicorn/Postgres projects)
# =================================================================

set -e

echo "🚀 Starting automated setup for SEO System..."

# 0. Create 1GB Swap file if missing (Prevents AWS OOM Memory Killer on 1GB RAM EC2)
if [ ! -f /swapfile ]; then
    echo "💾 Creating 1GB Swap memory to prevent RAM exhaustion..."
    sudo fallocate -l 1G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024 2>/dev/null || true
    sudo chmod 600 /swapfile 2>/dev/null || true
    sudo mkswap /swapfile 2>/dev/null || true
    sudo swapon /swapfile 2>/dev/null || true
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab 2>/dev/null || true
    fi
fi

# Clean broken MySQL state if unconfigured
if ! systemctl is-active --quiet mysql 2>/dev/null; then
    sudo systemctl stop mysql 2>/dev/null || true
    sudo rm -rf /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring 2>/dev/null || true
fi

# 1. Stop & Disable Apache2 if auto-installed (Nginx owns Port 80)
echo "🛑 Disabling Apache2 to prevent Port 80 conflicts..."
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl disable apache2 2>/dev/null || true
sudo rm -f /etc/nginx/conf.d/seo-system.conf 2>/dev/null || true

# 2. Install MySQL Server & PHP-FPM dependencies
echo "📦 Installing MySQL Server, PHP-FPM & extensions..."
sudo apt-get update -y
sudo apt-get install -y mysql-server php-cli php-fpm php-mysql php8.3-mysql php-sqlite3 php-curl php-gd php-mbstring php-xml zip unzip python3 python3-pip || true

# Fix half-initialized/corrupted MySQL datadir if service failed
if ! systemctl is-active --quiet mysql 2>/dev/null; then
    echo "🧹 Initializing fresh MySQL instance..."
    sudo systemctl stop mysql 2>/dev/null || true
    sudo rm -rf /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring 2>/dev/null || true
    sudo mkdir -p /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring 2>/dev/null || true
    sudo chown -R mysql:mysql /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring 2>/dev/null || true
    sudo mysqld --initialize-insecure --user=mysql 2>/dev/null || true
    sudo systemctl start mysql 2>/dev/null || true
    sudo dpkg --configure -a || true
fi

# Start MySQL Service
sudo systemctl enable mysql 2>/dev/null || true
sudo systemctl start mysql 2>/dev/null || true

# Setup MySQL users & permissions (Fixes Ubuntu socket / auth_socket access denied for www-data)
echo "⚙️ Configuring MySQL Database & Permissions..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS seo_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
sudo mysql -e "CREATE USER IF NOT EXISTS 'seo_user'@'localhost' IDENTIFIED BY 'seo_pass_123';" 2>/dev/null || true
sudo mysql -e "ALTER USER 'seo_user'@'localhost' IDENTIFIED BY 'seo_pass_123';" 2>/dev/null || true
sudo mysql -e "CREATE USER IF NOT EXISTS 'seo_user'@'127.0.0.1' IDENTIFIED BY 'seo_pass_123';" 2>/dev/null || true
sudo mysql -e "ALTER USER 'seo_user'@'127.0.0.1' IDENTIFIED BY 'seo_pass_123';" 2>/dev/null || true
sudo mysql -e "GRANT ALL PRIVILEGES ON seo_system.* TO 'seo_user'@'localhost';" 2>/dev/null || true
sudo mysql -e "GRANT ALL PRIVILEGES ON seo_system.* TO 'seo_user'@'127.0.0.1';" 2>/dev/null || true
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';" 2>/dev/null || true
sudo mysql -e "CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '';" 2>/dev/null || true
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;" 2>/dev/null || true
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;" 2>/dev/null || true
sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true

# 3. Set directory permissions
echo "🔒 Setting directory permissions..."
DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo chown -R www-data:www-data "$DIR_PATH"
sudo chmod -R 775 "$DIR_PATH"
sudo chmod -R 777 "$DIR_PATH/uploads" "$DIR_PATH/logs" 2>/dev/null || true

# 4. Create and update config.local.php safely via PHP
echo "⚙️ Creating & updating config.local.php..."
sudo php -r "
\$path = '$DIR_PATH/config.local.php';
\$example = '$DIR_PATH/config.local.php.example';
\$config = file_exists(\$path) ? @include(\$path) : [];
if (!is_array(\$config)) \$config = file_exists(\$example) ? @include(\$example) : [];
if (!is_array(\$config)) \$config = [];
\$config['DB_HOST'] = '127.0.0.1';
\$config['DB_USER'] = 'seo_user';
\$config['DB_PASS'] = 'seo_pass_123';
\$config['DB_NAME'] = 'seo_system';
if (empty(\$config['SITE_URL']) || strpos(\$config['SITE_URL'], 'localhost') !== false) {
    \$config['SITE_URL'] = 'http://13.206.147.70/seo-system';
}
file_put_contents(\$path, \"<?php\nreturn \" . var_export(\$config, true) . \";\n\");
" 2>/dev/null || true

# Import database schema if database.sql exists
if [ -f "$DIR_PATH/database.sql" ]; then
    echo "📥 Importing database.sql schema..."
    sudo mysql < "$DIR_PATH/database.sql" 2>/dev/null || sudo mysql -u seo_user -pseo_pass_123 < "$DIR_PATH/database.sql" 2>/dev/null || true
fi

# Seed default admin account if table empty
sudo php -r "require_once '$DIR_PATH/config.php'; \$db=getDB(); \$cnt=\$db->query('SELECT COUNT(*) FROM users')->fetchColumn(); if(\$cnt==0) { \$h=password_hash('admin123', PASSWORD_BCRYPT); \$db->exec(\"INSERT INTO users (username, password, email, role) VALUES ('admin', '\$h', 'admin@seo-system.local', 'admin')\"); }" 2>/dev/null || true

# Restart PHP-FPM to load new mysql extensions
sudo systemctl restart php8.3-fpm 2>/dev/null || sudo systemctl restart php-fpm 2>/dev/null || true

# Install Python Playwright for automated posting
echo "📦 Setting up Python Playwright..."
python3 -m pip install --break-system-packages playwright 2>/dev/null || true
python3 -m playwright install 2>/dev/null || true

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
