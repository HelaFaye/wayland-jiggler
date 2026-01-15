#!/bin/bash

echo "🚀 Installing Wayland Jiggler..."

if [ "$EUID" -ne 0 ]; then 
  echo "❌ Please run as root (sudo ./install.sh)"
  exit 1
fi

# 1. Install dependencies
echo "📦 Installing dependencies (ydotool)..."
apt-get update && apt-get install -y ydotool

# 2. Setup systemd service for ydotoold (background daemon)
# We use the config that allows non-root users to access the socket!
echo "⚙️  Configuring ydotoold service..."
cat <<EOF > /etc/systemd/system/ydotoold.service
[Unit]
Description=ydotool daemon (Jiggler backend)
Wants=network.target
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=3

# Command: Ensure we use the specific socket path needed by the script
ExecStart=/usr/bin/ydotoold --socket-path=/tmp/.ydotool_socket --background

# Permissions Fix:
# Wait 1s for the socket to be created, then give everyone write access.
# This allows the jiggler script (running as user) to talk to the daemon (running as root).
ExecStartPost=/bin/bash -c "sleep 1 && chmod 0666 /tmp/.ydotool_socket"

[Install]
WantedBy=multi-user.target
EOF

# 3. Enable and start the service
echo "🔥 Starting service..."
systemctl daemon-reload
systemctl enable --now ydotoold

# 4. Copy script
echo "📜 Copying jiggler script to /usr/local/bin..."
# Check if source file exists just in case
if [ -f "jiggler" ]; then
    cp jiggler /usr/local/bin/jiggler
    chmod +x /usr/local/bin/jiggler
else
    echo "⚠️  Warning: 'jiggler' file not found in current directory. Skipping copy."
fi

echo "✅ Installation Complete!"
echo "👉 You can now run: jiggler --start"