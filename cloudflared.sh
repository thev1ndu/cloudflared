#!/bin/bash

echo "===== Cloudflare Tunnel Setup Script ====="

# Step 1: Install cloudflared
echo "[*] Downloading cloudflared..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
chmod +x cloudflared
mv cloudflared /usr/local/bin/cloudflared
echo "[+] cloudflared installed."

# Step 2: Login to Cloudflare
echo "[*] Logging into Cloudflare..."
cloudflared tunnel login

# Step 3: Get tunnel name and domain
read -p "Enter a Tunnel Name: " TUNNEL_NAME
read -p "Enter your Domain Name (e.g., proxy.domain.com): " DOMAIN_NAME
read -p "Enter your first local port (e.g., 17000): " PORT1
read -p "Enter your second local port (or leave blank if none): " PORT2

# Step 4: Create the tunnel
echo "[*] Creating the tunnel..."
cloudflared tunnel create "$TUNNEL_NAME"

# Get Tunnel ID
TUNNEL_ID=$(cat /root/.cloudflared/"$TUNNEL_NAME".json | grep -oP '(?<="TunnelID": ")[^"]+')

# Step 5: Create DNS routing
echo "[*] Routing DNS to tunnel..."
cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN_NAME"

# Step 6: Generate config.yml
CONFIG_PATH="/root/.cloudflared/config.yml"
echo "[*] Creating config file at $CONFIG_PATH"

cat > "$CONFIG_PATH" <<EOF
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/$TUNNEL_NAME.json

ingress:
  - hostname: $DOMAIN_NAME
    service: https://localhost:$PORT1
EOF

# Add second port if provided
if [[ ! -z "$PORT2" ]]; then
cat >> "$CONFIG_PATH" <<EOF
  - hostname: $DOMAIN_NAME
    service: http://localhost:$PORT2
EOF
fi

# Default rule
cat >> "$CONFIG_PATH" <<EOF
  - service: http_status:404
EOF

echo "[+] Config file created."

# Step 7: Run the tunnel
echo "[*] Starting the Cloudflare tunnel..."
cloudflared tunnel --config "$CONFIG_PATH" run
