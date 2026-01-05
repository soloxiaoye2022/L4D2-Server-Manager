# CLI 化与持久安装升级方案

## 1. 目标
将现有的 `init.sh` 脚本升级为一个可安装的系统级 CLI 工具 `l4m` (L4D2 Manager)。用户只需运行一次安装命令，后续即可通过 `l4m` 指令随时呼出管理界面，且支持在线自我更新。

## 2. 核心架构设计

### A. 安装器 (Installer)
*   **功能**:
    1.  检测系统环境 (Root 权限)。
    2.  创建持久化数据目录 `/usr/local/l4d2_manager`。
    3.  下载最新版 `init.sh` 并重命名为 `l4m`。
    4.  赋予执行权限并建立软链接 `/usr/bin/l4m` -> `/usr/local/l4d2_manager/l4m`。
    5.  迁移或初始化 `servers.dat` 到持久化目录。
    6.  下载 `JS-MODS` 资源（可选，或仅在需要时下载）。

### B. 主程序 (l4m / init.sh) 改造
*   **自更新模块**:
    *   在 TUI 主菜单增加 `[系统更新]` 选项。
    *   逻辑: 检查 GitHub 仓库的 `commit hash` 或版本号，如果不同则下载覆盖 `/usr/local/l4d2_manager/l4m`。
*   **路径适配**:
    *   将硬编码的相对路径改为基于安装目录的绝对路径 (e.g., `MANAGER_ROOT="/usr/local/l4d2_manager"`).
    *   确保 `servers.dat` 和 `steamcmd` 存储在持久化目录中。

### C. 部署逻辑调整
*   **安装命令**: 保持 `bash <(curl ...)` 形式，但该命令现在执行的是一个“引导安装脚本”，而非直接运行管理器。

## 3. 实现步骤

1.  **编写引导安装脚本 (`install.sh`)**:
    *   负责初始化目录、下载主脚本、创建软链接。
    *   此脚本将替代原 `init.sh` 作为用户入口，或者让 `init.sh` 具备“自我安装”能力（检测到未安装则执行安装流程）。
    *   **方案选择**: 让 `init.sh` 具备双重身份。如果直接运行且未在系统路径，提示/执行安装；如果通过 `l4m` 运行，则进入管理模式。

2.  **改造 `init.sh`**:
    *   增加 `install_system_wide` 函数。
    *   增加 `self_update` 函数。
    *   修改 `MANAGER_ROOT` 判定逻辑：优先使用 `/usr/local/l4d2_manager`。

3.  **持久化数据迁移**:
    *   确保旧的 `servers.dat` 在安装时被保留（如果有）。

4.  **CLI 快捷指令**:
    *   支持 `l4m update` (更新脚本), `l4m start <server>` (快速启动) 等参数化调用（进阶功能，先做基础 TUI 入口）。

## 4. 文件结构规划
*   `/usr/local/l4d2_manager/`
    *   `l4m` (主脚本)
    *   `servers.dat` (数据文件)
    *   `config.ini` (可选配置)
    *   `steamcmd_common/` (公用 SteamCMD)
    *   `js-mods/` (插件库缓存)

## 5. 执行计划
1.  **TodoWrite**: 更新任务列表。
2.  **修改 `init.sh`**:
    *   添加“自我安装”逻辑。
    *   添加“自我更新”逻辑。
    *   调整路径变量。
3.  **验证**: 模拟用户执行 `bash init.sh` 触发安装，然后测试 `l4m` 命令。
