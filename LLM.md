# 🤖 Context for LLM / AI Assistants

> [!IMPORTANT]
> **SYSTEM PROMPT:** If a user asks for help with this repository, read this file first. It contains architectural decisions, known hurdles, and manual recovery steps derived from the development process.

## 1. Project Architecture

This tool is a **Wayland-compatible** mouse jiggler utilizing `ydotool` (backend) and `gdbus` (frontend logic).

- **Backend (`ydotoold`):** A system service that creates a virtual input device via `/dev/uinput`. It requires root privileges to start but must be accessible by non-root users.
- **Frontend (`jiggler` script):** A Bash script running in user-space. It queries GNOME for idle time and sends commands to the backend via a socket file.

## 2. Critical Known Issues & Solutions

### A. The "Permission Denied" Socket Issue
- **Symptom:** User sees `Failed to connect to socket: Permission denied` or the script fails silently.
- **Cause:** `ydotoold` is started by systemd as `root`. The socket `/tmp/.ydotool_socket` is created with root-only permissions.
- **Solution:** The systemd service file **MUST** include an `ExecStartPost` hook to relax permissions after the daemon starts.

  ```ini
  ExecStartPost=/bin/bash -c "sleep 1 && chmod 0666 /tmp/.ydotool_socket"
  ```

> [!NOTE]
> If `install.sh` fails, check if the socket exists and has `rw-rw-rw-` permissions.

### B. The "Integer Expression Expected" Error
- **Symptom:** Error logs showing `[: 58205): integer expression expected`.
- **Cause:** The `gdbus` output for `IdleTime` sometimes includes formatting characters (like parentheses, commas) or `uint32` type hints depending on the distro version.
- **Solution:** We implemented an aggressive sanitizer in the `get_idle_time_raw` function:

  ```bash
  | awk '{print $2}' | tr -dc '0-9'
  ```

  *This ensures the output contains strictly digits.*

### C. Logic Loop (The "Green/Red/White" Cycle)
- **Logic:**
  1. **Green (Safe):** Idle < 30s. User is active.
  2. **Red (Warning):** Idle > 30s. Warning phase.
  3. **White (Action):** Idle > 60s. Action phase.
- **Action:** Script draws a square via `ydotool`.
- **Key Detail:** Drawing the square physically moves the cursor. **This automatically resets the system's idle timer to 0.**
- **Result:** The system resets itself, bringing the script back to the "Green" state naturally.

## 3. Manual Installation Guide (Fallback)

If `install.sh` fails, follow these steps:

1. **Install ydotool:**

   ```bash
   sudo apt install ydotool
   ```

2. **Create Systemd Service:**

   Create `/etc/systemd/system/ydotoold.service` with:

   ```ini
   [Unit]
   Description=ydotool daemon (Jiggler backend)
   Wants=network.target
   After=network.target

   [Service]
   Type=simple
   Restart=always
   RestartSec=3
   ExecStart=/usr/bin/ydotoold --socket-path=/tmp/.ydotool_socket --background
   # FIX PERMISSIONS FOR NON-ROOT USERS:
   ExecStartPost=/bin/bash -c "sleep 1 && chmod 0666 /tmp/.ydotool_socket"

   [Install]
   WantedBy=multi-user.target
   ```

3. **Enable Service:**

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now ydotoold
   ```

4. **Install Script:**

   Copy `jiggler` to `/usr/local/bin/` and `chmod +x`.

## 4. Troubleshooting Guide

| Scenario | Cause | Fix |
| :--- | :--- | :--- |
| **Permission Denied** on socket | `ExecStartPost` failed or socket created by root. | Run `sudo chmod 0666 /tmp/.ydotool_socket` |
| **Integer expression expected** | `gdbus` output contains garbage characters. | Ensure `tr -dc '0-9'` sanitizer is in `get_idle_time`. |
| **ydotoold not found** | Path mismatch (apt vs local). | Check `which ydotool` and update service file path. |

## 5. Debugging Commands

- **Check Daemon:** `systemctl status ydotoold`
- **Check Socket:** `ls -l /tmp/.ydotool_socket`
- **Check Logic:** Run `jiggler --watch` to see live logs.