#!/bin/bash

echo "🚀 Installing Wayland Jiggler..."

if [ "$EUID" -ne 0 ]; then 
  echo "❌ Please run as root (sudo ./install.sh)"
  exit 1
fi

# --- STEP 1: SMART YDOTOOL DETECTION ---
YDO_BIN=""

# Check for manually compiled version (High Priority)
# Matches our "Build from Source" guide in LLM.md
if [ -f "/usr/local/bin/ydotoold" ]; then
    echo "💎 Found manually compiled version at /usr/local/bin/ydotoold"
    YDO_BIN="/usr/local/bin/ydotoold"

# Check for existing system package
elif [ -f "/usr/bin/ydotoold" ]; then
    echo "📦 Found system package version at /usr/bin/ydotoold"
    YDO_BIN="/usr/bin/ydotoold"

else
    # Fallback: Install via APT for lazy users
    echo "⚠️  ydotoold not found. Attempting install via APT..."
    apt-get update && apt-get install -y ydotool
    YDO_BIN="/usr/bin/ydotoold"
fi

# Final Validation
if [ ! -f "$YDO_BIN" ]; then
    echo "❌ CRITICAL ERROR: Could not find or install ydotool."
    echo "👉 Please compile manually following instructions in LLM.md"
    exit 1
fi

# --- STEP 2: SERVICE CONFIGURATION ---
echo "⚙️  Configuring systemd service using: $YDO_BIN"

cat <<EOF > /etc/systemd/system/ydotoold.service
[Unit]
Description=ydotool daemon (Jiggler backend)
Wants=network.target
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=3

# Using the detected binary path variable
ExecStart=$YDO_BIN --socket-path=/tmp/.ydotool_socket --background

# Permissions Fix (Critical for user script access):
# Wait 1s for socket creation, then allow read/write for all users.
ExecStartPost=/bin/bash -c "sleep 1 && chmod 0666 /tmp/.ydotool_socket"

[Install]
WantedBy=multi-user.target
EOF

# --- STEP 3: START SERVICE ---
echo "🔥 Starting service..."
systemctl daemon-reload
systemctl enable --now ydotoold

# --- STEP 4: INSTALL SCRIPT ---
echo "📜 Copying jiggler script to /usr/local/bin..."
if [ -f "jiggler" ]; then
    cp jiggler /usr/local/bin/jiggler
    chmod +x /usr/local/bin/jiggler
else
    echo "⚠️  Warning: 'jiggler' file not found in current directory. Skipping copy."
fi

echo "✅ Installation Complete!"
echo "👉 You can now run: jiggler --start"