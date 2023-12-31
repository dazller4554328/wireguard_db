#!/bin/bash
if [ ! -f "/root/wireguard_db/variables.json" ]; then
    echo "Variables file does not exist. Please run the PHP script first."
    exit 1
fi

# Define log file
LOG_FILE="/root/wireguard_db/installation.log"

{
    sudo apt install -y jq
    # Read variables from the JSON file
    serverName=$(jq -r '.serverName' /root/wireguard_db/variables.json)
    rootPassword=$(jq -r '.rootPassword' /root/wireguard_db/variables.json)
    serverIp=$(jq -r '.serverIp' /root/wireguard_db/variables.json)
    adminEmail=$(jq -r '.adminEmail' /root/wireguard_db/variables.json)
    localUsername=$(jq -r '.localUsername' /root/wireguard_db/variables.json)
    localPassword=$(jq -r '.localPassword' /root/wireguard_db/variables.json)
    scriptUsername=$(jq -r '.scriptUsername' /root/wireguard_db/variables.json)
    scriptPassword=$(jq -r '.scriptPassword' /root/wireguard_db/variables.json)
    apiKey=$(jq -r '.apiKey' /root/wireguard_db/variables.json)
    # Update system packages
    sudo apt update && sudo apt upgrade -y
    sudo apt install dnsutils
    serverIp=$(dig +short myip.opendns.com @resolver1.opendns.com)

    # Install MySQL
    sudo apt install -y mysql-server
    sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

    # Create database and users
    sudo mysql -e "CREATE DATABASE wire_db"
    sudo mysql -e "CREATE USER '$localUsername'@'localhost' IDENTIFIED WITH mysql_native_password BY '$localPassword'"
    sudo mysql -e "GRANT ALL PRIVILEGES ON wire_db.* TO '$localUsername'@'localhost' WITH GRANT OPTION"
    sudo mysql -e "CREATE USER '$scriptUsername'@'$serverIp' IDENTIFIED WITH mysql_native_password BY '$scriptPassword'"
    sudo mysql -e "GRANT ALL PRIVILEGES ON wire_db.* TO '$scriptUsername'@'$serverIp' WITH GRANT OPTION"
    sudo mysql -e "FLUSH PRIVILEGES"
    sleep 5
    # Import tables from create_tables.sql
    sudo mysql -u "$localUsername" -p"$localPassword" wire_db < /root/wireguard_db/create_tables.sql

    sudo service mysql restart
#} &> "$LOG_FILE"  # Redirect stdout and stderr to log file

#echo "Script completed, logs can be found in $LOG_FILE"
sudo service mysql restart

# Create /opt/wireguard directory
mkdir -p /opt/wireguard

# Create config.php file
sudo bash -c "cat > /opt/wireguard/config.php <<EOF
<?php
// MySQL configuration
$dbHost = 'localhost';
$dbUsername = '$localUsername';
$dbPassword = '$localPassword';
$dbName = 'wire_db';
$apiKey = '$apiKey';
?>
EOF"
sudo apt install wget -y
# Copy the wireguard.sh script to the root folder
sudo wget -O /root/wireguard.sh https://get.vpnsetup.net/wg
sleep 2
# Run the script with the --auto option
sudo bash /root/wireguard.sh --auto
# Extract WireGuard public key
PUBLIC_KEY=$(wg show | grep 'public key' | awk -F': ' '{print $2}')

# Define MySQL command to connect to the database
MYSQL_CMD="mysql -u$localUsername -p$localPassword -hlocalhost wire_db -e"

# Define SQL query to find device based on public_key
QUERY="SELECT * FROM devices WHERE public_key = '$PUBLIC_KEY';"

# Check if device exists in the database
DEVICE=$($MYSQL_CMD "$QUERY")

if [ -z "$DEVICE" ]; then
    # Device not found, add new device
    PRIVATE_KEY=$(awk '/PrivateKey/ {print $NF}' /etc/wireguard/wg0.conf)
    LISTEN_PORT=$(awk '/ListenPort/ {print $NF}' /etc/wireguard/wg0.conf)
    DEVICE_NAME="wg0"  # WireGuard interface name

    # Insert device details into the devices table
    $MYSQL_CMD "INSERT INTO devices (device_name, public_key, private_key, listen_port) VALUES ('$DEVICE_NAME', '$PUBLIC_KEY', '$PRIVATE_KEY', $LISTEN_PORT);"

    # Parse each peer block and extract the necessary details
    awk '/^\[Peer\]$/,/AllowedIPs/ {if (!/^\[Peer\]$/&&!/AllowedIPs/) print $0}' /etc/wireguard/wg0.conf | while read -r PEER; do
        PEER_PUBLIC_KEY=$(echo "$PEER" | awk '/PublicKey/ {print $NF}')
        PEER_ALLOWED_IPS=$(echo "$PEER" | awk '/AllowedIPs/ {print $NF}')

        # Insert peer details into the peers table
        $MYSQL_CMD "INSERT INTO peers (device_name, public_key, allowed_ips_str) VALUES ('$DEVICE_NAME', '$PEER_PUBLIC_KEY', '$PEER_ALLOWED_IPS');"
    done
else
    # Device found, update wg0.conf with peer details
    WG_CONFIG_PATH="/etc/wireguard/wg0.conf"
    echo "" > "$WG_CONFIG_PATH"  # Clear the current wg0.conf file

    # Add device details to wg0.conf file
    echo "[Interface]" >> "$WG_CONFIG_PATH"
    echo "PrivateKey = device_private_key" >> "$WG_CONFIG_PATH"  # Replace with actual value
    echo "ListenPort = device_listen_port" >> "$WG_CONFIG_PATH"  # Replace with actual value

    # Add each peer details to wg0.conf file
    $MYSQL_CMD "$QUERY" | while read -r PEER; do
        echo "" >> "$WG_CONFIG_PATH"
        echo "[Peer]" >> "$WG_CONFIG_PATH"
        echo "PublicKey = peer_public_key" >> "$WG_CONFIG_PATH"  # Replace with actual value
        echo "AllowedIPs = peer_allowed_ips" >> "$WG_CONFIG_PATH"  # Replace with actual value
    done
fi

# Install Apache2
sudo apt install apache2 -y

# Create directory for the API
sudo mkdir -p /var/www/api/wireguard_api

# Configure Apache for the API
sudo bash -c 'cat > /etc/apache2/sites-available/wireguard_api.conf <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/api/wireguard_api
    <Directory /var/www/api/wireguard_api>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF'

# Enable the new site and disable the default site
sudo a2ensite wireguard_api.conf
sudo a2dissite 000-default.conf

# Reload Apache to apply the changes
sudo systemctl reload apache2

# Clone the Git repository
sudo apt-get install -y git
sudo git clone https://github.com/dazller4554328/wireguard_api.git /var/www/api/wireguard_api
} &> "$LOG_FILE"  # Redirect stdout and stderr to log file





