# Server Install Script
Left 4 Dead 2 Server One-Click Deployment Script

## Introduction
A script collection for setting up and managing Left 4 Dead 2 servers and plugins.
This script integrates common functions such as server installation, updating, starting, and plugin management.
Some code is referenced or modified from other open-source projects. The main logic was written with AI assistance and modified by the author.

## System Requirements

*   **Supported Distributions**:
    *   Ubuntu 16.04+
    *   Debian 9+
    *   CentOS 7+
*   **Architecture**: x86_64 (amd64)

## Usage

### One-Click Script

**General (Recommended):**
```bash
bash <(curl -s -L https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh)
```

**Mainland China (Accelerated):**
```bash
bash <(curl -s -L https://gh-proxy.com/https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh)
```

### Manual Installation
1.  Download the `server_install/linux/init.sh` file from the repository.
2.  Upload it to your server.
3.  Grant execution permissions and run:
    ```bash
    chmod +x init.sh
    ./init.sh
    ```

## Update Log

**2026/01/05**
*   Added Github proxy speed test to optimize download speed in Mainland China.
*   Optimized dependency installation logic.

**2024**
*   Initial release.
