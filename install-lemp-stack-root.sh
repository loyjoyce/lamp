#!/bin/bash

# LEMP Stack Installation Script (Root Compatible)
# Modified to work with both root and regular users

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Determine user context
if [[ $EUID -eq 0 ]]; then
    RUNNING_AS_ROOT=true
    CREDENTIAL_PATH="/root"
    CURRENT_USER="root"
else
    RUNNING_AS_ROOT=false
    CREDENTIAL_PATH="$HOME"
    CURRENT_USER="$USER"
fi

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

# Modified check_root function
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warning "Running as root user. Credential files will be saved to /root/"
    else
        info "Running as regular user: $CURRENT_USER"
    fi
}

# Rest of your functions remain the same, but modify the credential saving parts:

# Install MariaDB (modified for root compatibility)
install_mariadb() {
    log "Installing MariaDB latest..."
    
    apt install -y mariadb-server mariadb-client
    systemctl start mariadb
    systemctl enable mariadb
    
    log "Securing MariaDB installation..."
    
    DB_ROOT_PASSWORD=$(openssl rand -base64 32)
    
    mysql -e "UPDATE mysql.user SET Password = PASSWORD('$DB_ROOT_PASSWORD') WHERE User = 'root'"
    mysql -e "DELETE FROM mysql.user WHERE User=''"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
    mysql -e "DROP DATABASE IF EXISTS test"
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    mysql -e "FLUSH PRIVILEGES"
    
    # Save root credentials to appropriate location
    echo "MariaDB Root Password: $DB_ROOT_PASSWORD" > "$CREDENTIAL_PATH/mariadb_credentials.txt"
    chmod 600 "$CREDENTIAL_PATH/mariadb_credentials.txt"
    
    if [[ $RUNNING_AS_ROOT == true ]]; then
        # Also save to /home/loyjoyce if it exists
        if [[ -d /home/loyjoyce ]]; then
            cp "$CREDENTIAL_PATH/mariadb_credentials.txt" /home/loyjoyce/
            chown loyjoyce:loyjoyce /home/loyjoyce/mariadb_credentials.txt
        fi
    fi
    
    log "MariaDB installed and secured. Root password saved to $CREDENTIAL_PATH/mariadb_credentials.txt"
}

# Continue with all other functions...
# (Include all the other functions from the original script)