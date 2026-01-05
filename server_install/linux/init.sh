#!/bin/bash

# 0. 强制设置 Locale 为 UTF-8，解决中文乱码问题
if command -v locale >/dev/null 2>&1; then
    if locale -a | grep -q "C.UTF-8"; then
        export LANG=C.UTF-8; export LC_ALL=C.UTF-8
    elif locale -a | grep -q "zh_CN.UTF-8"; then
        export LANG=zh_CN.UTF-8; export LC_ALL=zh_CN.UTF-8
    else
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
UPDATE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh"

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
JS_MODS_DIR="${FINAL_ROOT}/js-mods"
STEAMCMD_DIR="${FINAL_ROOT}/steamcmd_common"
TRAFFIC_DIR="${FINAL_ROOT}/traffic_logs"
BACKUP_DIR="${FINAL_ROOT}/backups"
DEFAULT_APPID="222860"

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
    echo -e "${CYAN}正在初始化安装向导...${NC}"
    local target_dir=""
    local link_path=""
    
    if [ "$EUID" -eq 0 ]; then
        target_dir="$SYSTEM_INSTALL_DIR"; link_path="$SYSTEM_BIN"
    else
        target_dir="$USER_INSTALL_DIR"; link_path="$USER_BIN"
    fi
    
    if ! mkdir -p "$target_dir" 2>/dev/null; then
        if [ "$target_dir" == "$SYSTEM_INSTALL_DIR" ]; then
             echo -e "${RED}系统目录不可写，回退到用户目录...${NC}"
             target_dir="$USER_INSTALL_DIR"; link_path="$USER_BIN"
             mkdir -p "$target_dir" || { echo -e "${RED}安装失败。${NC}"; exit 1; }
        else
             echo -e "${RED}无权限创建 $target_dir${NC}"; exit 1;
        fi
    fi

    echo -e "${CYAN}安装路径: $target_dir${NC}"
    mkdir -p "$target_dir" "${target_dir}/steamcmd_common" "${target_dir}/js-mods" "${target_dir}/backups"
    
    if [ -f "$0" ] && [[ "$0" != *"bash"* ]] && [[ "$0" != *"/fd/"* ]]; then
        cp "$0" "$target_dir/l4m"
    else
        echo -e "${YELLOW}下载最新脚本...${NC}"
        curl -sL "$UPDATE_URL" -o "$target_dir/l4m" || { echo -e "${RED}下载失败${NC}"; exit 1; }
    fi
    chmod +x "$target_dir/l4m"
    
    mkdir -p "$(dirname "$link_path")"
    if ln -sf "$target_dir/l4m" "$link_path" 2>/dev/null; then
        echo -e "${GREEN}链接已创建: $link_path${NC}"
    else
        echo -e "${YELLOW}无法创建链接，请手动添加 alias l4m='$target_dir/l4m'${NC}"
    fi
    
    if [ "$MANAGER_ROOT" != "$target_dir" ] && [ -f "${MANAGER_ROOT}/servers.dat" ]; then
         cp "${MANAGER_ROOT}/servers.dat" "$target_dir/"
    fi
    touch "$target_dir/servers.dat"
    
    if [[ "$link_path" == "$USER_BIN" ]] && [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo -e "${YELLOW}请将 $HOME/bin 加入 PATH 环境变量。${NC}"
    fi

    echo -e "${GREEN}安装完成！输入 l4m 启动。${NC}"
    sleep 2
    exec "$target_dir/l4m"
}

self_update() {
    echo -e "${CYAN}检查更新...${NC}"
    local temp="/tmp/l4m_upd.sh"
    if curl -sL "$UPDATE_URL" -o "$temp"; then
        if grep -q "main()" "$temp"; then
            mv "$temp" "$FINAL_ROOT/l4m"; chmod +x "$FINAL_ROOT/l4m"
            echo -e "${GREEN}更新成功！${NC}"; sleep 1; exec "$FINAL_ROOT/l4m"
        else
            echo -e "${RED}校验失败${NC}"; rm "$temp"
        fi
    else
        echo -e "${RED}连接失败${NC}"
    fi
    read -n 1 -s -r
}

#=============================================================================
# 1. 基础功能
#=============================================================================
check_deps() {
    local miss=()
    local req=("tmux" "curl" "wget" "tar" "tree" "sed" "awk" "lsof")
    for c in "${req[@]}"; do command -v "$c" >/dev/null 2>&1 || miss+=("$c"); done
    if [ ${#miss[@]} -eq 0 ]; then return 0; fi
    
    echo -e "${YELLOW}检测到缺失依赖: ${miss[*]}${NC}"
    local cmd=""
    if [ -f /etc/debian_version ]; then
        cmd="apt-get update -qq && apt-get install -y -qq ${miss[*]} lib32gcc-s1 lib32stdc++6 ca-certificates"
    elif [ -f /etc/redhat-release ]; then
        cmd="yum install -y -q ${miss[*]} glibc.i686 libstdc++.i686"
    fi

    if [ "$EUID" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            echo -e "${CYAN}尝试使用 sudo 安装 (可能需输密码)...${NC}"
            if [ -f /etc/debian_version ]; then sudo dpkg --add-architecture i386 >/dev/null 2>&1; fi
            if sudo bash -c "$cmd"; then echo -e "${GREEN}安装成功${NC}"; return 0; fi
        fi
        if command -v pkg >/dev/null; then pkg install -y "${miss[@]}"; return; fi
        echo -e "${RED}无法自动安装。请手动执行: sudo $cmd${NC}"; read -n 1 -s -r; return
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
    if [ "$EUID" -ne 0 ]; then echo -e "${RED}需Root权限${NC}"; read -n 1 -s -r; return; fi
    
    while true; do
        tui_header; echo -e "${CYAN}流量统计: $n ($port)${NC}\n----------------------------------------"
        local r1=$(iptables -nvxL L4M_STATS | awk -v p="dpt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
        local t1=$(iptables -nvxL L4M_STATS | awk -v p="spt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
        sleep 1
        local r2=$(iptables -nvxL L4M_STATS | awk -v p="dpt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
        local t2=$(iptables -nvxL L4M_STATS | awk -v p="spt:$port" '$0 ~ p {sum+=$2} END {print sum+0}')
        
        echo -e "实时: ↓$(numfmt --to=iec --suffix=B/s $((r2-r1)))  ↑$(numfmt --to=iec --suffix=B/s $((t2-t1)))"
        echo "----------------------------------------"
        
        local f="${TRAFFIC_DIR}/${n}_$(date +%Y%m).csv"
        if [ -f "$f" ]; then
            local today=$(date +%s -d "today 00:00")
            local stats=$(awk -F, -v d="$today" '{tr+=$2; tt+=$3} $1 >= d {dr+=$2; dt+=$3} END {printf "%d %d %d %d", dr, dt, tr, tt}' "$f")
            read dr dt tr tt <<< "$stats"
            echo -e "今日: ↓$(numfmt --to=iec $dr) ↑$(numfmt --to=iec $dt)"
            echo -e "本月: ↓$(numfmt --to=iec $tr) ↑$(numfmt --to=iec $tt)"
        else
            echo "暂无历史数据"
        fi
        echo "----------------------------------------"
        echo -e "${YELLOW}按任意键返回...${NC}"; read -n 1 -s -r -t 5 k; if [ -n "$k" ]; then break; fi
    done
}

#=============================================================================
# 2. TUI 库
#=============================================================================
tui_header() { clear; echo -e "${BLUE}=== L4D2 Manager (L4M) ===${NC}\n"; }

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
    if [ ! -f "${STEAMCMD_DIR}/steamcmd.sh" ]; then
        echo -e "${YELLOW}初始化 SteamCMD...${NC}"; mkdir -p "${STEAMCMD_DIR}"
        curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C "${STEAMCMD_DIR}"
    fi
}

deploy_wizard() {
    tui_header; echo -e "${GREEN}部署新实例${NC}"
    local name=""; while [ -z "$name" ]; do
        tui_input "服务器名称" "l4d2_srv_1" "name"
        if grep -q "^${name}|" "$DATA_FILE"; then echo -e "${RED}名称已存在${NC}"; name=""; fi
    done
    
    local def_path="$HOME/L4D2_Servers/${name}"
    
    local path=""; while [ -z "$path" ]; do
        tui_input "安装目录" "$def_path" "path"
        path="${path/#\~/$HOME}"
        if [ -d "$path" ] && [ "$(ls -A "$path")" ]; then echo -e "${RED}目录不为空${NC}"; path=""; fi
    done
    
    tui_header; echo "1. 匿名登录"; echo "2. 账号登录"
    local mode; tui_input "选择 (1/2)" "1" "mode"
    
    mkdir -p "$path"; install_steamcmd
    echo -e "${CYAN}开始下载...${NC}"
    local script="${path}/update.txt"
    if [ "$mode" == "2" ]; then
        local u p; tui_input "账号" "" "u"; tui_input "密码" "" "p" "true"
        echo "force_install_dir \"$path\"" > "$script"
        echo "login $u $p" >> "$script"
        echo "@sSteamCmdForcePlatformType linux" >> "$script"
        echo "app_update $DEFAULT_APPID validate" >> "$script"
        echo "quit" >> "$script"
        "${STEAMCMD_DIR}/steamcmd.sh" +runscript "$script" | grep -v "CHTTPClientThreadPool"
    else
        echo "force_install_dir \"$path\"" > "$script"
        echo "login anonymous" >> "$script"
        echo "@sSteamCmdForcePlatformType linux" >> "$script"
        echo "app_info_update 1" >> "$script"
        echo "app_update $DEFAULT_APPID" >> "$script"
        echo "@sSteamCmdForcePlatformType windows" >> "$script"
        echo "app_info_update 1" >> "$script"
        echo "app_update $DEFAULT_APPID" >> "$script"
        echo "@sSteamCmdForcePlatformType linux" >> "$script"
        echo "app_info_update 1" >> "$script"
        echo "app_update $DEFAULT_APPID validate" >> "$script"
        echo "quit" >> "$script"
        "${STEAMCMD_DIR}/steamcmd.sh" +runscript "$script" | grep -v "CHTTPClientThreadPool"
    fi
    
    if [ ! -f "${path}/srcds_run" ]; then
        echo -e "\n${RED}======================================${NC}"
        echo -e "${RED}        [FAILED] 部署失败             ${NC}"
        echo -e "${RED}======================================${NC}"
        echo -e "未找到 srcds_run，请检查上方 SteamCMD 报错。"
        read -n 1 -s -r; return
    fi
    
    mkdir -p "${path}/left4dead2/cfg"
    if [ ! -f "${path}/left4dead2/cfg/server.cfg" ]; then
        echo -e "hostname \"$name\"\nrcon_password \"password\"\nsv_lan 0\nsv_cheats 0\nsv_region 4" > "${path}/left4dead2/cfg/server.cfg"
    fi
    
    echo -e "#!/bin/bash\nwhile true; do\n echo 'Starting...'\n ./srcds_run -game left4dead2 -port 27015 +map c2m1_highway +maxplayers 8 -tickrate 60\n echo 'Restarting in 5s...'\n sleep 5\ndone" > "${path}/run_guard.sh"
    chmod +x "${path}/run_guard.sh"
    
    # 格式: Name|Path|Status|Port|AutoStart
    echo "${name}|${path}|STOPPED|27015|false" >> "$DATA_FILE"
    echo -e "\n${GREEN}======================================${NC}"
    echo -e "${GREEN}        [SUCCESS] 部署成功            ${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo -e "服务器已就绪: ${CYAN}${path}${NC}"
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
            local st=$(get_status "$n"); local c=""; if [ "$st" == "RUNNING" ]; then c="${GREEN}[运行]${NC}"; else c="${RED}[停止]${NC}"; fi
            local ac=""; if [ "$auto" == "true" ]; then ac="${CYAN}[自启]${NC}"; fi
            srvs+=("$n"); opts+=("$n $c $ac")
        fi
    done < "$DATA_FILE"
    
    if [ ${#srvs[@]} -eq 0 ]; then echo -e "${YELLOW}无实例${NC}"; read -n 1 -s -r; return; fi
    opts+=("返回")
    tui_menu "选择实例:" "${opts[@]}"; local c=$?
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
        local a_txt="开启自启"; if [ "$auto" == "true" ]; then a_txt="关闭自启"; fi
        
        tui_menu "管理: $n [$st]" "启动" "停止" "重启" "更新服务端" "控制台" "日志" "流量统计" "配置启动参数" "插件管理" "$a_txt" "备份服务端" "返回"
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
        echo -e "${YELLOW}更新前需停止服务器${NC}"
        read -p "立即停止并更新? (y/n): " c
        if [[ "$c" != "y" && "$c" != "Y" ]]; then return; fi
        stop_srv "$n"
    fi
    
    local script="${p}/update.txt"
    if [ ! -f "$script" ]; then
        echo -e "${RED}未找到 update.txt${NC}"
        echo -e "${YELLOW}是否以匿名模式重建更新脚本? (y/n)${NC}"
        read -p "> " c
        if [[ "$c" == "y" || "$c" == "Y" ]]; then
            echo "force_install_dir \"$p\"" > "$script"
            echo "login anonymous" >> "$script"
            echo "@sSteamCmdForcePlatformType linux" >> "$script"
            echo "app_info_update 1" >> "$script"
            echo "app_update $DEFAULT_APPID" >> "$script"
            echo "@sSteamCmdForcePlatformType windows" >> "$script"
            echo "app_info_update 1" >> "$script"
            echo "app_update $DEFAULT_APPID" >> "$script"
            echo "@sSteamCmdForcePlatformType linux" >> "$script"
            echo "app_info_update 1" >> "$script"
            echo "app_update $DEFAULT_APPID validate" >> "$script"
            echo "quit" >> "$script"
        else
            return
        fi
    fi
    
    echo -e "${CYAN}正在调用 SteamCMD 更新...${NC}"
    "${STEAMCMD_DIR}/steamcmd.sh" +runscript "$script" | grep -v "CHTTPClientThreadPool"
    echo -e "\n${GREEN}======================================${NC}"
    echo -e "${GREEN}        [SUCCESS] 更新完成            ${NC}"
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
        echo -e "${RED}端口 $real_port 被占用!${NC}"; read -n 1 -s -r; return
    fi
    
    cd "$p" || return
    tmux new-session -d -s "l4d2_$n" "./run_guard.sh"
    echo -e "${GREEN}启动指令已发送${NC}"; sleep 1
}

stop_srv() {
    local n="$1"
    tmux send-keys -t "l4d2_$n" C-c; sleep 1
    if tmux has-session -t "l4d2_$n" 2>/dev/null; then tmux kill-session -t "l4d2_$n"; fi
    echo -e "${GREEN}已停止${NC}"; sleep 1
}

attach_con() {
    local n="$1"
    if [ "$(get_status "$n")" == "STOPPED" ]; then echo -e "${RED}未运行${NC}"; sleep 1; return; fi
    echo -e "${YELLOW}按 Ctrl+B, D 离线${NC}"; read -n 1 -s -r
    tmux attach-session -t "l4d2_$n"
}

view_log() {
    local f="$1/left4dead2/console.log"
    if [ -f "$f" ]; then tail -f "$f"; else echo -e "${RED}无日志(请确认已加-condebug)${NC}"; read -n 1 -s -r; fi
}

edit_args() {
    local s="$1/run_guard.sh"; local c=$(grep "./srcds_run" "$s")
    tui_header; echo -e "${CYAN}当前:${NC} $c\n${YELLOW}新指令:${NC}"
    read -e -i "$c" new
    if [ -n "$new" ]; then
        local esc=$(printf '%s\n' "$new" | sed 's:[][\/.^$*]:\\&:g')
        sed -i "s|^\./srcds_run.*|$new|" "$s"; echo -e "${GREEN}保存${NC}"
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
    echo -e "${GREEN}自启已设置为: $new${NC}"; sleep 1
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
    echo -e "${CYAN}正在执行精简备份 (含Metamod、插件清单及数据)...${NC}"
    
    cd "$p" || return
    
    # 生成插件清单
    local list="installed_plugins.txt"
    echo "Backup Time: $(date)" > "$list"
    echo "Server: $n" >> "$list"
    echo "--- Addons ---" >> "$list"
    if [ -d "left4dead2/addons" ]; then ls -1 "left4dead2/addons" >> "$list"; fi
    
    local targets=("run_guard.sh" "left4dead2/addons" "left4dead2/cfg" "left4dead2/host.txt" "left4dead2/motd.txt" "left4dead2/mapcycle.txt" "left4dead2/maplist.txt" "$list")
    local final=()
    for t in "${targets[@]}"; do if [ -e "$t" ]; then final+=("$t"); fi; done
    
    tar -czf "${BACKUP_DIR}/$f" --exclude="left4dead2/addons/sourcemod/logs" --exclude="*.log" "${final[@]}"
    rm -f "$list"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}备份成功: backups/$f ($(du -h "${BACKUP_DIR}/$f" | cut -f1))${NC}"
    else
        echo -e "${RED}备份失败${NC}"
    fi
    read -n 1 -s -r
}

#=============================================================================
# 5. 插件
#=============================================================================
plugins_menu() {
    local p="$1"
    if [ ! -d "$p/left4dead2" ]; then echo -e "${RED}目录错${NC}"; read -n 1 -s -r; return; fi
    while true; do
        tui_menu "插件管理" "安装插件" "安装平台(SM/MM)" "返回"
        case $? in
            0) inst_plug "$p" ;; 1) inst_plat "$p" ;; 2) return ;;
        esac
    done
}

inst_plug() {
    local t="$1/left4dead2"
    if [ ! -d "$JS_MODS_DIR" ]; then
        local f=$(find "$FINAL_ROOT" -maxdepth 4 -type d -name "JS-MODS" -print -quit)
        if [ -n "$f" ]; then JS_MODS_DIR="$f"; fi
    fi
    if [ ! -d "$JS_MODS_DIR" ]; then echo -e "${RED}缺 JS-MODS${NC}"; read -n 1 -s -r; return; fi
    
    local ps=(); local d=()
    while IFS= read -r -d '' dir; do
        local n=$(basename "$dir"); ps+=("$n")
        if [ -d "$t/addons/$n" ]; then d+=("$n ${GREEN}[已装]${NC}"); else d+=("$n"); fi
    done < <(find "$JS_MODS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    
    if [ ${#ps[@]} -eq 0 ]; then echo "空"; read -n 1 -s -r; return; fi
    
    local sel=(); for ((j=0;j<${#ps[@]};j++)); do sel[j]=0; done
    local cur=0; local start=0; local size=15; local tot=${#ps[@]}
    
    tput civis; trap 'tput cnorm' EXIT
    while true; do
        tui_header; echo -e "${YELLOW}Space选 Enter确${NC}\n----------------------------------------"
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
        if [ "${sel[j]}" -eq 1 ]; then cp -rf "${JS_MODS_DIR}/${ps[j]}/"* "$t/" 2>/dev/null; ((c++)); fi
    done
    echo -e "${GREEN}完成 $c${NC}"; read -n 1 -s -r
}

inst_plat() {
    local d="$1/left4dead2"; mkdir -p "$d"; cd "$d" || return
    echo -e "${CYAN}下载...${NC}"
    local m=$(curl -s "https://www.sourcemm.net/downloads.php?branch=stable" | grep -Eo "https://[^']+linux.tar.gz" | head -1)
    local s=$(curl -s "http://www.sourcemod.net/downloads.php?branch=stable" | grep -Eo "https://[^']+linux.tar.gz" | head -1)
    wget -qO mm.tar.gz "$m" && tar -zxf mm.tar.gz && rm mm.tar.gz
    wget -qO sm.tar.gz "$s" && tar -zxf sm.tar.gz && rm sm.tar.gz
    if [ -f "$d/addons/metamod.vdf" ]; then sed -i '/"file"/c\\t"file"\t"..\/left4dead2\/addons\/metamod\/bin\/server"' "$d/addons/metamod.vdf"; fi
    echo "OK"; read -n 1 -s -r
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
    
    if [[ "$INSTALL_TYPE" == "temp" ]]; then
        tui_header
        echo -e "${YELLOW}欢迎使用 L4D2 Server Manager (L4M)${NC}"
        echo -e "检测到您当前通过临时方式运行 (管道/临时目录)。"
        echo ""
        echo -e "为了获得最佳体验，建议将管理器安装到系统："
        echo -e "  • ${GREEN}数据持久化${NC}: 服务器配置和数据将安全保存，防误删。"
        echo -e "  • ${GREEN}便捷访问${NC}: 安装后只需输入 ${CYAN}l4m${NC} 即可随时管理。"
        echo -e "  • ${GREEN}高级功能${NC}: 支持开机自启、流量监控等特性。"
        echo ""
        read -p "是否立即安装到系统? (Y/n): " c
        c=${c:-y}
        if [[ "$c" == "y" || "$c" == "Y" ]]; then install_smart; exit 0; fi
        echo -e "${GREY}进入临时运行模式...${NC}"; sleep 1
    fi
    
    check_deps
    if [ ! -f "$DATA_FILE" ]; then touch "$DATA_FILE"; fi
    
    while true; do
        tui_menu "L4M 主菜单" "部署新实例" "实例管理" "系统更新" "退出"
        case $? in
            0) deploy_wizard ;; 1) manage_menu ;; 2) self_update ;; 3) exit 0 ;;
        esac
    done
}

main "$@"
