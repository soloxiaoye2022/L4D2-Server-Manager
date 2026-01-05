# L4D2 Server Manager (L4M)

A powerful, modern Left 4 Dead 2 server management tool.
Designed for Linux environments, supporting all platforms (VPS, Dedicated Servers, Containers) with a smooth TUI (Text User Interface) and CLI operations.

## ✨ Key Features

*   **🚀 One-Click Install & Persistence**: Automatically installs to the system with persistent data storage.
*   **💻 Powerful CLI Tool**: Manage everything using the `l4m` command after installation. Supports self-update (`l4m update`).
*   **🖥️ Modern TUI**: Full keyboard-navigable graphical menu. No more tedious command typing.
*   **📦 Multi-Instance Support**: Deploy unlimited server instances, each with independent configuration and runtime.
*   **🛡️ Process Watchdog**: Smart `tmux`-based watchdog that automatically restarts the server 5 seconds after a crash.
*   **🔌 Plugin Manager**: Built-in plugin installer/uninstaller, adapted for multiple instances, supporting one-click installation from JS-MODS.
*   **🌐 All-Platform Compatibility**: Perfectly supports Root users, Non-Root users, and Proot/Chroot container environments.

## 📥 Quick Start

Run the following command in your terminal to install or start:

```bash
bash <(curl -s -L https://gh-proxy.com/https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh)
```

The script automatically detects your environment:
- **Root User**: Installs to `/usr/local/l4d2_manager`
- **Non-Root**: Installs to `~/.l4d2_manager`

## 📖 Usage Guide

After installation, use the `l4m` command anywhere:

```bash
l4m          # Open the main menu (TUI)
l4m update   # Update the manager to the latest version
l4m install  # Re-run the installation wizard (Repair)
```

### Main Modules

1.  **Deploy New Server**: 
    - Interactive wizard; just enter the server name and path.
    - Supports **Anonymous Login** and **Steam Account Login** (handles SteamCMD automatically).
    - Auto-generates optimized `server.cfg` and startup scripts.

2.  **Server Management**:
    - **Start/Stop/Restart**: One-click control with real-time status feedback.
    - **Console**: Access the server console directly (tmux-based). Press `Ctrl+B` then `D` to detach and keep it running in the background.
    - **Live Logs**: View server output in real-time.
    - **Startup Args**: Edit startup parameters (Map, Max Players, Tickrate, etc.) directly in the TUI.

3.  **Plugin Management**:
    - Automatically scans local or downloaded JS-MODS libraries.
    - Supports batch plugin selection and installation.
    - One-click deployment of SourceMod/MetaMod platforms.

## 🔧 Advanced Info

*   **Process Management**: Uses `tmux` instead of `screen` for more stable session management. Each server runs in an isolated tmux session named `l4d2_<server_name>`.
*   **Dependency Check**: Automatically checks and attempts to install necessary components like `tmux`, `curl`, `lib32gcc` on startup. Prompts for manual installation or tries `pkg` in non-Root environments.

## 🤝 Contribution

Issues and Pull Requests are welcome to help improve this tool!
