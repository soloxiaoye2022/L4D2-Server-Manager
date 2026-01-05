# L4M 开机自启与功能完善计划

## 1. 核心任务：开机自启机制 (Boot Persistence)

### A. 服务端自启 (Per-Instance Autostart)
用户需要在 TUI 中选择特定服务端开启“开机自启”。
*   **Root 环境 (Systemd)**:
    *   为每个实例生成 `/etc/systemd/system/l4d2_<name>.service`。
    *   服务类型 `Type=forking` 或 `simple`。
    *   核心命令：`tmux new-session -d -s l4d2_<name> <run_guard.sh>`。
    *   停止命令：`tmux kill-session -t l4d2_<name>`。
*   **非 Root/Termux 环境 (Cron/Rc.local)**:
    *   使用 `crontab -e` 添加 `@reboot /path/to/l4m start <instance_name>`。
    *   或者修改 `~/.bashrc` / `termux-boot` (如果是 Termux)。
    *   **策略**: 统一使用 `crontab` 作为非 Root 的通用方案，因为它最稳定。Termux 可能需要额外的 `termux-services` 支持，但 crontab 是最通用的 fallback。

### B. CLI 管理器自启 (Manager Autostart)
虽然 CLI 本身是被动调用的工具，不需要“运行”，但如果用户的意图是“开机后自动恢复之前的服务器状态”，我们需要一个全局的“恢复服务”。
*   **Global Resume Service**:
    *   创建一个 `l4m-resume` 服务或脚本。
    *   开机时，它读取 `servers.dat`，检查哪些服务器被标记为 `AUTOSTART=true`，然后批量启动它们。

## 2. 脑暴优化与新功能 (Brainstorming)

### A. 性能与监控优化
*   **📊 实时资源监控**: 在 TUI 中显示 CPU/内存占用 (集成 `top` 或读取 `/proc` 数据)。
*   **🧹 自动清理**: 清理 SteamCMD 缓存、旧日志、临时文件的功能。

### B. 网络与安全
*   **🛡️ 防火墙配置**: 检测 `ufw` 或 `iptables`，一键开放服务器端口 (27015 等)。
*   **🔍 端口检测**: 启动前检测端口是否被占用，避免静默失败。

### C. 游戏性增强
*   **🌍 Rcon 远程控制**: 在 TUI 中集成简易 Rcon 客户端，不进入游戏也能踢人、换图。
*   **🔄 定时任务**: 在 TUI 中设置定时重启、定时发公告 (利用 crontab)。

### D. 备份与迁移
*   **💾 一键备份**: 备份整个服务端或仅配置/插件到 `.tar.gz`。
*   **☁️ 异地恢复**: 支持从备份包恢复服务端。

## 3. 本次实施范围
为了保持迭代稳健，本次集中实现：
1.  **开机自启管理**:
    *   在 TUI 服务器管理菜单增加 `[开机自启: 开/关]` 切换。
    *   实现 Systemd (Root) 和 Crontab (User) 两种后端。
    *   实现 `l4m boot-resume` 命令，用于开机时批量启动。
2.  **备份功能**: 简单的本地备份/恢复。
3.  **网络优化**: 简单的端口占用检测。

## 4. 文件修改
*   `server_install/linux/init.sh`:
    *   增加 `toggle_autostart` 函数。
    *   增加 `backup_server` 函数。
    *   增加 `check_port` 逻辑。
    *   增加 `boot_resume` 处理逻辑。

## 5. 执行步骤
1.  **TodoWrite**: 记录任务。
2.  **代码实现**: 编写自启逻辑和备份逻辑。
3.  **测试**: 模拟 Root 和非 Root 环境下的行为。
