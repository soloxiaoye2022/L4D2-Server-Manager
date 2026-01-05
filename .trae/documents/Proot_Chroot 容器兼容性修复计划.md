# Proot/Chroot 容器兼容性修复计划

## 1. 问题分析
用户反馈在 Proot/Chroot 环境下（常见于 Termux、Linux Deploy 等）出现 `mkdir: cannot create directory '/proc/self/fd/steamcmd_common'` 错误。
这通常是因为：
1.  **路径判断逻辑缺陷**: 脚本通过 `cd "$(dirname "${BASH_SOURCE[0]}")"` 获取路径，而在管道运行 (`bash <(curl...)`) 时，`$0` 或 `BASH_SOURCE` 可能指向 `/proc/self/fd/x`（文件描述符），这在某些受限容器中无法作为有效目录进行操作。
2.  **硬编码的系统路径**: 直接使用 `/usr/local/l4d2_manager` 可能在非 Root 或 Proot 环境下不可写。

## 2. 解决方案

### A. 增强路径与环境检测
*   **管道运行检测**: 更严谨地判断是否通过管道运行，如果是，则强制使用**临时目录**或**用户主目录**作为临时的 `MANAGER_ROOT`，而不是依赖 `$0` 的路径。
*   **非 Root/Proot 兼容**:
    *   优先尝试安装到 `/usr/local` (需要 Root)。
    *   如果失败（无权限或只读文件系统），自动回退到用户主目录 `~/l4d2_manager`。
    *   相应地调整 `BIN_LINK` 的位置（如果无法写入 `/usr/bin`，则提示用户添加 PATH 或使用 alias）。

### B. 安装逻辑优化
*   **动态 INSTALL_DIR**:
    *   Root 用户 -> `/usr/local/l4d2_manager`
    *   普通用户/Proot -> `$HOME/.l4d2_manager`
*   **动态 BIN_DIR**:
    *   Root 用户 -> `/usr/bin`
    *   普通用户/Proot -> `$HOME/bin` (并检测 PATH)

### C. 修正 `init.sh` 头部逻辑
*   在定义全局变量 `MANAGER_ROOT` 之前，先进行环境嗅探。
*   如果检测到 `$0` 是 `/proc/self/fd/*`，立即切换到 `$HOME` 或 `/tmp` 进行操作，避免基于 `$0` 创建相对路径。

## 3. 实现步骤
1.  **修改 `MANAGER_ROOT` 获取逻辑**:
    *   如果 `$0` 包含 `/proc/self/fd` 或为空，判定为管道模式，设置 `MANAGER_ROOT` 为 `$HOME/.cache/l4m_install_tmp`（临时）。
2.  **重写 `install_system_wide`**:
    *   增加写入权限检查 (`/usr/local` 和 `/usr/bin`)。
    *   如果无权限，切换到用户模式安装 (`$HOME/.l4d2_manager`)。
3.  **更新 CLI 提示**:
    *   安装完成后，如果安装在用户目录且未在 PATH 中，提示用户 `export PATH=$PATH:~/bin`。

## 4. 文件修改
*   `server_install/linux/init.sh`: 全量更新头部路径判断和安装函数。

## 5. 执行计划
1.  **TodoWrite**: 记录任务。
2.  **代码修改**: 实施上述兼容性修复。
3.  **提交**: 推送更新。
