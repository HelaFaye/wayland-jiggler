# 🖱️ Wayland Jiggler (The Ultimate Anti-Idle Tool)

> **Keep your status Green.** Fight the micromanagement. Stay active.

![Jiggler Demo](gif.gif)

Most mouse jigglers break on **Linux Wayland** or require heavy GUI apps. This is a **lightweight, intelligent Bash script** that uses native system calls (`gdbus` + `ydotool`) to keep your session alive only when necessary.

It mimics human behavior and integrates seamlessly with your desktop environment.

## 🚀 Why this one?

* **Wayland Native:** Works where `xdotool` fails.
* **Intelligent Traffic Light System:**
    * 🟢 **Green:** You are active (or Jiggler is monitoring).
    * 🔴 **Red:** Warning (30s idle). Jiggler is about to take over.
    * ⚪ **White:** Action! (60s idle). Draws a square to reset the idle timer.
* **Stealth Mode:** Does not inject input constantly. It waits for the system idle timer to hit the threshold, performs one action, and sleeps.
* **The Matrix Mode:** Watch live logs with `--watch` to see exactly what the script is thinking.
* **GNOME Integrated:** Designed to work with the "Executor" extension to provide a clean, minimalist status dot on your top bar.

## 📦 Installation

1.  Clone this repository:
    ```bash
    git clone [https://github.com/emilszymecki/wayland-jiggler.git](https://github.com/emilszymecki/wayland-jiggler.git)
    cd wayland-jiggler
    ```

2.  Run the installer (handles dependencies like `ydotool` and permissions):
    ```bash
    chmod +x install.sh
    sudo ./install.sh
    ```

3.  **Done!** Type `jiggler --start` in your terminal.

## 🎮 Usage

| Command | Description |
| :--- | :--- |
| `jiggler --start` | Starts the daemon in the background. |
| `jiggler --stop` | Stops the daemon. |
| `jiggler --toggle` | Smart toggle (useful for toolbar buttons). |
| `jiggler --status` | Returns current state icon (🟢/🔴/⚪/⚫) for integration. |
| `jiggler --watch` | **Live Debug Mode.** View the countdown and logic in real-time. |

## 🧩 GNOME Top Bar Integration (Recommended)

To transform this script into a **minimalist, color-changing status dot** on your top bar (like a system indicator), use the **Executor** extension.

1.  Install the **Executor** extension for GNOME.
2.  Open Executor settings and configure a new command:
    * **Command:** `jiggler --status`
    * **Interval:** `1` (Update every second for real-time feedback)
    * **Left Click:** `jiggler --toggle`
3.  **Result:** You will see a clean dot next to your clock that changes automatically:
    * ⚫ **Off** (Script stopped)
    * 🟢 **Monitoring** (Safe zone)
    * 🔴 **Warning** (Idle > 30s)
    * ⚪ **Action** (Drawing square)

## 🛠️ Requirements
* Linux with **GNOME Desktop** (uses `org.gnome.Mutter.IdleMonitor`).
* **Wayland** session (can work on X11 but it's designed for Wayland).
* `ydotool` (installed automatically by the script).

## 📄 License
MIT License. Free to use, modify, and distribute.