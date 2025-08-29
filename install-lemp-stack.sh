#!/bin/bash

# LEMP Stack Installation Script (Linux, Nginx, MariaDB, PHP 8.3, phpMyAdmin)
# Author: Auto-generated installation script
# Date: $(date)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        error "Cannot detect OS. This script supports Ubuntu/Debian systems."
    fi
    
    log "Detected OS: $OS $VER"
}

# Update system
update_system() {
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release
}

# Install Nginx
install_nginx() {
    log "Installing Nginx..."
    sudo apt install -y nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    # Configure firewall
    sudo ufw allow 'Nginx Full' 2>/dev/null || true
    
    log "Nginx installed and started successfully"
}

# Install PHP 8.3
install_php() {
    log "Installing PHP 8.3..."
    
    # Add PHP repository
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update
    
    # Install PHP 8.3 and common extensions
    sudo apt install -y php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring \
        php8.3-xml php8.3-xmlrpc php8.3-soap php8.3-intl php8.3-zip php8.3-cli \
        php8.3-common php8.3-opcache php8.3-readline php8.3-json php8.3-bcmath \
        php8.3-bz2 php8.3-imagick php8.3-dev
    
    # Start and enable PHP-FPM
    sudo systemctl start php8.3-fpm
    sudo systemctl enable php8.3-fpm
    
    # Configure PHP
    sudo sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/8.3/fpm/php.ini
    sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' /etc/php/8.3/fpm/php.ini
    sudo sed -i 's/post_max_size = 8M/post_max_size = 100M/' /etc/php/8.3/fpm/php.ini
    sudo sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.3/fpm/php.ini
    sudo sed -i 's/max_input_vars = 1000/max_input_vars = 3000/' /etc/php/8.3/fpm/php.ini
    
    sudo systemctl restart php8.3-fpm
    
    log "PHP 8.3 installed and configured successfully"
}

# Install MariaDB
install_mariadb() {
    log "Installing MariaDB latest..."
    
    # Install MariaDB
    sudo apt install -y mariadb-server mariadb-client
    
    # Start and enable MariaDB
    sudo systemctl start mariadb
    sudo systemctl enable mariadb
    
    # Secure MariaDB installation
    log "Securing MariaDB installation..."
    
    # Generate random root password
    DB_ROOT_PASSWORD=$(openssl rand -base64 32)
    
    # Secure installation non-interactively
    sudo mysql -e "UPDATE mysql.user SET Password = PASSWORD('$DB_ROOT_PASSWORD') WHERE User = 'root'"
    sudo mysql -e "DELETE FROM mysql.user WHERE User=''"
    sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
    sudo mysql -e "DROP DATABASE IF EXISTS test"
    sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    sudo mysql -e "FLUSH PRIVILEGES"
    
    # Save root credentials
    echo "MariaDB Root Password: $DB_ROOT_PASSWORD" > ~/mariadb_credentials.txt
    chmod 600 ~/mariadb_credentials.txt
    
    log "MariaDB installed and secured. Root password saved to ~/mariadb_credentials.txt"
}

# Install phpMyAdmin
install_phpmyadmin() {
    log "Installing phpMyAdmin latest..."
    
    # Create phpMyAdmin directory
    sudo mkdir -p /var/www/phpmyadmin
    cd /tmp
    
    # Download latest phpMyAdmin
    PHPMYADMIN_VERSION=$(curl -s https://api.github.com/repos/phpmyadmin/phpmyadmin/releases/latest | grep "tag_name" | cut -d '"' -f 4)
    log "Downloading phpMyAdmin version: $PHPMYADMIN_VERSION"
    
    wget "https://github.com/phpmyadmin/phpmyadmin/archive/${PHPMYADMIN_VERSION}.tar.gz"
    tar xzf "${PHPMYADMIN_VERSION}.tar.gz"
    
    # Move to web directory
    sudo mv "phpmyadmin-${PHPMYADMIN_VERSION}"/* /var/www/phpmyadmin/
    sudo chown -R www-data:www-data /var/www/phpmyadmin
    sudo chmod -R 755 /var/www/phpmyadmin
    
    # Configure phpMyAdmin
    sudo cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php
    
    # Generate blowfish secret
    BLOWFISH_SECRET=$(openssl rand -base64 32)
    sudo sed -i "s/\$cfg\['blowfish_secret'\] = '';/\$cfg['blowfish_secret'] = '$BLOWFISH_SECRET';/" /var/www/phpmyadmin/config.inc.php
    
    # Create temp directory
    sudo mkdir -p /var/www/phpmyadmin/tmp
    sudo chown www-data:www-data /var/www/phpmyadmin/tmp
    sudo chmod 777 /var/www/phpmyadmin/tmp
    
    # Add temp directory to config
    echo "\$cfg['TempDir'] = '/var/www/phpmyadmin/tmp';" | sudo tee -a /var/www/phpmyadmin/config.inc.php
    
    log "phpMyAdmin installed successfully"
    
    # Clean up
    rm -f "/tmp/${PHPMYADMIN_VERSION}.tar.gz"
    rm -rf "/tmp/phpmyadmin-${PHPMYADMIN_VERSION}"
}

# Configure Nginx for PHP and phpMyAdmin
configure_nginx() {
    log "Configuring Nginx..."
    
    # Backup default config
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
    
    # Create new default site configuration
    sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}

server {
    listen 80;
    server_name phpmyadmin.localhost localhost;

    root /var/www/phpmyadmin;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }

    # Deny access to setup and libraries directories
    location ~ ^/(setup|libraries)/ {
        deny all;
    }
}
EOF

    # Test Nginx configuration
    sudo nginx -t
    
    # Restart Nginx
    sudo systemctl restart nginx
    
    log "Nginx configured for PHP and phpMyAdmin"
}

# Create test PHP file
create_test_files() {
    log "Creating test files..."
    
    # Create PHP info file
    sudo tee /var/www/html/info.php > /dev/null <<EOF
<?php
phpinfo();
?>
EOF

    # Create a simple test file
    sudo tee /var/www/html/test.php > /dev/null <<EOF
<?php
echo "<h1>LEMP Stack Test</h1>";
echo "<p>PHP Version: " . phpversion() . "</p>";
echo "<p>Server: " . \$_SERVER['SERVER_SOFTWARE'] . "</p>";

// Test MySQL connection
try {
    \$pdo = new PDO('mysql:host=localhost', 'root', file_get_contents('/home/' . get_current_user() . '/mariadb_credentials.txt'));
    echo "<p>Database Connection: <span style='color: green;'>Success</span></p>";
} catch(PDOException \$e) {
    echo "<p>Database Connection: <span style='color: red;'>Failed</span></p>";
}

echo "<p><a href='/phpmyadmin' target='_blank'>Access phpMyAdmin</a></p>";
?>
EOF

    sudo chown www-data:www-data /var/www/html/*.php
    
    log "Test files created successfully"
}

# Create phpMyAdmin database user
create_phpmyadmin_user() {
    log "Creating phpMyAdmin database user..."
    
    # Read root password
    DB_ROOT_PASSWORD=$(cat ~/mariadb_credentials.txt | grep "MariaDB Root Password:" | cut -d ' ' -f 4)
    
    # Generate phpMyAdmin user password
    PMA_PASSWORD=$(openssl rand -base64 16)
    
    # Create phpMyAdmin user
    mysql -u root -p"$DB_ROOT_PASSWORD" -e "CREATE USER 'phpmyadmin'@'localhost' IDENTIFIED BY '$PMA_PASSWORD';"
    mysql -u root -p"$DB_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;"
    mysql -u root -p"$DB_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
    
    # Save phpMyAdmin credentials
    echo "phpMyAdmin User: phpmyadmin" >> ~/mariadb_credentials.txt
    echo "phpMyAdmin Password: $PMA_PASSWORD" >> ~/mariadb_credentials.txt
    
    log "phpMyAdmin user created successfully"
}

# Display final information
display_info() {
    log "Installation completed successfully!"
    echo
    info "=== LEMP Stack Installation Summary ==="
    info "Nginx: Installed and running"
    info "PHP: 8.3 with PHP-FPM"
    info "MariaDB: Latest version installed"
    info "phpMyAdmin: Latest version installed"
    echo
    info "=== Access Information ==="
    info "Web server: http://localhost or http://$(hostname -I | awk '{print $1}')"
    info "PHP Info: http://localhost/info.php"
    info "Test page: http://localhost/test.php"
    info "phpMyAdmin: http://localhost/phpmyadmin"
    echo
    info "=== Credentials ==="
    info "Database credentials are saved in: ~/mariadb_credentials.txt"
    warning "Please change default passwords for production use!"
    echo
    info "=== Service Status ==="
    sudo systemctl status nginx --no-pager -l
    sudo systemctl status php8.3-fpm --no-pager -l
    sudo systemctl status mariadb --no-pager -l
    echo
    info "=== Next Steps ==="
    info "1. Secure your server with SSL certificates"
    info "2. Configure proper firewall rules"
    info "3. Update default passwords"
    info "4. Remove test files from production"
    info "5. Configure automatic backups"
    echo
    log "Installation script completed!"
}

# Main execution
main() {
    log "Starting LEMP Stack installation..."
    
    check_root
    detect_os
    update_system
    install_nginx
    install_php
    install_mariadb
    install_phpmyadmin
    configure_nginx
    create_phpmyadmin_user
    create_test_files
    display_info
}

# Run main function
main "$@"