#!/bin/bash

# 0. 强制设置 Locale 为 UTF-8，解决中文乱码问题
if command -v locale >/dev/null 2>&1; then
    if locale -a 2>/dev/null | grep -q "C.UTF-8"; then
        export LANG=C.UTF-8; export LC_ALL=C.UTF-8
    elif locale -a 2>/dev/null | grep -q "zh_CN.UTF-8"; then
        export LANG=zh_CN.UTF-8; export LC_ALL=zh_CN.UTF-8
    elif locale -a 2>/dev/null | grep -q "en_US.UTF-8"; then
        export LANG=en_US.UTF-8; export LC_ALL=en_US.UTF-8
    fi
else
    # 兜底 (Proot 环境可能没有 locale 命令)
    export LANG=C.UTF-8; export LC_ALL=C.UTF-8
fi

#=============================================================================
# L4D2 Server Manager (L4M)
# 功能: 全平台兼容 (Root/Non-Root/Proot)、多实例管理、CLI/TUI、自启/备份
#=============================================================================

# 1. 定义候选安装路径
SYSTEM_INSTALL_DIR="/usr/local/l4d2_manager"
USER_INSTALL_DIR="$HOME/.l4d2_manager"
SYSTEM_BIN="/usr/bin/l4m"
USER_BIN="$HOME/bin/l4m"


# 2. 智能探测运行环境
if [[ "$0" == "$SYSTEM_INSTALL_DIR/l4m" ]] || [[ -L "$0" && "$(readlink -f "$0")" == "$SYSTEM_INSTALL_DIR/l4m" ]]; then
    MANAGER_ROOT="$SYSTEM_INSTALL_DIR"
    INSTALL_TYPE="system"
elif [[ "$0" == "$USER_INSTALL_DIR/l4m" ]] || [[ -L "$0" && "$(readlink -f "$0")" == "$USER_INSTALL_DIR/l4m" ]]; then
    MANAGER_ROOT="$USER_INSTALL_DIR"
    INSTALL_TYPE="user"
else
    if [[ "$0" == *"bash"* ]] || [[ "$0" == *"/fd/"* ]]; then
        MANAGER_ROOT="/tmp/l4m_install_temp"
        mkdir -p "$MANAGER_ROOT" 2>/dev/null || MANAGER_ROOT="$HOME/.cache/l4m_temp"
        mkdir -p "$MANAGER_ROOT"
    else
        MANAGER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    INSTALL_TYPE="temp"
fi

# 3. 确定最终使用的配置路径
if [[ "$INSTALL_TYPE" != "temp" ]]; then
    FINAL_ROOT="$MANAGER_ROOT"
else
    if [ "$EUID" -eq 0 ]; then FINAL_ROOT="$SYSTEM_INSTALL_DIR"; else FINAL_ROOT="$USER_INSTALL_DIR"; fi
fi

DATA_FILE="${FINAL_ROOT}/servers.dat"
PLUGIN_CONFIG="${FINAL_ROOT}/plugin_config.dat"
if [ -f "$PLUGIN_CONFIG" ]; then JS_MODS_DIR=$(cat "$PLUGIN_CONFIG"); else
    if [ "$EUID" -eq 0 ]; then JS_MODS_DIR="/root/L4D2_Plugins"; else JS_MODS_DIR="$HOME/L4D2_Plugins"; fi
fi
# 自动创建预设的插件文件夹
mkdir -p "$JS_MODS_DIR"

STEAMCMD_DIR="${FINAL_ROOT}/steamcmd_common"
SERVER_CACHE_DIR="${FINAL_ROOT}/server_cache"
TRAFFIC_DIR="${FINAL_ROOT}/traffic_logs"
BACKUP_DIR="${FINAL_ROOT}/backups"
DEFAULT_APPID="222860"
CONFIG_FILE="${FINAL_ROOT}/config.dat"

# I18N
load_i18n() {
    if [ "$1" == "zh" ]; then
        M_TITLE="=== L4D2 管理器 (L4M) ==="
        M_WELCOME="欢迎使用 L4D2 Server Manager (L4M)"
        M_TEMP_RUN="检测到您当前通过临时方式运行 (管道/临时目录)。"
        M_REC_INSTALL="为了获得最佳体验，建议将管理器安装到系统："
        M_F_PERSIST="  • ${GREEN}数据持久化${NC}: 服务器配置和数据将安全保存，防误删。"
        M_F_ACCESS="  • ${GREEN}便捷访问${NC}: 安装后只需输入 ${CYAN}l4m${NC} 即可随时管理。"
        M_F_ADV="  • ${GREEN}高级功能${NC}: 支持开机自启、流量监控等特性。"
        M_ASK_INSTALL="是否立即安装到系统? (Y/n): "
        M_TEMP_MODE="${GREY}进入临时运行模式...${NC}"
        M_MAIN_MENU="L4M 主菜单"
        M_DEPLOY="部署新实例"
        M_MANAGE="实例管理"
        M_UPDATE="系统更新"
        M_LANG="切换语言 / Language"
        M_EXIT="退出"
        M_SUCCESS="${GREEN}[成功]${NC}"
        M_FAILED="${RED}[失败]${NC}"
        M_INIT_INSTALL="正在初始化安装向导..."
        M_SYS_DIR_RO="${RED}系统目录不可写，回退到用户目录...${NC}"
        M_INSTALL_FAIL="${RED}安装失败。${NC}"
        M_NO_PERM="${RED}无权限创建${NC}"
        M_INSTALL_PATH="安装路径:"
        M_DL_SCRIPT="${YELLOW}下载最新脚本...${NC}"
        M_DL_FAIL="${RED}下载失败${NC}"
        M_LINK_CREATED="${GREEN}链接已创建:${NC}"
        M_LINK_FAIL="${YELLOW}无法创建链接，请手动添加 alias${NC}"
        M_ADD_PATH="${YELLOW}请将 $HOME/bin 加入 PATH 环境变量。${NC}"
        M_INSTALL_DONE="${GREEN}安装完成！输入 l4m 启动。${NC}"
        M_CHECK_UPDATE="${CYAN}检查更新...${NC}"
        M_UPDATE_SUCCESS="${GREEN}更新成功！${NC}"
        M_VERIFY_FAIL="${RED}校验失败${NC}"
        M_CONN_FAIL="${RED}连接失败${NC}"
        M_MISSING_DEPS="${YELLOW}检测到缺失依赖:${NC}"
        M_TRY_SUDO="${CYAN}尝试使用 sudo 安装 (可能需输密码)...${NC}"
        M_INSTALL_OK="${GREEN}安装成功${NC}"
        M_MANUAL_INSTALL="${RED}无法自动安装。请手动执行:${NC}"
        M_NEED_ROOT="${RED}需Root权限${NC}"
        M_TRAFFIC_STATS="${CYAN}流量统计:${NC}"
        M_REALTIME="实时:"
        M_TODAY="今日:"
        M_MONTH="本月:"
        M_NO_HISTORY="暂无历史数据"
        M_PRESS_KEY="${YELLOW}按任意键返回...${NC}"
        M_INIT_STEAMCMD="${YELLOW}初始化 SteamCMD...${NC}"
        M_DL_STEAMCMD="${CYAN}正在下载 SteamCMD 安装包...${NC}"
        M_EXTRACTING="${CYAN}解压中...${NC}"
        M_SRV_NAME="服务器名称"
        M_NAME_EXIST="${RED}名称已存在${NC}"
        M_INSTALL_DIR="安装目录"
        M_DIR_NOT_EMPTY="${RED}目录不为空${NC}"
        M_LOGIN_ANON="1. 匿名登录"
        M_LOGIN_ACC="2. 账号登录"
        M_SELECT_1_2="选择 (1/2)"
        M_START_DL="${CYAN}开始下载...${NC}"
        M_ACC="账号"
        M_PASS="密码"
        M_NO_SRCDS="未找到 srcds_run，请检查上方 SteamCMD 报错。"
        M_SRV_READY="服务器已就绪:"
        M_ST_RUN="${GREEN}[运行]${NC}"
        M_ST_STOP="${RED}[停止]${NC}"
        M_ST_AUTO="${CYAN}[自启]${NC}"
        M_NO_INSTANCE="${YELLOW}无实例${NC}"
        M_RETURN="返回"
        M_SELECT_INSTANCE="选择实例:"
        M_OPT_START="启动"
        M_OPT_STOP="停止"
        M_OPT_RESTART="重启"
        M_OPT_UPDATE="更新服务端"
        M_OPT_CONSOLE="控制台"
        M_OPT_LOGS="日志"
        M_OPT_TRAFFIC="流量统计"
        M_OPT_ARGS="配置启动参数"
        M_OPT_PLUGINS="插件管理"
        M_OPT_BACKUP="备份服务端"
        M_OPT_AUTO_ON="开启自启"
        M_OPT_AUTO_OFF="关闭自启"
        M_STOP_BEFORE_UPDATE="${YELLOW}更新前需停止服务器${NC}"
        M_ASK_STOP_UPDATE="立即停止并更新? (y/n): "
        M_NO_UPDATE_SCRIPT="${RED}未找到 update.txt${NC}"
        M_ASK_REBUILD="${YELLOW}是否以匿名模式重建更新脚本? (y/n)${NC}"
        M_CALL_STEAMCMD="${CYAN}正在调用 SteamCMD 更新...${NC}"
        M_UPDATED="更新完成"
        M_DEPLOY_FAIL="部署失败"
        M_PORT_OCCUPIED="${RED}端口被占用!${NC}"
        M_START_SENT="${GREEN}启动指令已发送${NC}"
        M_STOPPED="${GREEN}已停止${NC}"
        M_NOT_RUNNING="${RED}未运行${NC}"
        M_DETACH_HINT="${YELLOW}按 Ctrl+B, D 离线${NC}"
        M_NO_LOG="${RED}无日志(请确认已加-condebug)${NC}"
        M_CURRENT="${CYAN}当前:${NC}"
        M_NEW_CMD="${YELLOW}新指令:${NC}"
        M_SAVED="${GREEN}保存${NC}"
        M_AUTO_SET="${GREEN}自启已设置为:${NC}"
        M_BACKUP_START="${CYAN}正在执行精简备份 (含Metamod、插件清单及数据)...${NC}"
        M_BACKUP_OK="${GREEN}备份成功:${NC}"
        M_BACKUP_FAIL="${RED}备份失败${NC}"
        M_DIR_ERR="${RED}目录错${NC}"
        M_PLUG_INSTALL="安装插件"
        M_PLUG_PLAT="安装平台(SM/MM)"
        M_PLUG_REPO="设置插件库目录"
        M_PLUG_UNINSTALL="卸载插件"
        M_INSTALLED_PLUGINS="已安装插件"
        M_DOWNLOAD_PACKAGES="下载插件整合包"
        M_SELECT_PACKAGES="选择插件整合包"
        M_CUR_REPO="${CYAN}当前插件库:${NC}"
        M_NEW_REPO_PROMPT="${YELLOW}请输入新路径 (留空取消):${NC}"
        M_REPO_NOT_FOUND="${RED}插件库不存在:${NC}"
        M_REPO_EMPTY="插件库为空"
        M_INSTALLED="${GREY}[已装]${NC}"
        M_SELECT_HINT="${YELLOW}Space选 Enter确${NC}"
        M_DONE="${GREEN}完成${NC}"
        M_LOCAL_PKG="${CYAN}发现本地预置包，正在安装...${NC}"
        M_CONN_OFFICIAL="${CYAN}正在连接官网(sourcemod.net)获取最新版本...${NC}"
        M_GET_LINK_FAIL="${RED}[FAILED] 无法获取下载链接，请检查网络或手动下载。${NC}"
        M_FOUND_EXISTING="检测到系统已安装 L4M，正在启动..."
        M_UPDATE_CACHE="${CYAN}正在更新服务端缓存 (首次可能较慢)...${NC}"
        M_COPY_CACHE="${CYAN}正在从缓存部署实例 (本地复制)...${NC}"
    else
        M_TITLE="=== L4D2 Manager (L4M) ==="
        M_WELCOME="Welcome to L4D2 Server Manager (L4M)"
        M_TEMP_RUN="Detected temporary run mode (Pipe/Temp Dir)."
        M_REC_INSTALL="It is recommended to install L4M to system for best experience:"
        M_F_PERSIST="  • ${GREEN}Persistence${NC}: Configs and data are saved safely."
        M_F_ACCESS="  • ${GREEN}Easy Access${NC}: Type ${CYAN}l4m${NC} to manage anytime."
        M_F_ADV="  • ${GREEN}Advanced${NC}: Auto-start, Traffic Monitor supported."
        M_ASK_INSTALL="Install to system now? (Y/n): "
        M_TEMP_MODE="${GREY}Entering temporary mode...${NC}"
        M_MAIN_MENU="Main Menu"
        M_DEPLOY="Deploy New Instance"
        M_MANAGE="Manage Instances"
        M_UPDATE="System Update"
        M_LANG="Change Language"
        M_EXIT="Exit"
        M_SUCCESS="${GREEN}[SUCCESS]${NC}"
        M_FAILED="${RED}[FAILED]${NC}"
        M_INIT_INSTALL="Initializing installation wizard..."
        M_SYS_DIR_RO="${RED}System dir read-only, fallback to user dir...${NC}"
        M_INSTALL_FAIL="${RED}Install failed.${NC}"
        M_NO_PERM="${RED}No permission to create${NC}"
        M_INSTALL_PATH="Install Path:"
        M_DL_SCRIPT="${YELLOW}Downloading latest script...${NC}"
        M_DL_FAIL="${RED}Download failed${NC}"
        M_LINK_CREATED="${GREEN}Link created:${NC}"
        M_LINK_FAIL="${YELLOW}Link failed, please add alias manually${NC}"
        M_ADD_PATH="${YELLOW}Please add \$HOME/bin to PATH env.${NC}"
        M_INSTALL_DONE="${GREEN}Installed! Type l4m to start.${NC}"
        M_CHECK_UPDATE="${CYAN}Checking for updates...${NC}"
        M_UPDATE_SUCCESS="${GREEN}Update successful!${NC}"
        M_VERIFY_FAIL="${RED}Verification failed${NC}"
        M_CONN_FAIL="${RED}Connection failed${NC}"
        M_MISSING_DEPS="${YELLOW}Missing dependencies:${NC}"
        M_TRY_SUDO="${CYAN}Trying sudo install (password might be needed)...${NC}"
        M_INSTALL_OK="${GREEN}Install successful${NC}"
        M_MANUAL_INSTALL="${RED}Auto-install failed. Please run manually:${NC}"
        M_NEED_ROOT="${RED}Root required${NC}"
        M_TRAFFIC_STATS="${CYAN}Traffic Stats:${NC}"
        M_REALTIME="Realtime:"
        M_TODAY="Today:"
        M_MONTH="Month:"
        M_NO_HISTORY="No history data"
        M_PRESS_KEY="${YELLOW}Press any key to return...${NC}"
        M_INIT_STEAMCMD="${YELLOW}Initializing SteamCMD...${NC}"
        M_DL_STEAMCMD="${CYAN}Downloading SteamCMD...${NC}"
        M_EXTRACTING="${CYAN}Extracting...${NC}"
        M_SRV_NAME="Server Name"
        M_NAME_EXIST="${RED}Name exists${NC}"
        M_INSTALL_DIR="Install Dir"
        M_DIR_NOT_EMPTY="${RED}Dir not empty${NC}"
        M_LOGIN_ANON="1. Anonymous"
        M_LOGIN_ACC="2. Account"
        M_SELECT_1_2="Select (1/2)"
        M_START_DL="${CYAN}Downloading...${NC}"
        M_ACC="Account"
        M_PASS="Password"
        M_NO_SRCDS="srcds_run not found, check SteamCMD errors above."
        M_SRV_READY="Server ready:"
        M_ST_RUN="${GREEN}[RUN]${NC}"
        M_ST_STOP="${RED}[STOP]${NC}"
        M_ST_AUTO="${CYAN}[AUTO]${NC}"
        M_NO_INSTANCE="${YELLOW}No instances${NC}"
        M_RETURN="Return"
        M_SELECT_INSTANCE="Select Instance:"
        M_OPT_START="Start"
        M_OPT_STOP="Stop"
        M_OPT_RESTART="Restart"
        M_OPT_UPDATE="Update Server"
        M_OPT_CONSOLE="Console"
        M_OPT_LOGS="Logs"
        M_OPT_TRAFFIC="Traffic Stats"
        M_OPT_ARGS="Config Args"
        M_OPT_PLUGINS="Plugins"
        M_OPT_BACKUP="Backup"
        M_OPT_AUTO_ON="Enable Auto-start"
        M_OPT_AUTO_OFF="Disable Auto-start"
        M_STOP_BEFORE_UPDATE="${YELLOW}Stop server before update${NC}"
        M_ASK_STOP_UPDATE="Stop and update now? (y/n): "
        M_NO_UPDATE_SCRIPT="${RED}update.txt not found${NC}"
        M_ASK_REBUILD="${YELLOW}Rebuild anonymous update script? (y/n)${NC}"
        M_CALL_STEAMCMD="${CYAN}Calling SteamCMD update...${NC}"
        M_UPDATED="Update completed"
        M_DEPLOY_FAIL="Deploy Failed"
        M_PORT_OCCUPIED="${RED}Port occupied!${NC}"
        M_START_SENT="${GREEN}Start command sent${NC}"
        M_STOPPED="${GREEN}Stopped${NC}"
        M_NOT_RUNNING="${RED}Not running${NC}"
        M_DETACH_HINT="${YELLOW}Press Ctrl+B, D to detach${NC}"
        M_NO_LOG="${RED}No log (check -condebug)${NC}"
        M_CURRENT="${CYAN}Current:${NC}"
        M_NEW_CMD="${YELLOW}New:${NC}"
        M_SAVED="${GREEN}Saved${NC}"
        M_AUTO_SET="${GREEN}Auto-start set to:${NC}"
        M_BACKUP_START="${CYAN}Backing up (MM, plugins, data)...${NC}"
        M_BACKUP_OK="${GREEN}Backup success:${NC}"
        M_BACKUP_FAIL="${RED}Backup failed${NC}"
        M_DIR_ERR="${RED}Dir Error${NC}"
        M_PLUG_INSTALL="Install Plugin"
        M_PLUG_PLAT="Install Platform (SM/MM)"
        M_PLUG_REPO="Set Plugin Repo"
        M_PLUG_UNINSTALL="Uninstall Plugin"
        M_INSTALLED_PLUGINS="Installed Plugins"
        M_DOWNLOAD_PACKAGES="Download Plugin Packages"
        M_SELECT_PACKAGES="Select Plugin Packages"
        M_CUR_REPO="${CYAN}Current Repo:${NC}"
        M_NEW_REPO_PROMPT="${YELLOW}New Path (Empty to cancel):${NC}"
        M_REPO_NOT_FOUND="${RED}Repo not found:${NC}"
        M_REPO_EMPTY="Repo empty"
        M_INSTALLED="${GREY}[Inst]${NC}"
        M_SELECT_HINT="${YELLOW}Space:Select Enter:Confirm${NC}"
        M_DONE="${GREEN}Done${NC}"
        M_LOCAL_PKG="${CYAN}Found local package, installing...${NC}"
        M_CONN_OFFICIAL="${CYAN}Connecting to sourcemod.net...${NC}"
        M_GET_LINK_FAIL="${RED}[FAILED] Cannot get link, check network.${NC}"
        M_FOUND_EXISTING="Detected existing L4M installation, launching..."
        M_UPDATE_CACHE="${CYAN}Updating server cache (might take time)...${NC}"
        M_COPY_CACHE="${CYAN}Deploying from cache (local copy)...${NC}"
    fi
}

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
GREY='\033[90m'
NC='\033[0m'

#=============================================================================
# 0. 智能安装与更新模块
#=============================================================================
install_smart() {
    select_mirror
    echo -e "${CYAN}$M_INIT_INSTALL${NC}"
    local target_dir=""
    local link_path=""
    
    if [ "$EUID" -eq 0 ]; then
        target_dir="$SYSTEM_INSTALL_DIR"; link_path="$SYSTEM_BIN"
    else
        target_dir="$USER_INSTALL_DIR"; link_path="$USER_BIN"
    fi
    
    if ! mkdir -p "$target_dir" 2>/dev/null; then
        if [ "$target_dir" == "$SYSTEM_INSTALL_DIR" ]; then
             echo -e "$M_SYS_DIR_RO"
             target_dir="$USER_INSTALL_DIR"; link_path="$USER_BIN"
             mkdir -p "$target_dir" || { echo -e "$M_INSTALL_FAIL"; exit 1; }
        else
             echo -e "$M_NO_PERM $target_dir"; exit 1;
        fi
    fi

    echo -e "${CYAN}$M_INSTALL_PATH $target_dir${NC}"
    mkdir -p "$target_dir" "${target_dir}/steamcmd_common" "${target_dir}/js-mods" "${target_dir}/backups"
    
    if [ -f "$0" ] && [[ "$0" != *"bash"* ]] && [[ "$0" != *"/fd/"* ]]; then
        cp "$0" "$target_dir/l4m"
    else
        echo -e "$M_DL_SCRIPT"
        curl -L -# "$UPDATE_URL" -o "$target_dir/l4m" || { echo -e "$M_DL_FAIL"; exit 1; }
    fi
    chmod +x "$target_dir/l4m"
    
    mkdir -p "$(dirname "$link_path")"
    if ln -sf "$target_dir/l4m" "$link_path" 2>/dev/null; then
        echo -e "$M_LINK_CREATED $link_path"
    else
        echo -e "$M_LINK_FAIL l4m='$target_dir/l4m'"
    fi
    
    if [ "$MANAGER_ROOT" != "$target_dir" ] && [ -f "${MANAGER_ROOT}/servers.dat" ]; then
         cp "${MANAGER_ROOT}/servers.dat" "$target_dir/"
    fi
    touch "$target_dir/servers.dat"
    
    if [[ "$link_path" == "$USER_BIN" ]] && [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo -e "$M_ADD_PATH"
    fi

    echo -e "$M_INSTALL_DONE"
    sleep 2
    exec "$target_dir/l4m"
}

self_update() {
    select_mirror
    echo -e "$M_CHECK_UPDATE"
    local temp="/tmp/l4m_upd.sh"
    if curl -L -# "$UPDATE_URL" -o "$temp"; then
        if grep -q "main()" "$temp"; then
            mv "$temp" "$FINAL_ROOT/l4m"; chmod +x "$FINAL_ROOT/l4m"
            echo -e "$M_UPDATE_SUCCESS"; sleep 1; exec "$FINAL_ROOT/l4m"
        else
            echo -e "$M_VERIFY_FAIL"; rm "$temp"
        fi
    else
        echo -e "$M_CONN_FAIL"
    fi
    read -n 1 -s -r
}

#=============================================================================
# 1. 基础功能
#=============================================================================
check_deps() {
    local miss=()
    local req=("tmux" "curl" "wget" "tar" "tree" "sed" "awk" "lsof" "7z" "unzip")
    for c in "${req[@]}"; do command -v "$c" >/dev/null 2>&1 || miss+=("$c"); done
    if [ ${#miss[@]} -eq 0 ]; then return 0; fi
    
    echo -e "$M_MISSING_DEPS ${miss[*]}"
    local cmd=""
    if [ -f /etc/debian_version ]; then
        # 添加7zip和unzip依赖，使用p7zip-full和unzip包
        local deb_pkgs="${miss[*]}"
        # 如果需要安装7z，替换为p7zip-full
        deb_pkgs=$(echo "$deb_pkgs" | sed 's/7z/p7zip-full/g')
        cmd="apt-get update -qq && apt-get install -y -qq $deb_pkgs lib32gcc-s1 lib32stdc++6 ca-certificates"
    elif [ -f /etc/redhat-release ]; then
        # 添加7zip和unzip依赖
        local rhel_pkgs="${miss[*]}"
        # 如果需要安装7z，替换为p7zip
        rhel_pkgs=$(echo "$rhel_pkgs" | sed 's/7z/p7zip/g')
        cmd="yum install -y -q $rhel_pkgs glibc.i686 libstdc++.i686"
    fi

    if [ "$EUID" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            echo -e "$M_TRY_SUDO"
            if [ -f /etc/debian_version ]; then sudo dpkg --add-architecture i386 >/dev/null 2>&1; fi
            if sudo bash -c "$cmd"; then echo -e "$M_INSTALL_OK"; return 0; fi
        fi
        if command -v pkg >/dev/null; then pkg install -y "${miss[@]}"; return; fi
        echo -e "$M_MANUAL_INSTALL sudo $cmd"; read -n 1 -s -r; return
    fi
    
    if [ -f /etc/debian_version ]; then dpkg --add-architecture i386 >/dev/null 2>&1; fi
    eval "$cmd"
}

check_port() {
    local port="$1"
    if command -v lsof >/dev/null; then lsof -i ":$port" >/dev/null 2>&1; return $?; fi
    if command -v netstat >/dev/null; then netstat -tuln | grep -q ":$port "; return $?; fi
    (echo > /dev/tcp/127.0.0.1/$port) >/dev/null 2>&1; return $?
}

#=============================================================================
# X. 流量监控 (Root Only)
#=============================================================================
traffic_daemon() {
    if [ "$EUID" -ne 0 ]; then echo "Root only"; exit 1; fi
    mkdir -p "$TRAFFIC_DIR"
    iptables -N L4M_STATS 2>/dev/null
    if ! iptables -C INPUT -j L4M_STATS 2>/dev/null; then iptables -I INPUT -j L4M_STATS; fi
    if ! iptables -C OUTPUT -j L4M_STATS 2>/dev/null; then iptables -I OUTPUT -j L4M_STATS; fi
    
    declare -A last_rx; declare -A last_tx
    
    while true; do
        while IFS='|' read -r n p s port auto; do
            if [ -n "$port" ]; then
                for proto in udp tcp; do
                    if ! iptables -C L4M_STATS -p $proto --dport "$port" 2>/dev/null; then iptables -A L4M_STATS -p $proto --dport "$port"; fi
                    if ! iptables -C L4M_STATS -p $proto --sport "$port" 2>/dev/null; then iptables -A L4M_STATS -p $proto --sport "$port"; fi
                done
            fi
        done < "$DATA_FILE"
        
        local ts=$(date +%s); local m=$(date +%Y%m)
        local out=$(iptables -nvxL L4M_STATS)
        
        while IFS='|' read -r n p s port auto; do
            if [ -n "$port" ]; then
                local rx=$(echo "$out" | awk -v p="dpt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
                local tx=$(echo "$out" | awk -v p="spt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
                local drx=0; local dtx=0
                
                if [ -n "${last_rx[$port]}" ]; then
                    drx=$((rx - ${last_rx[$port]})); dtx=$((tx - ${last_tx[$port]}))
                    if [ $drx -lt 0 ]; then drx=$rx; fi; if [ $dtx -lt 0 ]; then dtx=$tx; fi
                fi
                last_rx[$port]=$rx; last_tx[$port]=$tx
                
                if [ $drx -gt 0 ] || [ $dtx -gt 0 ]; then
                    echo "$ts,$drx,$dtx" >> "${TRAFFIC_DIR}/${n}_${m}.csv"
                fi
            fi
        done < "$DATA_FILE"
        sleep 300
    done
}

view_traffic() {
    local n="$1"; local port="$2"
    if [ "$EUID" -ne 0 ]; then echo -e "$M_NEED_ROOT"; read -n 1 -s -r; return; fi
    
    while true; do
        tui_header; echo -e "$M_TRAFFIC_STATS $n ($port)\n----------------------------------------"
        local r1=$(iptables -nvxL L4M_STATS | awk -v p="dpt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
        local t1=$(iptables -nvxL L4M_STATS | awk -v p="spt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
        sleep 1
        local r2=$(iptables -nvxL L4M_STATS | awk -v p="dpt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
        local t2=$(iptables -nvxL L4M_STATS | awk -v p="spt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
        
        echo -e "$M_REALTIME ↓$(numfmt --to=iec --suffix=B/s $((r2-r1)))  ↑$(numfmt --to=iec --suffix=B/s $((t2-t1)))"
        echo "----------------------------------------"
        
        local f="${TRAFFIC_DIR}/${n}_$(date +%Y%m).csv"
        if [ -f "$f" ]; then
            local today=$(date +%s -d "today 00:00")
            local stats=$(awk -F, -v d="$today" '{tr+=$2; tt+=$3} $1 >= d {dr+=$2; dt+=$3} END {printf "%d %d %d %d", dr, dt, tr, tt}' "$f")
            read dr dt tr tt <<< "$stats"
            echo -e "$M_TODAY ↓$(numfmt --to=iec $dr) ↑$(numfmt --to=iec $dt)"
            echo -e "$M_MONTH ↓$(numfmt --to=iec $tr) ↑$(numfmt --to=iec $tt)"
        else
            echo "$M_NO_HISTORY"
        fi
        echo "----------------------------------------"
        echo -e "$M_PRESS_KEY"; read -n 1 -s -r -t 5 k; if [ -n "$k" ]; then break; fi
    done
}

#=============================================================================
# 2. TUI 库
#=============================================================================
tui_header() { clear; echo -e "${BLUE}$M_TITLE${NC}\n"; }

tui_input() {
    local p="$1"; local d="$2"; local v="$3"; local pass="$4"
    if [ -n "$d" ]; then echo -e "${YELLOW}$p ${GREY}[默认: $d]${NC}"; else echo -e "${YELLOW}$p${NC}"; fi
    if [ "$pass" == "true" ]; then read -s -p "> " i; echo ""; else read -p "> " i; fi
    if [ -z "$i" ] && [ -n "$d" ]; then eval $v="$d"; else eval $v=\"\$i\"; fi
}

tui_menu() {
    local t="$1"; shift; local opts=("$@"); local sel=0; local tot=${#opts[@]}
    tput civis; trap 'tput cnorm' EXIT
    while true; do
        tui_header; echo -e "${YELLOW}$t${NC}\n----------------------------------------"
        for ((i=0; i<tot; i++)); do
            if [ $i -eq $sel ]; then echo -e "${GREEN} -> ${opts[i]} ${NC}"; else echo -e "    ${opts[i]} "; fi
        done
        echo "----------------------------------------"
        read -rsn1 k 2>/dev/null
        case "$k" in
            "") tput cnorm; return $sel ;;
            "A") ((sel--)); if [ $sel -lt 0 ]; then sel=$((tot-1)); fi ;;
            "B") ((sel++)); if [ $sel -ge $tot ]; then sel=0; fi ;;
            $'\x1b') read -rsn2 r 2>/dev/null; if [[ "$r" == "[A" ]]; then ((sel--)); fi; if [[ "$r" == "[B" ]]; then ((sel++)); fi ;;
        esac
    done
}

#=============================================================================
# 3. 部署向导
#=============================================================================
install_steamcmd() {
    # 修复 SteamCMD Locale (Debian/Ubuntu Root)
    if [ "$EUID" -eq 0 ] && [ -f /etc/debian_version ] && ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
        echo -e "${YELLOW}Fixing SteamCMD Locale (en_US.UTF-8)...${NC}"
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq locales >/dev/null 2>&1
        sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen 2>/dev/null
        locale-gen en_US.UTF-8 >/dev/null 2>&1
    fi

    if [ ! -f "${STEAMCMD_DIR}/steamcmd.sh" ]; then
        echo -e "$M_INIT_STEAMCMD"; mkdir -p "${STEAMCMD_DIR}"
        echo -e "$M_DL_STEAMCMD"
        local tmp="/tmp/steamcmd.tar.gz"
        if wget -O "$tmp" "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"; then
            echo -e "$M_EXTRACTING"
            tar zxf "$tmp" -C "${STEAMCMD_DIR}"
            rm -f "$tmp"
        else
            echo -e "$M_DL_FAIL"; return 1
        fi
    fi
}

deploy_wizard() {
    tui_header; echo -e "${GREEN}$M_DEPLOY${NC}"
    local name=""; while [ -z "$name" ]; do
        tui_input "$M_SRV_NAME" "l4d2_srv_1" "name"
        if grep -q "^${name}|" "$DATA_FILE"; then echo -e "$M_NAME_EXIST"; name=""; fi
    done
    
    local def_path="$HOME/L4D2_Servers/${name}"
    
    local path=""; while [ -z "$path" ]; do
        tui_input "$M_INSTALL_DIR" "$def_path" "path"
        path="${path/#\~/$HOME}"
        if [ -d "$path" ] && [ "$(ls -A "$path")" ]; then echo -e "$M_DIR_NOT_EMPTY"; path=""; fi
    done
    
    tui_header; echo "$M_LOGIN_ANON"; echo "$M_LOGIN_ACC"
    local mode; tui_input "$M_SELECT_1_2" "1" "mode"
    
    # 1. Update Cache
    install_steamcmd
    mkdir -p "$SERVER_CACHE_DIR"
    echo -e "$M_UPDATE_CACHE"
    
    # Force UTF-8 for SteamCMD
    export LANG=en_US.UTF-8; export LC_ALL=en_US.UTF-8
    
    local cache_script="${SERVER_CACHE_DIR}/update_cache.txt"
    if [ "$mode" == "2" ]; then
        local u p; tui_input "$M_ACC" "" "u"; tui_input "$M_PASS" "" "p" "true"
        echo "force_install_dir \"$SERVER_CACHE_DIR\"" > "$cache_script"
        echo "login $u $p" >> "$cache_script"
        echo "@sSteamCmdForcePlatformType linux" >> "$cache_script"
        echo "app_update $DEFAULT_APPID validate" >> "$cache_script"
        echo "quit" >> "$cache_script"
        "${STEAMCMD_DIR}/steamcmd.sh" +runscript "$cache_script" | grep -v "CHTTPClientThreadPool"
    else
        echo "force_install_dir \"$SERVER_CACHE_DIR\"" > "$cache_script"
        echo "login anonymous" >> "$cache_script"
        echo "@sSteamCmdForcePlatformType linux" >> "$cache_script"
        echo "app_info_update 1" >> "$cache_script"
        echo "app_update $DEFAULT_APPID" >> "$cache_script"
        echo "@sSteamCmdForcePlatformType windows" >> "$cache_script"
        echo "app_info_update 1" >> "$cache_script"
        echo "app_update $DEFAULT_APPID" >> "$cache_script"
        echo "@sSteamCmdForcePlatformType linux" >> "$cache_script"
        echo "app_info_update 1" >> "$cache_script"
        echo "app_update $DEFAULT_APPID validate" >> "$cache_script"
        echo "quit" >> "$cache_script"
        "${STEAMCMD_DIR}/steamcmd.sh" +runscript "$cache_script" | grep -v "CHTTPClientThreadPool"
    fi
    
    # 2. Deploy from Cache
    if [ ! -f "${SERVER_CACHE_DIR}/srcds_run" ]; then
        echo -e "\n${RED}======================================${NC}"
        echo -e "${RED}        $M_FAILED $M_DEPLOY_FAIL             ${NC}"
        echo -e "${RED}======================================${NC}"
        echo -e "$M_NO_SRCDS"
        read -n 1 -s -r; return
    fi
    
    echo -e "$M_COPY_CACHE"
    mkdir -p "$path"
    # Try reflink for speed/space, fallback to standard copy
    if ! cp -rf --reflink=auto "$SERVER_CACHE_DIR/"* "$path/" 2>/dev/null; then
        cp -rf "$SERVER_CACHE_DIR/"* "$path/"
    fi
    rm -f "$path/update_cache.txt"
    
    # 3. Create local update.txt
    local script="${path}/update.txt"
    sed "s|force_install_dir .*|force_install_dir \"$path\"|" "$cache_script" > "$script"
    
    mkdir -p "${path}/left4dead2/cfg"
    if [ ! -f "${path}/left4dead2/cfg/server.cfg" ]; then
        echo -e "hostname \"$name\"\nrcon_password \"password\"\nsv_lan 0\nsv_cheats 0\nsv_region 4" > "${path}/left4dead2/cfg/server.cfg"
    fi
    
    echo -e "#!/bin/bash\nwhile true; do\n echo 'Starting...'\n ./srcds_run -game left4dead2 -port 27015 +map c2m1_highway +maxplayers 8 -tickrate 60\n echo 'Restarting in 5s...'\n sleep 5\ndone" > "${path}/run_guard.sh"
    chmod +x "${path}/run_guard.sh"
    
    # 格式: Name|Path|Status|Port|AutoStart
    echo "${name}|${path}|STOPPED|27015|false" >> "$DATA_FILE"
    echo -e "\n${GREEN}======================================${NC}"
    echo -e "${GREEN}        $M_SUCCESS            ${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo -e "$M_SRV_READY ${CYAN}${path}${NC}"
    read -n 1 -s -r
}

#=============================================================================
# 4. 服务器管理与自启
#=============================================================================
get_status() { if tmux has-session -t "l4d2_$1" 2>/dev/null; then echo "RUNNING"; else echo "STOPPED"; fi; }

manage_menu() {
    local srvs=(); local opts=()
    while IFS='|' read -r n p s port auto; do
        if [ -n "$n" ]; then
            local st=$(get_status "$n"); local c=""; if [ "$st" == "RUNNING" ]; then c="$M_ST_RUN"; else c="$M_ST_STOP"; fi
            local ac=""; if [ "$auto" == "true" ]; then ac="$M_ST_AUTO"; fi
            srvs+=("$n"); opts+=("$n $c $ac")
        fi
    done < "$DATA_FILE"
    
    if [ ${#srvs[@]} -eq 0 ]; then echo -e "$M_NO_INSTANCE"; read -n 1 -s -r; return; fi
    opts+=("$M_RETURN")
    tui_menu "$M_SELECT_INSTANCE" "${opts[@]}"; local c=$?
    if [ $c -lt ${#srvs[@]} ]; then control_panel "${srvs[$c]}"; fi
}

control_panel() {
    local n="$1"
    # 获取最新信息
    local line=$(grep "^${n}|" "$DATA_FILE")
    local p=$(echo "$line" | cut -d'|' -f2)
    local port=$(echo "$line" | cut -d'|' -f4)
    local auto=$(echo "$line" | cut -d'|' -f5)
    
    while true; do
        local st=$(get_status "$n")
        local a_txt="$M_OPT_AUTO_ON"; if [ "$auto" == "true" ]; then a_txt="$M_OPT_AUTO_OFF"; fi
        
        tui_menu "$M_MANAGE_TITLE $n [$st]" "$M_OPT_START" "$M_OPT_STOP" "$M_OPT_RESTART" "$M_OPT_UPDATE" "$M_OPT_CONSOLE" "$M_OPT_LOGS" "$M_OPT_TRAFFIC" "$M_OPT_ARGS" "$M_OPT_PLUGINS" "$a_txt" "$M_OPT_BACKUP" "$M_RETURN"
        case $? in
            0) start_srv "$n" "$p" "$port" ;;
            1) stop_srv "$n" ;;
            2) stop_srv "$n"; sleep 1; start_srv "$n" "$p" "$port" ;;
            3) update_srv "$n" "$p" ;;
            4) attach_con "$n" ;;
            5) view_log "$p" ;;
            6) view_traffic "$n" "$port" ;;
            7) edit_args "$p" ;;
            8) plugins_menu "$p" ;;
            9) toggle_auto "$n" "$line"; break ;; 
            10) backup_srv "$n" "$p" ;;
            11) return ;;
        esac
    done
    control_panel "$n" # reload
}

update_srv() {
    local n="$1"; local p="$2"
    if [ "$(get_status "$n")" == "RUNNING" ]; then
        echo -e "$M_STOP_BEFORE_UPDATE"
        read -p "$M_ASK_STOP_UPDATE" c
        if [[ "$c" != "y" && "$c" != "Y" ]]; then return; fi
        stop_srv "$n"
    fi
    
    # 1. 更新中央缓存 (纯英文路径，规避 SteamCMD 乱码)
    echo -e "$M_UPDATE_CACHE"
    mkdir -p "$SERVER_CACHE_DIR"
    local cache_script="${SERVER_CACHE_DIR}/update_cache.txt"
    
    if [ ! -f "$cache_script" ]; then
        echo -e "$M_ASK_REBUILD"
        read -p "> " c
        if [[ "$c" == "y" || "$c" == "Y" ]]; then
            echo "force_install_dir \"$SERVER_CACHE_DIR\"" > "$cache_script"
            echo "login anonymous" >> "$cache_script"
            echo "@sSteamCmdForcePlatformType linux" >> "$cache_script"
            echo "app_info_update 1" >> "$cache_script"
            echo "app_update $DEFAULT_APPID" >> "$cache_script"
            echo "@sSteamCmdForcePlatformType windows" >> "$cache_script"
            echo "app_info_update 1" >> "$cache_script"
            echo "app_update $DEFAULT_APPID" >> "$cache_script"
            echo "@sSteamCmdForcePlatformType linux" >> "$cache_script"
            echo "app_info_update 1" >> "$cache_script"
            echo "app_update $DEFAULT_APPID validate" >> "$cache_script"
            echo "quit" >> "$cache_script"
        else
            return
        fi
    fi
    
    echo -e "$M_CALL_STEAMCMD"
    export LANG=en_US.UTF-8; export LC_ALL=en_US.UTF-8
    "${STEAMCMD_DIR}/steamcmd.sh" +runscript "$cache_script" | grep -v "CHTTPClientThreadPool"
    
    # 2. 同步到实例 (支持中文路径)
    echo -e "$M_COPY_CACHE"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --info=progress2 --exclude="server.cfg" --exclude="banned_user.cfg" --exclude="banned_ip.cfg" "$SERVER_CACHE_DIR/" "$p/"
    else
        # cp -u 无法排除文件，但 server.cfg 通常不在纯净包里，风险较低
        cp -rfu "$SERVER_CACHE_DIR/"* "$p/"
    fi
    
    echo -e "\n${GREEN}======================================${NC}"
    echo -e "${GREEN}        $M_SUCCESS $M_UPDATED            ${NC}"
    echo -e "${GREEN}======================================${NC}"
    read -n 1 -s -r
}

start_srv() {
    local n="$1"; local p="$2"; local port="$3"
    if [ "$(get_status "$n")" == "RUNNING" ]; then return; fi
    
    # 端口检查 (简单解析启动脚本中的端口，或者使用记录的端口)
    # 这里我们尝试从 run_guard.sh 中 grep 出端口，如果 grep 不到则用默认
    local real_port=$(grep -oP "(?<=-port )\d+" "$p/run_guard.sh" | head -1)
    if [ -z "$real_port" ]; then real_port=$port; fi
    
    if check_port "$real_port"; then
        echo -e "$M_PORT_OCCUPIED"; read -n 1 -s -r; return
    fi
    
    cd "$p" || return
    tmux new-session -d -s "l4d2_$n" "./run_guard.sh"
    echo -e "$M_START_SENT"; sleep 1
}

stop_srv() {
    local n="$1"
    tmux send-keys -t "l4d2_$n" C-c; sleep 1
    if tmux has-session -t "l4d2_$n" 2>/dev/null; then tmux kill-session -t "l4d2_$n"; fi
    echo -e "$M_STOPPED"; sleep 1
}

attach_con() {
    local n="$1"
    if [ "$(get_status "$n")" == "STOPPED" ]; then echo -e "$M_NOT_RUNNING"; sleep 1; return; fi
    echo -e "$M_DETACH_HINT"; read -n 1 -s -r
    tmux attach-session -t "l4d2_$n"
}

view_log() {
    local f="$1/left4dead2/console.log"
    if [ -f "$f" ]; then tail -f "$f"; else echo -e "$M_NO_LOG"; read -n 1 -s -r; fi
}

edit_args() {
    local s="$1/run_guard.sh"; local c=$(grep "./srcds_run" "$s")
    tui_header; echo -e "$M_CURRENT $c\n$M_NEW_CMD"
    read -e -i "$c" new
    if [ -n "$new" ]; then
        local esc=$(printf '%s\n' "$new" | sed 's:[][\/.^$*]:\\&:g')
        sed -i "s|^\./srcds_run.*|$new|" "$s"; echo -e "$M_SAVED"
    fi
    sleep 1
}

toggle_auto() {
    local n="$1"; local l="$2"
    local cur=$(echo "$l" | cut -d'|' -f5)
    local new="true"; if [ "$cur" == "true" ]; then new="false"; fi
    
    # Update line (careful with delimiter)
    # Reconstruct line: Name|Path|Status|Port|New
    local pre=$(echo "$l" | cut -d'|' -f1-4)
    # Use temporary file to avoid sed issues with special chars
    grep -v "^$n|" "$DATA_FILE" > "${DATA_FILE}.tmp"
    echo "${pre}|${new}" >> "${DATA_FILE}.tmp"
    mv "${DATA_FILE}.tmp" "$DATA_FILE"
    
    setup_global_resume
    echo -e "$M_AUTO_SET $new"; sleep 1
}

setup_global_resume() {
    if [ "$EUID" -eq 0 ]; then
        local s="/etc/systemd/system/l4m-resume.service"
        if [ ! -f "$s" ]; then
            echo -e "[Unit]\nDescription=L4M Resume\nAfter=network.target\n[Service]\nType=oneshot\nExecStart=$FINAL_ROOT/l4m resume\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target" > "$s"
            systemctl daemon-reload; systemctl enable l4m-resume.service >/dev/null 2>&1
        fi
        local m="/etc/systemd/system/l4m-monitor.service"
        if [ ! -f "$m" ]; then
            echo -e "[Unit]\nDescription=L4M Traffic Monitor\nAfter=network.target\n[Service]\nExecStart=$FINAL_ROOT/l4m monitor\nRestart=always\n[Install]\nWantedBy=multi-user.target" > "$m"
            systemctl daemon-reload; systemctl enable --now l4m-monitor.service >/dev/null 2>&1
        fi
    else
        if ! crontab -l 2>/dev/null | grep -q "l4m resume"; then
            (crontab -l 2>/dev/null; echo "@reboot $FINAL_ROOT/l4m resume >> $FINAL_ROOT/resume.log 2>&1") | crontab -
        fi
    fi
}

resume_all() {
    echo "L4M Resume triggered..."
    while IFS='|' read -r n p s port auto; do
        if [ "$auto" == "true" ]; then
            echo "Starting $n..."
            cd "$p" || continue
            tmux new-session -d -s "l4d2_$n" "./run_guard.sh"
        fi
    done < "$DATA_FILE"
}

backup_srv() {
    local n="$1"; local p="$2"
    mkdir -p "$BACKUP_DIR"
    local f="bk_${n}_$(date +%Y%m%d_%H%M).tar.gz"
    echo -e "$M_BACKUP_START"
    
    cd "$p" || return
    
    # 生成插件清单
    local list="installed_plugins.txt"
    echo "Backup Time: $(date)" > "$list"
    echo "Server: $n" >> "$list"
    echo "--- Addons ---" >> "$list"
    if [ -d "left4dead2/addons" ]; then ls -1 "left4dead2/addons" >> "$list"; fi
    
    # 生成已安装插件列表
    local rec_dir=".plugin_records"
    if [ -d "$rec_dir" ]; then
        echo "--- $M_INSTALLED_PLUGINS ---" >> "$list"
        for rec_file in "$rec_dir"/*; do
            if [ -f "$rec_file" ]; then
                echo "$(basename "$rec_file")" >> "$list"
            fi
        done
    fi
    
    local targets=("run_guard.sh" "left4dead2/addons" "left4dead2/cfg" "left4dead2/host.txt" "left4dead2/motd.txt" "left4dead2/mapcycle.txt" "left4dead2/maplist.txt" "$rec_dir" "$list")
    local final=()
    for t in "${targets[@]}"; do if [ -e "$t" ]; then final+=("$t"); fi; done
    
    tar -czf "${BACKUP_DIR}/$f" --exclude="left4dead2/addons/sourcemod/logs" --exclude="*.log" "${final[@]}"
    rm -f "$list"
    
    if [ $? -eq 0 ]; then
        echo -e "$M_BACKUP_OK backups/$f ($(du -h "${BACKUP_DIR}/$f" | cut -f1))${NC}"
    else
        echo -e "$M_BACKUP_FAIL"
    fi
    read -n 1 -s -r
}

#=============================================================================
# 5. 插件
#=============================================================================
plugins_menu() {
    local p="$1"
    if [ ! -d "$p/left4dead2" ]; then echo -e "$M_DIR_ERR"; read -n 1 -s -r; return; fi
    while true; do
        tui_menu "$M_OPT_PLUGINS" "$M_PLUG_INSTALL" "$M_PLUG_UNINSTALL" "$M_PLUG_PLAT" "$M_PLUG_REPO" "$M_RETURN"
        case $? in
            0) inst_plug "$p" ;; 1) uninstall_plug "$p" ;; 2) inst_plat "$p" ;; 3) set_plugin_repo ;; 4) return ;;
        esac
    done
}

set_plugin_repo() {
    tui_header; echo -e "$M_CUR_REPO $JS_MODS_DIR"
    
    # 下载的插件整合包目录
    local pkg_dir="${FINAL_ROOT}/downloaded_packages"
    
    # 显示选择菜单
    echo -e "${YELLOW}1. 选择已下载的插件整合包${NC}"
    echo -e "${YELLOW}2. 手动输入插件库目录${NC}"
    echo -e "${YELLOW}3. 返回${NC}"
    read -p "> " choice
    
    case "$choice" in
        1)  # 选择已下载的插件整合包
            # 获取已下载的整合包列表
            local pkg_list=()
            for dir in "$pkg_dir"/*; do
                if [ -d "$dir" ]; then
                    local name=$(basename "$dir")
                    pkg_list+=("$name")
                fi
            done
            
            if [ ${#pkg_list[@]} -eq 0 ]; then
                echo -e "${YELLOW}没有已下载的插件整合包${NC}"; read -n 1 -s -r; return
            fi
            
            # 显示整合包列表
            local cur=0; local start=0; local size=15; local tot=${#pkg_list[@]}
            tput civis; trap 'tput cnorm' EXIT
            while true; do
                tui_header; echo -e "${GREEN}选择插件整合包${NC}\n$M_SELECT_HINT\n----------------------------------------"
                local end=$((start+size)); if [ $end -gt $tot ]; then end=$tot; fi
                for ((j=start;j<end;j++)); do
                    local m="[ ]"
                    if [ $j -eq $cur ]; then echo -e "${GREEN}-> $m ${pkg_list[j]}${NC}"; else echo -e "   $m ${pkg_list[j]}"; fi
                done
                read -rsn1 k 2>/dev/null
                case "$k" in
                    "") break ;;
                    "A") ((cur--)); if [ $cur -lt 0 ]; then cur=$((tot-1)); fi; if [ $cur -lt $start ]; then start=$cur; fi ;;
                    "B") ((cur++)); if [ $cur -ge $tot ]; then cur=0; start=0; fi; if [ $cur -ge $((start+size)) ]; then start=$((cur-size+1)); fi ;;
                    $'\x1b') read -rsn2 r; if [[ "$r" == "[A" ]]; then ((cur--)); fi; if [[ "$r" == "[B" ]]; then ((cur++)); fi ;;
                esac
            done
            tput cnorm
            
            # 设置选中的整合包为插件库
            if [ $cur -lt ${#pkg_list[@]} ]; then
                local selected_pkg="${pkg_list[$cur]}"
                local selected_dir="$pkg_dir/$selected_pkg/JS-MODS"
                if [ -d "$selected_dir" ]; then
                    JS_MODS_DIR="$selected_dir"; echo "$selected_dir" > "$PLUGIN_CONFIG"
                    echo -e "${GREEN}已选择插件库: $selected_dir${NC}"; read -n 1 -s -r
                else
                    echo -e "${RED}整合包结构不正确，缺少JS-MODS目录${NC}"; read -n 1 -s -r
                fi
            fi
            ;;
        2)  # 手动输入插件库目录
            echo -e "$M_NEW_REPO_PROMPT"
            read -e -i "$JS_MODS_DIR" new
            if [ -n "$new" ]; then
                JS_MODS_DIR="$new"; echo "$new" > "$PLUGIN_CONFIG"
                mkdir -p "$new"; echo -e "$M_SAVED"
            fi
            sleep 1
            ;;
        3)  # 返回
            return
            ;;
        *)
            echo -e "${RED}无效选择${NC}"; read -n 1 -s -r
            ;;
    esac
}

uninstall_plug() {
    local t="$1/left4dead2"
    local rec_dir="$1/.plugin_records"
    
    # 确保记录目录存在
    mkdir -p "$rec_dir"
    
    # 获取已安装的插件列表
    local ps=(); local d=()
    for rec_file in "$rec_dir"/*; do
        if [ -f "$rec_file" ]; then
            local n=$(basename "$rec_file")
            ps+=("$n"); d+=("$n")
        fi
    done
    
    if [ ${#ps[@]} -eq 0 ]; then 
        echo -e "${YELLOW}No plugins installed${NC}"; read -n 1 -s -r; return; 
    fi
    
    local sel=(); for ((j=0;j<${#ps[@]};j++)); do sel[j]=0; done
    local cur=0; local start=0; local size=15; local tot=${#ps[@]}
    
    tput civis; trap 'tput cnorm' EXIT
    while true; do
        tui_header; echo -e "$M_SELECT_HINT\n----------------------------------------"
        local end=$((start+size)); if [ $end -gt $tot ]; then end=$tot; fi
        for ((j=start;j<end;j++)); do
            local m="[ ]"; if [ "${sel[j]}" -eq 1 ]; then m="[x]"; fi
            if [ $j -eq $cur ]; then echo -e "${GREEN}-> $m ${d[j]}${NC}"; else echo -e "   $m ${d[j]}"; fi
        done
        read -rsn1 k 2>/dev/null
        case "$k" in
            "") break ;;
            " ") if [ "${sel[cur]}" -eq 0 ]; then sel[cur]=1; else sel[cur]=0; fi ;;
            "A") ((cur--)); if [ $cur -lt 0 ]; then cur=$((tot-1)); fi; if [ $cur -lt $start ]; then start=$cur; fi ;;
            "B") ((cur++)); if [ $cur -ge $tot ]; then cur=0; start=0; fi; if [ $cur -ge $((start+size)) ]; then start=$((cur-size+1)); fi ;;
            $'\x1b') read -rsn2 r; if [[ "$r" == "[A" ]]; then ((cur--)); fi; if [[ "$r" == "[B" ]]; then ((cur++)); fi ;;
        esac
    done
    tput cnorm
    
    local c=0
    for ((j=0;j<tot;j++)); do
        if [ "${sel[j]}" -eq 1 ]; then 
            local rec_file="$rec_dir/${ps[j]}"
            if [ -f "$rec_file" ]; then
                # 读取记录文件，删除对应的文件（只删除文件，不删除目录）
                while IFS= read -r file_path; do
                    if [ -n "$file_path" ] && [ -f "$t/$file_path" ]; then  # 只删除文件，不处理目录
                        rm -f "$t/$file_path" 2>/dev/null
                    fi
                done < "$rec_file"
                
                # 删除记录文件
                rm -f "$rec_file"
                ((c++))
            fi
        fi
    done
    echo -e "$M_DONE $c"; read -n 1 -s -r
}

inst_plug() {
    local t="$1/left4dead2"
    local rec_dir="$1/.plugin_records"
    
    if [ ! -d "$JS_MODS_DIR" ]; then echo -e "$M_REPO_NOT_FOUND $JS_MODS_DIR"; read -n 1 -s -r; return; fi
    
    # 确保记录目录存在
    mkdir -p "$rec_dir"
    
    local ps=(); local d=()
    while IFS= read -r -d '' dir; do
        local n=$(basename "$dir")
        if [ -f "$rec_dir/$n" ]; then
            ps+=("$n"); d+=("$n $M_INSTALLED")
        else
            ps+=("$n"); d+=("$n")
        fi
    done < <(find "$JS_MODS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    
    if [ ${#ps[@]} -eq 0 ]; then echo "$M_REPO_EMPTY"; read -n 1 -s -r; return; fi
    
    local sel=(); for ((j=0;j<${#ps[@]};j++)); do sel[j]=0; done
    local cur=0; local start=0; local size=15; local tot=${#ps[@]}
    
    tput civis; trap 'tput cnorm' EXIT
    while true; do
        tui_header; echo -e "$M_SELECT_HINT\n----------------------------------------"
        local end=$((start+size)); if [ $end -gt $tot ]; then end=$tot; fi
        for ((j=start;j<end;j++)); do
            local m="[ ]"; if [ "${sel[j]}" -eq 1 ]; then m="[x]"; fi
            if [ $j -eq $cur ]; then echo -e "${GREEN}-> $m ${d[j]}${NC}"; else echo -e "   $m ${d[j]}"; fi
        done
        read -rsn1 k 2>/dev/null
        case "$k" in
            "") break ;;
            " ") if [ "${sel[cur]}" -eq 0 ]; then sel[cur]=1; else sel[cur]=0; fi ;;
            "A") ((cur--)); if [ $cur -lt 0 ]; then cur=$((tot-1)); fi; if [ $cur -lt $start ]; then start=$cur; fi ;;
            "B") ((cur++)); if [ $cur -ge $tot ]; then cur=0; start=0; fi; if [ $cur -ge $((start+size)) ]; then start=$((cur-size+1)); fi ;;
            $'\x1b') read -rsn2 r; if [[ "$r" == "[A" ]]; then ((cur--)); fi; if [[ "$r" == "[B" ]]; then ((cur++)); fi ;;
        esac
    done
    tput cnorm
    
    local c=0
    for ((j=0;j<tot;j++)); do
        if [ "${sel[j]}" -eq 1 ]; then 
            local plugin_dir="${JS_MODS_DIR}/${ps[j]}"
            local rec_file="$rec_dir/${ps[j]}"
            
            # 清空记录文件
            > "$rec_file"
            
            # 复制文件并记录（只记录文件，不记录目录）
            while IFS= read -r -d '' file; do
                if [ -f "$file" ]; then  # 只处理文件，目录会在复制时自动创建
                    # 获取相对路径（相对于插件目录）
                    local rel_path=${file#"$plugin_dir/"}
                    local dest="$t/$rel_path"
                    
                    # 创建目标目录
                    mkdir -p "$(dirname "$dest")"
                    
                    # 复制文件
                    cp -f "$file" "$dest" 2>/dev/null
                    
                    # 记录文件路径
                    echo "$rel_path" >> "$rec_file"
                fi
            done < <(find "$plugin_dir" -type f -print0 | sort -z)
            
            ((c++))
        fi
    done
    echo -e "$M_DONE $c"; read -n 1 -s -r
}

inst_plat() {
    local d="$1/left4dead2"; mkdir -p "$d"; cd "$d" || return
    
    # 优先检测本地预置包 (位于脚本同级 pkg 目录)
    local pkg_dir="$FINAL_ROOT/pkg"
    if [ -f "$pkg_dir/mm.tar.gz" ] && [ -f "$pkg_dir/sm.tar.gz" ]; then
        echo -e "$M_LOCAL_PKG"
        tar -zxf "$pkg_dir/mm.tar.gz" && tar -zxf "$pkg_dir/sm.tar.gz"
    else
        echo -e "$M_CONN_OFFICIAL"
        local m=$(curl -s "https://www.sourcemm.net/downloads.php?branch=stable" | grep -Eo "https://[^']+linux.tar.gz" | head -1)
        local s=$(curl -s "http://www.sourcemod.net/downloads.php?branch=stable" | grep -Eo "https://[^']+linux.tar.gz" | head -1)
        
        if [ -z "$m" ] || [ -z "$s" ]; then
            echo -e "$M_GET_LINK_FAIL"; read -n 1 -s -r; return
        fi
        
        echo -e "MetaMod: ${GREY}$(basename "$m")${NC}"
        echo -e "SourceMod: ${GREY}$(basename "$s")${NC}"
        
        if ! wget -O mm.tar.gz "$m" || ! wget -O sm.tar.gz "$s"; then
             echo -e "$M_DL_FAIL"; rm -f mm.tar.gz sm.tar.gz; read -n 1 -s -r; return
        fi
        
        tar -zxf mm.tar.gz && tar -zxf sm.tar.gz
        rm mm.tar.gz sm.tar.gz
    fi

    if [ -f "$d/addons/metamod.vdf" ]; then sed -i '/"file"/c\\t"file"\t"..\/left4dead2\/addons\/metamod\/bin\/server"' "$d/addons/metamod.vdf"; fi
    echo -e "${GREEN}$M_SUCCESS $M_DONE${NC}"; read -n 1 -s -r
}

select_mirror() {
    if [ -n "$MIRROR_SELECTED" ]; then return; fi
    echo -e "${YELLOW}正在为您挑选最快的 GitHub 镜像节点...${NC}"
    local mirrors=(
        "https://gh-proxy.com"
        "https://ghproxy.net"
        "https://mirror.ghproxy.com"
        "https://github.moeyy.xyz"
    )
    local target_file="https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/LICENSE"
    local best=""
    local min_time=100000 # ms
    
    # 1. 测试直连
    local t=$(curl -L -o /dev/null -s --connect-timeout 2 -m 3 -w "%{http_code} %{time_total}" "$target_file")
    local code=$(echo "$t" | awk '{print $1}')
    local time=$(echo "$t" | awk '{print int($2 * 1000)}')
    
    if [ "$code" -eq 200 ]; then
        echo -e "  Direct: ${GREEN}${time}ms${NC}"
        min_time=$time
        best=""
    else
        echo -e "  Direct: ${RED}超时${NC}"
    fi
    
    # 2. 测试镜像
    for m in "${mirrors[@]}"; do
        local test_url="${m}/${target_file}"
        local t=$(curl -L -o /dev/null -s --connect-timeout 2 -m 3 -w "%{http_code} %{time_total}" "$test_url")
        local code=$(echo "$t" | awk '{print $1}')
        local time=$(echo "$t" | awk '{print int($2 * 1000)}')
        
        if [ "$code" -eq 200 ]; then
            echo -e "  $m: ${GREEN}${time}ms${NC}"
            if [ "$time" -lt "$min_time" ]; then
                min_time=$time
                best=$m
            fi
        else
            echo -e "  $m: ${RED}超时${NC}"
        fi
    done
    
    if [ -n "$best" ]; then
        echo -e "${GREEN}选中最佳镜像: $best${NC}"
        UPDATE_URL="${best}/https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh"
    else
        if [ "$min_time" -lt 100000 ]; then
             echo -e "${GREEN}直连速度最快${NC}"
        else
             echo -e "${RED}所有节点均不可用，回退到官方源${NC}"
        fi
        UPDATE_URL="https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh"
    fi
    MIRROR_SELECTED="true"
}

change_lang() {
    rm -f "$CONFIG_FILE"
    exec "$0"
}

download_packages() {
    tui_header; echo -e "${GREEN}$M_DOWNLOAD_PACKAGES${NC}"
    
    # 插件整合包下载目录
    local pkg_dir="${FINAL_ROOT}/downloaded_packages"
    mkdir -p "$pkg_dir"
    
    # 从GitHub仓库获取插件整合包列表
    local repo="soloxiaoye2022/server_install"
    local api_url="https://api.github.com/repos/${repo}/contents/豆瓣酱战役整合包"
    local proxy_api_url="https://gh-proxy.com/${api_url}"
    
    echo -e "${CYAN}正在获取插件整合包列表...${NC}"
    
    # 使用curl获取仓库内容，支持代理
    local response
    local packages
    local curl_success=false
    
    # 尝试直接连接GitHub API
    response=$(curl -s "$api_url" -o -)
    packages=$(echo "$response" | grep -oP '(?<="name": ")[^"]+\.(7z|zip|tar\.gz|tar\.bz2)' | grep -i "整合包")
    
    if [ -n "$packages" ]; then
        curl_success=true
    else
        # 直接连接失败，尝试使用代理
        echo -e "${YELLOW}直接连接失败，尝试使用代理...${NC}"
        response=$(curl -s "$proxy_api_url" -o -)
        packages=$(echo "$response" | grep -oP '(?<="name": ")[^"]+\.(7z|zip|tar\.gz|tar\.bz2)' | grep -i "整合包")
        
        if [ -n "$packages" ]; then
            curl_success=true
        fi
    fi
    
    # 检查是否获取到包列表
    if [ "$curl_success" = false ] || [ -z "$packages" ]; then
        echo -e "${RED}无法获取插件整合包列表${NC}"
        echo -e "${YELLOW}可能的原因：${NC}"
        echo -e "1. 网络连接问题"
        echo -e "2. GitHub API访问限制"
        echo -e "3. 仓库路径或文件名不正确"
        echo -e "${YELLOW}调试信息：${NC}"
        echo -e "API URL: $api_url"
        echo -e "Response snippet: $(echo "$response" | head -20)"
        read -n 1 -s -r; return
    fi
    
    # 将包名转换为数组
    local pkg_array=()
    while IFS= read -r pkg; do
        pkg_array+=("$pkg")
    done <<< "$packages"
    
    # 显示包列表供用户选择
    local sel=(); for ((j=0;j<${#pkg_array[@]};j++)); do sel[j]=0; done
    local cur=0; local start=0; local size=15; local tot=${#pkg_array[@]}
    
    tput civis; trap 'tput cnorm' EXIT
    while true; do
        tui_header; echo -e "${GREEN}$M_SELECT_PACKAGES${NC}\n$M_SELECT_HINT\n----------------------------------------"
        local end=$((start+size)); if [ $end -gt $tot ]; then end=$tot; fi
        for ((j=start;j<end;j++)); do
            local m="[ ]"; if [ "${sel[j]}" -eq 1 ]; then m="[x]"; fi
            if [ $j -eq $cur ]; then echo -e "${GREEN}-> $m ${pkg_array[j]}${NC}"; else echo -e "   $m ${pkg_array[j]}"; fi
        done
        read -rsn1 k 2>/dev/null
        case "$k" in
            "") break ;;
            " ") if [ "${sel[cur]}" -eq 0 ]; then sel[cur]=1; else sel[cur]=0; fi ;;
            "A") ((cur--)); if [ $cur -lt 0 ]; then cur=$((tot-1)); fi; if [ $cur -lt $start ]; then start=$cur; fi ;;
            "B") ((cur++)); if [ $cur -ge $tot ]; then cur=0; start=0; fi; if [ $cur -ge $((start+size)) ]; then start=$((cur-size+1)); fi ;;
            $'\x1b') read -rsn2 r; if [[ "$r" == "[A" ]]; then ((cur--)); fi; if [[ "$r" == "[B" ]]; then ((cur++)); fi ;;
        esac
    done
    tput cnorm
    
    # 下载选中的包
    local c=0
    for ((j=0;j<tot;j++)); do
        if [ "${sel[j]}" -eq 1 ]; then
            local pkg="${pkg_array[j]}"
            local raw_url="https://raw.githubusercontent.com/${repo}/main/豆瓣酱战役整合包/${pkg}"
            local proxy_url="https://gh-proxy.com/${raw_url}"
            local dest="${pkg_dir}/${pkg}"
            
            echo -e "\n${CYAN}正在下载: ${pkg}${NC}"
            if curl -L -# "$proxy_url" -o "$dest"; then
                echo -e "${GREEN}下载完成: ${pkg}${NC}"
                
                # 解压整合包
                echo -e "${CYAN}正在解压: ${pkg}${NC}"
                local unzip_success=false
                
                # 尝试使用7z解压
                if command -v 7z >/dev/null 2>&1; then
                    if 7z x -o"${pkg_dir}" "$dest" >/dev/null 2>&1; then
                        unzip_success=true
                    fi
                fi
                
                # 如果7z失败，尝试使用unzip
                if [ "$unzip_success" = false ] && command -v unzip >/dev/null 2>&1; then
                    if unzip "$dest" -d "${pkg_dir}" >/dev/null 2>&1; then
                        unzip_success=true
                    fi
                fi
                
                # 如果unzip也失败，尝试使用tar（针对.tar.gz或.tar.bz2格式）
                if [ "$unzip_success" = false ] && command -v tar >/dev/null 2>&1; then
                    if tar -xf "$dest" -C "${pkg_dir}" >/dev/null 2>&1; then
                        unzip_success=true
                    fi
                fi
                
                if [ "$unzip_success" = true ]; then
                    echo -e "${GREEN}解压完成: ${pkg}${NC}"
                    # 解压后删除压缩包
                    rm -f "$dest"
                    ((c++))
                else
                    echo -e "${RED}解压失败: ${pkg}${NC}"
                fi
            else
                echo -e "${RED}下载失败: ${pkg}${NC}"
            fi
        fi
    done
    
    echo -e "\n${GREEN}下载完成，共成功处理 ${c} 个包${NC}"; read -n 1 -s -r
}

#=============================================================================
# 6. Main
#=============================================================================
main() {
    chmod +x "$0"
    case "$1" in
        "install") install_smart; exit 0 ;;
        "update") self_update; exit 0 ;;
        "resume") resume_all; exit 0 ;;
        "monitor") traffic_daemon; exit 0 ;;
    esac
    
    # 语言初始化
    if [ ! -f "$CONFIG_FILE" ]; then
        clear; echo -e "${BLUE}=== L4D2 Manager (L4M) ===${NC}\n"
        echo "Please select language / 请选择语言:"
        echo "1. English"
        echo "2. 简体中文"
        read -p "> " l
        if [ "$l" == "2" ]; then echo "zh" > "$CONFIG_FILE"; else echo "en" > "$CONFIG_FILE"; fi
        
        # 尝试配置中文环境 (Root Only)
        if [ "$l" == "2" ] && [ "$EUID" -eq 0 ]; then
             if [ -f /etc/debian_version ]; then
                 echo -e "${YELLOW}Configuring Chinese Locale...${NC}"
                 apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq locales >/dev/null 2>&1
                 sed -i 's/# zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen 2>/dev/null
                 locale-gen zh_CN.UTF-8 >/dev/null 2>&1
                 export LANG=zh_CN.UTF-8
             fi
        fi
    fi
    load_i18n $(cat "$CONFIG_FILE")
    
    select_mirror
    
    if [[ "$INSTALL_TYPE" == "temp" ]]; then
        # 优先检测现有安装
        local exist_path=""
        if [ "$EUID" -eq 0 ] && [ -f "$SYSTEM_INSTALL_DIR/l4m" ]; then
            exist_path="$SYSTEM_INSTALL_DIR/l4m"
        elif [ -f "$USER_INSTALL_DIR/l4m" ]; then
            exist_path="$USER_INSTALL_DIR/l4m"
        fi
        
        if [ -n "$exist_path" ]; then
            echo -e "${GREEN}$M_FOUND_EXISTING${NC}"
            sleep 1
            exec "$exist_path" "$@"
        fi

        tui_header
        echo -e "${YELLOW}$M_WELCOME${NC}"
        echo -e "$M_TEMP_RUN"
        echo ""
        echo -e "$M_REC_INSTALL"
        echo -e "$M_F_PERSIST"
        echo -e "$M_F_ACCESS"
        echo -e "$M_F_ADV"
        echo ""
        read -p "$M_ASK_INSTALL" c
        c=${c:-y}
        if [[ "$c" == "y" || "$c" == "Y" ]]; then install_smart; exit 0; fi
        echo -e "$M_TEMP_MODE"; sleep 1
    fi
    
    check_deps
    if [ ! -f "$DATA_FILE" ]; then touch "$DATA_FILE"; fi
    
    while true; do
        tui_menu "$M_MAIN_MENU" "$M_DEPLOY" "$M_MANAGE" "$M_DOWNLOAD_PACKAGES" "$M_UPDATE" "$M_LANG" "$M_EXIT"
        case $? in
            0) deploy_wizard ;; 1) manage_menu ;; 2) download_packages ;; 3) self_update ;; 4) change_lang ;; 5) exit 0 ;;
        esac
    done
}

main "$@"
