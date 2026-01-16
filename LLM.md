# Context for LLM / AI Assistants

> [!IMPORTANT]
> **SYSTEM PROMPT:** If a user asks for help with this repository, read this file first. It contains architectural decisions, known hurdles, and manual recovery steps.

## 1. Project Architecture

**Jigglemil** is a native C daemon for Wayland that keeps sessions alive using human-like mouse movements.

### Components

```
ydotoold (system service)     →  Creates /dev/uinput virtual input
    ↓
jigglemil (user daemon)       →  Generates WindMouse paths, executes via ydotool
    ↓
jiggler (bash wrapper)        →  User-friendly --start/--stop/--toggle/--status
```

### Key Files

```
src/jigglemil.c   # Main daemon (C, ~500 lines)
jiggler           # Wrapper script for easy control
install.sh        # Installer (deps, compile, systemd)
```

### Runtime Files

```
/tmp/jigglemil.state   # Current emoji: 🟢/🔴/🟡/⚫
/tmp/jigglemil.log     # Debug logs
/tmp/jigglemil.pid     # PID for process control
/tmp/.ydotool_socket   # ydotool IPC socket
```

## 2. State Machine

| Emoji | State | Condition | Action |
|-------|-------|-----------|--------|
| 🟢 | Safe | idle < 30s | Monitoring |
| 🔴 | Warning | idle 30-60s | Countdown to action |
| 🟡 | Action | idle > 60-120s (random) | WindMouse movement |
| ⚫ | Stopped | daemon not running | - |

Movement resets idle timer → back to 🟢

## 3. WindMouse Algorithm

Creates organic S-curve trajectories instead of straight lines:

```c
// Wind = random drift
wx = wx / sqrt(3.0) + randf(-wind, wind) / sqrt(5.0);

// Gravity = pull toward target
vx += (wx + (target_x - x) * gravity / dist) / mouse_speed;
```

**Randomized parameters per movement** (in `src/jigglemil.c`):

```c
#define MOUSE_SPEED_MIN     20.0    // Lower = more points
#define MOUSE_SPEED_MAX     30.0
#define GRAVITY_MIN         3.0     // Pull strength
#define GRAVITY_MAX         5.0
#define WIND_MIN            6.0     // Random drift
#define WIND_MAX            10.0
```

Each movement generates 100-400 unique path points.

## 4. Timing Configuration

```c
#define WARNING_LIMIT_MS    30000   // 🔴 starts at 30s idle
#define MIN_ACTION_MS       60000   // 🟡 earliest at 60s
#define MAX_ACTION_MS       120000  // 🟡 latest at 120s
```

Cycle: 30s green + 30-90s red (random) = 60-120s total per action

## 5. Critical Known Issues

### A. Socket Permission Denied

**Symptom:** `Failed to connect to socket: Permission denied`

**Cause:** `ydotoold` runs as root, creates socket with root perms

**Solution:** Systemd service MUST include:
```ini
ExecStartPost=/bin/sleep 1
ExecStartPost=/bin/chmod 0666 /tmp/.ydotool_socket
```

### B. ydotoold Path Detection

**Issue:** May be in `/usr/local/bin/ydotoold` (compiled) or `/usr/bin/ydotoold` (apt)

**Solution:** `install.sh` auto-detects:
```bash
if [ -f "/usr/local/bin/ydotoold" ]; then
    YDOTOOLD_BIN="/usr/local/bin/ydotoold"
elif [ -f "/usr/bin/ydotoold" ]; then
    YDOTOOLD_BIN="/usr/bin/ydotoold"
fi
```

### C. ydotoold Not Starting After Reboot

**Cause:** Service not enabled or wrong binary path

**Fix:**
```bash
sudo systemctl status ydotoold   # Check status
sudo ./install.sh                # Reinstall fixes config
```

## 6. User Commands

```bash
jiggler --start    # Start daemon (--smooth mode)
jiggler --stop     # Stop daemon
jiggler --toggle   # Toggle (for shortcuts)
jiggler --status   # Print emoji status
jiggler --watch    # Live dashboard
```

## 7. Manual Installation (Fallback)

If `install.sh` fails:

```bash
# 1. Install deps
sudo apt install ydotool build-essential

# 2. Compile
gcc -Wall -Wextra -O2 -std=c11 -o jigglemil src/jigglemil.c -lm
sudo cp jigglemil /usr/local/bin/
sudo cp jiggler /usr/local/bin/

# 3. Find ydotoold
YDOTOOLD=$(which ydotoold)

# 4. Create service
sudo tee /etc/systemd/system/ydotoold.service << EOF
[Unit]
Description=ydotool daemon
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=$YDOTOOLD --socket-path=/tmp/.ydotool_socket
ExecStartPost=/bin/sleep 1
ExecStartPost=/bin/chmod 0666 /tmp/.ydotool_socket

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ydotoold
```

## 8. Debugging

```bash
# Service status
systemctl status ydotoold

# Socket permissions (should be 0666)
ls -l /tmp/.ydotool_socket

# Live logs
tail -f /tmp/jigglemil.log

# Test ydotool
ydotool mousemove -- 50 50

# Test idle detection
gdbus call --session --dest org.gnome.Mutter.IdleMonitor \
  --object-path /org/gnome/Mutter/IdleMonitor/Core \
  --method org.gnome.Mutter.IdleMonitor.GetIdletime
```

## 9. GNOME Executor Integration

For status dot in top bar:
- **Command:** `jiggler --status`
- **Interval:** `1`
- **Left Click:** `jiggler --toggle`
