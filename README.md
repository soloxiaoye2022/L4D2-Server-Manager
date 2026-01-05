# Server Install Script
求生之路2服务端一键部署脚本

## 介绍
适用于求生之路2 (Left 4 Dead 2) 开服和管理插件的脚本集。
本脚本整合了常用的服务端安装、更新、启动以及插件管理功能。
部分代码参考或修改自其他开源项目，主体逻辑由 AI 辅助编写，作者进行二次修改和整合。

## 系统要求

*   **支持的发行版**：
    *   Ubuntu 16.04+
    *   Debian 9+
    *   CentOS 7+
*   **架构**：x86_64 (amd64)

## 食用方法

### 一键脚本

**通用（推荐）：**
```bash
bash <(curl -s -L https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh)
```

**大陆机器（加速）：**
```bash
bash <(curl -s -L https://gh-proxy.com/https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh)
```

### 手动安装
1.  下载仓库中的 `server_install/linux/init.sh` 文件。
2.  上传至服务器任意目录。
3.  赋予执行权限并运行：
    ```bash
    chmod +x init.sh
    ./init.sh
    ```

## 更新日志

**2026/01/05**
*   新增 Github 代理测速功能，优化国内下载体验。
*   优化依赖安装逻辑。

**2024**
*   初始化项目。
