#!/bin/bash

# MongoDB 4.4 Installation Script for Ubuntu 22.04
# This script installs MongoDB 4.4 on Ubuntu 22.04 using the Focal repository
# and fixes compatibility issues with libssl

set -e  # Exit immediately if a command exits with a non-zero status

# Function to print colored output
print_message() {
    GREEN='\033[0;32m'
    NC='\033[0m'  # No Color
    echo -e "${GREEN}[MongoDB Installer] $1${NC}"
}

print_error() {
    RED='\033[0;31m'
    NC='\033[0m'  # No Color
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root or with sudo"
    exit 1
fi

# Set MongoDB version
MONGODB_VERSION="4.4"

print_message "Starting MongoDB $MONGODB_VERSION installation on Ubuntu 22.04"
print_message "Step 1: Updating system packages..."
apt update && apt upgrade -y

print_message "Step 2: Installing required dependencies..."
apt install -y gnupg curl

print_message "Step 3: Importing MongoDB 4.4 GPG key..."
curl -fsSL https://pgp.mongodb.com/server-4.4.asc | \
   gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg \
   --dearmor

print_message "Step 4: Adding MongoDB 4.4 repository (using Focal)..."
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | \
   tee /etc/apt/sources.list.d/mongodb-org-4.4.list

print_message "Step 5: Updating package index..."
apt update

print_message "Step 6: Installing MongoDB 4.4..."
apt install -y mongodb-org=$MONGODB_VERSION mongodb-org-server=$MONGODB_VERSION \
    mongodb-org-shell=$MONGODB_VERSION mongodb-org-mongos=$MONGODB_VERSION \
    mongodb-org-tools=$MONGODB_VERSION

print_message "Step 7: Pinning the MongoDB version..."
echo "mongodb-org hold" | dpkg --set-selections
echo "mongodb-org-server hold" | dpkg --set-selections
echo "mongodb-org-shell hold" | dpkg --set-selections
echo "mongodb-org-mongos hold" | dpkg --set-selections
echo "mongodb-org-tools hold" | dpkg --set-selections

print_message "Step 8: Fixing libssl compatibility issues..."
if [ ! -f /usr/lib/x86_64-linux-gnu/libssl.so.1.1 ]; then
    ln -sf /usr/lib/x86_64-linux-gnu/libssl.so.3 /usr/lib/x86_64-linux-gnu/libssl.so.1.1
    print_message "Created symlink for libssl.so.1.1"
else
    print_message "libssl.so.1.1 already exists"
fi

if [ ! -f /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 ]; then
    ln -sf /usr/lib/x86_64-linux-gnu/libcrypto.so.3 /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
    print_message "Created symlink for libcrypto.so.1.1"
else
    print_message "libcrypto.so.1.1 already exists"
fi

print_message "Step 9: Starting and enabling MongoDB service..."
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to start
sleep 5

# Check if MongoDB is running
if systemctl is-active --quiet mongod; then
    print_message "MongoDB is running successfully!"
else
    print_error "MongoDB failed to start. Check logs with: sudo cat /var/log/mongodb/mongod.log"
    exit 1
fi

# Ask user if they want to set up an admin user
read -p "Do you want to create an admin user for MongoDB? (y/n): " create_admin
if [[ "$create_admin" =~ ^[Yy]$ ]]; then
    read -p "Enter admin username: " admin_user
    read -s -p "Enter admin password: " admin_pass
    echo

    # Create admin user
    print_message "Creating admin user..."
    mongosh --quiet --eval "
    use admin;
    db.createUser({
        user: '$admin_user',
        pwd: '$admin_pass',
        roles: [{ role: 'userAdminAnyDatabase', db: 'admin' }]
    });
    exit;" admin

    # Enable authentication in MongoDB config
    print_message "Enabling authentication in MongoDB config..."
    if grep -q "#security:" /etc/mongod.conf; then
        # Uncomment and set security.authorization
        sed -i 's/#security:/security:\n  authorization: enabled/' /etc/mongod.conf
    elif grep -q "security:" /etc/mongod.conf; then
        # Check if authorization is already set
        if ! grep -q "authorization: enabled" /etc/mongod.conf; then
            # Add authorization under security
            sed -i '/security:/a \ \ authorization: enabled' /etc/mongod.conf
        fi
    else
        # Add security section with authorization
        echo -e "\nsecurity:\n  authorization: enabled" >> /etc/mongod.conf
    fi

    # Restart MongoDB for changes to take effect
    print_message "Restarting MongoDB..."
    systemctl restart mongod
    sleep 3

    if systemctl is-active --quiet mongod; then
        print_message "MongoDB restarted successfully with authentication enabled!"
    else
        print_error "MongoDB failed to restart. Check logs with: sudo cat /var/log/mongodb/mongod.log"
        exit 1
    fi
fi

print_message "MongoDB $MONGODB_VERSION has been successfully installed on Ubuntu 22.04!"
print_message "MongoDB service is running on default port 27017"
print_message "Configuration file: /etc/mongod.conf"
print_message "Log file: /var/log/mongodb/mongod.log"

if [[ "$create_admin" =~ ^[Yy]$ ]]; then
    print_message "Authentication is enabled. Connect using:"
    print_message "  mongosh --authenticationDatabase admin -u $admin_user -p"
else
    print_message "Connect to MongoDB using:"
    print_message "  mongosh"
fi

exit 0