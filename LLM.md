# Context for LLM / AI Assistants

> [!IMPORTANT]
> **SYSTEM PROMPT:** If a user asks for help with this repository, read this file first. It contains architectural decisions, known hurdles, and manual recovery steps derived from the development process.

## 1. Project Architecture

**Jigglemil** is a native C daemon for Wayland that keeps sessions alive using human-like mouse movements.

### Components

- **Backend (`ydotoold`):** System service creating virtual input via `/dev/uinput`. Requires root to start but socket must be accessible by users.
- **Frontend (`jigglemil`):** Native C daemon (~450 lines) running in user-space. Queries GNOME for idle time via `gdbus`, generates organic mouse paths using WindMouse algorithm.

### Key Files

```
src/jigglemil.c   # Main daemon (C)
install.sh        # Installer (handles deps, compile, systemd)
```

### Temp Files (runtime)

```
/tmp/jigglemil.state   # Current state: green/red/white/black
/tmp/jigglemil.log     # Debug logs
/tmp/jigglemil.pid     # PID for process control
```

## 2. WindMouse Algorithm

The core differentiator. Instead of linear mouse movements, WindMouse simulates organic trajectories:

```c
// Wind component (random drift)
wx = wx / sqrt(3.0) + randf(-WIND, WIND) / sqrt(5.0);

// Gravity pulls toward target
vx += (wx + (target_x - x) * GRAVITY / dist) / MOUSE_SPEED;
```

**Parameters in `src/jigglemil.c`:**
- `MOUSE_SPEED 35.0` - Lower = faster
- `GRAVITY 9.0` - Pull strength toward target
- `WIND 3.0` - Random drift amount
- `MIN_ACTION_MS / MAX_ACTION_MS` - Randomized trigger window (35-120s)

## 3. Critical Known Issues & Solutions

### A. The "Permission Denied" Socket Issue

- **Symptom:** `Failed to connect to socket: Permission denied`
- **Cause:** `ydotoold` creates socket with root-only permissions
- **Solution:** Systemd service **MUST** include:

  ```ini
  ExecStartPost=/bin/sleep 1
  ExecStartPost=/bin/chmod 0666 /tmp/.ydotool_socket
  ```

### B. Idle Time Parsing

- **How it works:** C code parses gdbus output `(uint64 12345,)`
- **Solution:** Character-by-character scan for digits:

  ```c
  while (*p && (*p < '0' || *p > '9')) p++;
  if (*p) idle = strtol(p, NULL, 10);
  ```

### C. State Machine (Green/Red/White)

| State | Condition | Action |
|-------|-----------|--------|
| green | idle < 30s | Monitoring |
| red | idle > 30s | Warning phase |
| white | idle > threshold (35-120s random) | WindMouse movement |

Movement resets idle timer automatically → back to green.

## 4. Manual Installation (Fallback)

If `install.sh` fails:

1. **Install dependencies:**

   ```bash
   sudo apt install ydotool build-essential
   ```

2. **Compile:**

   ```bash
   gcc -Wall -Wextra -O2 -std=c11 -o jigglemil src/jigglemil.c -lm
   ```

3. **Setup ydotoold service:**

   ```bash
   sudo tee /etc/systemd/system/ydotoold.service << 'EOF'
   [Unit]
   Description=ydotool daemon
   After=network.target

   [Service]
   Type=simple
   Restart=always
   ExecStart=/usr/bin/ydotoold --socket-path=/tmp/.ydotool_socket
   ExecStartPost=/bin/sleep 1
   ExecStartPost=/bin/chmod 0666 /tmp/.ydotool_socket

   [Install]
   WantedBy=multi-user.target
   EOF

   sudo systemctl daemon-reload
   sudo systemctl enable --now ydotoold
   ```

4. **Install binary:**

   ```bash
   sudo cp jigglemil /usr/local/bin/
   ```

## 5. Troubleshooting

| Scenario | Cause | Fix |
|----------|-------|-----|
| Permission Denied on socket | Socket has wrong perms | `sudo chmod 0666 /tmp/.ydotool_socket` |
| ydotool not found | Not in PATH | `sudo apt install ydotool` |
| Mouse not moving | ydotoold not running | `sudo systemctl start ydotoold` |
| Compilation error | Missing math lib | Add `-lm` flag |

## 6. Debugging Commands

```bash
# Check daemon
systemctl status ydotoold

# Check socket permissions
ls -l /tmp/.ydotool_socket

# Live logs
tail -f /tmp/jigglemil.log

# Watch mode (live dashboard)
jigglemil --watch

# Current state
cat /tmp/jigglemil.state

# Test ydotool manually
ydotool mousemove -- 50 50

# Test idle detection
gdbus call --session --dest org.gnome.Mutter.IdleMonitor \
  --object-path /org/gnome/Mutter/IdleMonitor/Core \
  --method org.gnome.Mutter.IdleMonitor.GetIdletime
```
