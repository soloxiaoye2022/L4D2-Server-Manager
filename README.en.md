# L4D2 Server Manager (L4M)

A powerful, modern Left 4 Dead 2 server management tool.
Designed for Linux environments, supporting all platforms (VPS, Dedicated Servers, Containers) with a smooth TUI (Text User Interface) and CLI operations.

## ✨ Key Features

*   **🌐 Multi-Language (I18N)**: Auto-detects language on first run (English/Simplified Chinese). Auto-configures system locale for Root users to fix garbled text.
*   **🚀 One-Click Install & Persistence**: Automatically installs to system. Default path unified to `~/L4D2_Servers` for easier management.
*   **💻 Powerful CLI Tool**: Manage everything using `l4m` command. Supports self-update (`l4m update`).
*   **🖥️ Modern TUI**: Full graphical menu with real-time traffic monitoring and progress bars for downloads.
*   **📦 Multi-Instance**: Hybrid deployment. Copies core binaries (`bin`, `hl2`) for stability, while symlinking assets (`maps`, `materials`) to save space.
*   **🔌 Smart Plugin Manager**: 
    *   **Global Repo**: Shared `~/L4D2_Plugins` directory saves space.
    *   **Install Tracking**: Tracks installed plugins to avoid duplicates.
    *   **One-Click Platform**: Installs SourceMod/MetaMod (prefers local package if available).
*   **🛡️ Watchdog & Auto-Start**: Auto-restarts crashed servers; supports boot auto-start (Systemd/Crontab).
*   **💾 Smart Backup**: Backs up core data (including plugin list) while excluding logs.
*   **📶 Traffic Monitor**: Precise per-port traffic stats for Root users (Realtime/Daily/Monthly).

## 📥 Quick Start

Run the following command in your terminal to install or start:

```bash
bash <(curl -s -L https://gh-proxy.com/https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh)
```

The script automatically detects your environment (supports sudo for dependency installation).

## 📖 Usage Guide

After installation, use the `l4m` command anywhere:

```bash
l4m          # Open the main menu (TUI)
l4m update   # Update the manager to the latest version
l4m install  # Re-run the installation wizard (Repair)
```

### Main Modules

1.  **Deploy New Server**: 
    - Interactive wizard with **Anonymous Login** (auto-fix download issues) and **Steam Account Login**.
    - Auto-generates optimized `server.cfg` and startup scripts.

2.  **Server Management**:
    - **Start/Stop/Restart**: One-click control with real-time status.
    - **Update Server**: Supports resume and auto-fix for update scripts.
    - **Traffic Stats**: View real-time bandwidth usage.
    - **Console**: Access server console (tmux). Press `Ctrl+B` then `D` to detach.

3.  **Plugin Management**:
    - Scans global plugin repository.
    - Marks installed plugins clearly.
    - Supports custom repo paths.

## 🔧 Advanced Info

*   **Process Management**: Uses `tmux` for stable session management.
*   **Container Ready**: Optimized for Docker/LXC environments with auto-locale fix.

## 🤝 Contribution

Issues and Pull Requests are welcome to help improve this tool!
