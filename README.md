# Jigglemil

> **Keep your status Green.** Fight the micromanagement. Stay active.

A native C daemon that keeps your session alive using human-like mouse movements. Works on **Wayland** where other tools fail.

![Status Demo](gif.gif)

## Why This Works (And Others Don't)

| Tool | Method | Detectable? |
|------|--------|-------------|
| Caffeine | Inhibits screensaver via D-Bus | **Trivial** - just a flag |
| xdotool | X11 synthetic events | **Easy** - tagged as synthetic |
| Mouse jigglers (USB) | Hardware HID events | Detectable by device ID |
| **Jigglemil** | uinput kernel events | **Indistinguishable from real hardware** |

### The Secret Sauce

1. **Kernel-level injection** - Uses `ydotool` which writes directly to `/dev/uinput`. From the kernel's perspective, this IS a real input device.

2. **WindMouse algorithm** - Borrowed from game bot research. Creates curved, organic trajectories with simulated "wind" and "gravity" instead of robotic straight lines.

3. **Chaotic timing** - No fixed intervals. Action triggers are randomized between 35-120 seconds. Zero temporal signature.

## Quick Start

```bash
git clone https://github.com/emilszymecki/wayland-jiggler.git
cd wayland-jiggler
chmod +x install.sh
sudo ./install.sh

# Run it
jigglemil
```

## Installation Options

### Option A: System-wide (recommended)
```bash
sudo ./install.sh
```
This will:
- Install `jigglemil` to `/usr/local/bin/`
- Configure `ydotoold` systemd service
- Create user service file

### Option B: User-local
```bash
./install.sh  # without sudo
```
Installs to `~/.local/bin/` (make sure it's in your PATH)

### Option C: Manual
```bash
gcc -Wall -Wextra -O2 -std=c11 -o jigglemil src/jigglemil.c -lm
sudo cp jigglemil /usr/local/bin/
```

## Usage

### Foreground (see what's happening)
```bash
jigglemil --watch
```

### Background (daemon mode)
```bash
jigglemil &
# or better:
systemctl --user start jigglemil
```

### As a service (auto-start on login)
```bash
systemctl --user enable --now jigglemil
```

### Options

| Flag | Description |
|------|-------------|
| `--watch` | Live dashboard mode - see status, idle time, countdown in real-time |
| `--smooth` | Individual mouse moves with delays. Slower but more human-like. |
| `--help` | Show help |

## Status Indicators

The daemon writes its state to `/tmp/jigglemil.state`:

| State | Meaning |
|-------|---------|
| green | Safe - user is active or jigglemil is monitoring |
| red | Warning - idle > 30s, action imminent |
| white | Action - performing mouse movement |
| black | Stopped |

### GNOME Integration (Executor Extension)

1. Install the [Executor](https://extensions.gnome.org/extension/2932/executor/) extension
2. Add new command:
   - **Command:** `cat /tmp/jigglemil.state`
   - **Interval:** `1`
   - **Left Click:** `systemctl --user start jigglemil`
   - **Right Click:** `systemctl --user stop jigglemil`

Result: A live status indicator in your top bar.

## Monitoring

```bash
# Current status
cat /tmp/jigglemil.state

# Live logs
tail -f /tmp/jigglemil.log

# Check if running
cat /tmp/jigglemil.pid
```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                       JIGGLEMIL                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │ Idle Timer  │───>│ WindMouse    │───>│ ydotool       │  │
│  │ (gdbus)     │    │ (path gen)   │    │ (executor)    │  │
│  └─────────────┘    └──────────────┘    └───────┬───────┘  │
│                                                  │          │
│                                                  v          │
│                                          ┌──────────────┐   │
│                                          │ /dev/uinput  │   │
│                                          │ (kernel)     │   │
│                                          └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

1. **Monitor** - Polls GNOME's `IdleMonitor` every 2 seconds
2. **Decide** - If idle exceeds randomized threshold (35-120s), trigger action
3. **Generate** - WindMouse algorithm creates curved trajectory (pure math, no I/O)
4. **Execute** - Single batched `ydotool` command injects all movements
5. **Reset** - Randomize next threshold, return to monitoring

## Configuration

Edit `src/jigglemil.c` constants:

```c
#define WARNING_LIMIT_MS    30000   // When to show red (30s)
#define MIN_ACTION_MS       35000   // Minimum idle before action
#define MAX_ACTION_MS       120000  // Maximum idle before action
#define MOUSE_SPEED         35.0    // Lower = faster mouse
#define GRAVITY             9.0     // Pull toward target
#define WIND                3.0     // Random drift amount
```

Then recompile: `gcc -Wall -Wextra -O2 -std=c11 -o jigglemil src/jigglemil.c -lm`

## Troubleshooting

### "ydotool: command not found"
```bash
sudo apt install ydotool
```

### "failed to connect socket"
```bash
# Start the ydotool daemon
sudo systemctl enable --now ydotoold

# Or manually:
sudo ydotoold --socket-path=/tmp/.ydotool_socket &
sudo chmod 666 /tmp/.ydotool_socket
```

### Mouse not moving
```bash
# Check if ydotool works
export YDOTOOL_SOCKET=/tmp/.ydotool_socket
ydotool mousemove -- 50 50

# Check idle detection
gdbus call --session --dest org.gnome.Mutter.IdleMonitor \
  --object-path /org/gnome/Mutter/IdleMonitor/Core \
  --method org.gnome.Mutter.IdleMonitor.GetIdletime
```

### KDE/Sway support
Currently designed for GNOME (uses `org.gnome.Mutter.IdleMonitor`).

For KDE, you'd need to replace the idle detection with:
```bash
qdbus org.kde.screensaver /ScreenSaver GetSessionIdleTime
```

PRs welcome!

## License

MIT License - do whatever you want.

## Credits

- **WindMouse algorithm** - Adapted from Ben Land's implementation
- **ydotool** - The magic behind kernel-level input injection
- **Claude** - Pair programming partner

---

*Made with mass distrust of activity monitoring*
