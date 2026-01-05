#!/bin/bash

#=============================================================================
# L4D2 Server Manager (L4M)
# 功能: 多实例管理、CLI/TUI双模式、自动安装更新、Tmux进程守护
#=============================================================================

# 全局配置
INSTALL_DIR="/usr/local/l4d2_manager"
BIN_LINK="/usr/bin/l4m"
UPDATE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/server_install/linux/init.sh"

# 动态判断运行路径
if [[ "$0" == "$INSTALL_DIR/l4m" ]] || [[ -L "$0" && "$(readlink -f "$0")" == "$INSTALL_DIR/l4m" ]]; then
    MANAGER_ROOT="$INSTALL_DIR"
else
    MANAGER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

DATA_FILE="${MANAGER_ROOT}/servers.dat"
JS_MODS_DIR="${MANAGER_ROOT}/js-mods"
STEAMCMD_DIR="${MANAGER_ROOT}/steamcmd_common"
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
# 0. 系统安装与更新模块
#=============================================================================
install_system_wide() {
    # 检查 Root 权限
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请使用 root 权限运行安装 (sudo bash $0)${NC}"
        exit 1
    fi

    echo -e "${CYAN}正在安装 L4D2 Manager 到系统...${NC}"

    # 创建目录
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$STEAMCMD_DIR"
    mkdir -p "$JS_MODS_DIR"

    # 复制脚本
    if [ -f "$0" ]; then
        cp "$0" "$INSTALL_DIR/l4m"
        chmod +x "$INSTALL_DIR/l4m"
    else
        # 如果是通过管道运行 (bash <(curl...))，则下载
        echo -e "${YELLOW}检测到管道运行，正在下载最新版...${NC}"
        if ! curl -sL "$UPDATE_URL" -o "$INSTALL_DIR/l4m"; then
            echo -e "${RED}下载失败。${NC}"
            exit 1
        fi
        chmod +x "$INSTALL_DIR/l4m"
    fi

    # 创建软链接
    ln -sf "$INSTALL_DIR/l4m" "$BIN_LINK"

    # 迁移旧数据 (如果存在)
    if [ -f "${MANAGER_ROOT}/servers.dat" ] && [ "${MANAGER_ROOT}" != "${INSTALL_DIR}" ]; then
        echo -e "${YELLOW}检测到旧数据，正在迁移...${NC}"
        cp "${MANAGER_ROOT}/servers.dat" "$INSTALL_DIR/"
    fi
    
    # 初始化数据文件
    touch "$INSTALL_DIR/servers.dat"

    echo -e "${GREEN}安装成功！${NC}"
    echo -e "现在你可以直接输入 ${CYAN}l4m${NC} 来启动管理器。"
    echo -e "或者使用 ${CYAN}l4m update${NC} 来更新脚本。"
    sleep 2
    
    # 切换到安装目录运行
    exec "$INSTALL_DIR/l4m"
}

self_update() {
    echo -e "${CYAN}正在检查更新...${NC}"
    local temp_file="/tmp/l4m_update.sh"
    
    if curl -sL "$UPDATE_URL" -o "$temp_file"; then
        # 简单检查文件完整性
        if grep -q "main()" "$temp_file"; then
            mv "$temp_file" "$INSTALL_DIR/l4m"
            chmod +x "$INSTALL_DIR/l4m"
            echo -e "${GREEN}更新成功！重启脚本中...${NC}"
            sleep 1
            exec "$INSTALL_DIR/l4m"
        else
            echo -e "${RED}更新文件校验失败。${NC}"
            rm -f "$temp_file"
        fi
    else
        echo -e "${RED}无法连接更新服务器。${NC}"
    fi
    read -n 1 -s -r -p "按任意键返回..."
}

#=============================================================================
# 1. 依赖管理
#=============================================================================
check_and_install_deps() {
    local missing_deps=()
    local required_cmds=("tmux" "curl" "wget" "tar" "tree" "sed" "awk")
    
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        return 0
    fi
    
    echo -e "${YELLOW}正在后台自动安装缺失依赖: ${missing_deps[*]} ...${NC}"
    
    if [ -f /etc/debian_version ]; then
        dpkg --add-architecture i386 >/dev/null 2>&1
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq tmux curl wget tar tree lib32gcc-s1 lib32stdc++6 ca-certificates >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        yum install -y -q tmux curl wget tar tree glibc.i686 libstdc++.i686 >/dev/null 2>&1
    else
        echo -e "${RED}请手动安装: ${missing_deps[*]} 及 32位运行库${NC}"
        read -n 1 -s -r -p "按任意键继续..."
    fi
}

#=============================================================================
# 2. TUI 基础库
#=============================================================================
tui_header() {
    clear
    echo -e "${BLUE}==============================================================${NC}"
    echo -e "${CYAN}             L4D2 Manager (L4M) - CLI/TUI v3.0            ${NC}"
    echo -e "${BLUE}==============================================================${NC}"
    echo ""
}

tui_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local is_password="$4"
    
    if [ -n "$default" ]; then
        echo -e "${YELLOW}${prompt} ${GREY}[默认: ${default}]${NC}"
    else
        echo -e "${YELLOW}${prompt}${NC}"
    fi
    
    if [ "$is_password" == "true" ]; then
        read -s -p "> " input_str
        echo ""
    else
        read -p "> " input_str
    fi
    
    if [ -z "$input_str" ] && [ -n "$default" ]; then
        eval $var_name="$default"
    else
        eval $var_name=\"\$input_str\"
    fi
}

tui_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local total=${#options[@]}
    
    tput civis
    trap 'tput cnorm' EXIT
    
    while true; do
        tui_header
        echo -e "${YELLOW}${title}${NC}"
        echo "----------------------------------------"
        
        for ((i=0; i<total; i++)); do
            if [ $i -eq $selected ]; then
                echo -e "${GREEN} -> ${options[i]} ${NC}"
            else
                echo -e "    ${options[i]} "
            fi
        done
        echo "----------------------------------------"
        echo -e "${GREY}[↑/↓] 选择  [Enter] 确认${NC}"
        
        read -rsn1 key 2>/dev/null
        case "$key" in
            "") tput cnorm; return $selected ;;
            "A") ((selected--)); if [ $selected -lt 0 ]; then selected=$((total-1)); fi ;;
            "B") ((selected++)); if [ $selected -ge $total ]; then selected=0; fi ;;
            $'\x1b')
                read -rsn2 rest 2>/dev/null || rest=""
                if [[ "$rest" == "[A" ]]; then ((selected--)); if [ $selected -lt 0 ]; then selected=$((total-1)); fi; fi
                if [[ "$rest" == "[B" ]]; then ((selected++)); if [ $selected -ge $total ]; then selected=0; fi; fi
                ;;
        esac
    done
}

#=============================================================================
# 3. 部署向导
#=============================================================================
install_steamcmd() {
    if [ ! -f "${STEAMCMD_DIR}/steamcmd.sh" ]; then
        echo -e "${YELLOW}正在初始化 SteamCMD...${NC}"
        mkdir -p "${STEAMCMD_DIR}"
        if ! curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C "${STEAMCMD_DIR}"; then
            echo -e "${RED}SteamCMD 下载失败！${NC}"
            return 1
        fi
    fi
    return 0
}

deploy_server_wizard() {
    tui_header
    echo -e "${GREEN}开始部署新的 L4D2 服务器实例${NC}"
    
    local srv_name=""
    while [ -z "$srv_name" ]; do
        tui_input "请输入服务器名称 (用于标识)" "l4d2_srv_1" "srv_name"
        if grep -q "^${srv_name}|" "$DATA_FILE"; then
            echo -e "${RED}名称已存在。${NC}"
            srv_name=""
        fi
    done
    
    local install_path=""
    while [ -z "$install_path" ]; do
        tui_input "请输入安装目录" "${MANAGER_ROOT}/${srv_name}" "install_path"
        if [ -d "$install_path" ] && [ "$(ls -A "$install_path")" ]; then
            echo -e "${RED}目录不为空。${NC}"
            install_path=""
        fi
    done
    
    tui_header
    echo -e "${YELLOW}登录方式${NC}"
    echo "1. 匿名 (Anonymous)"
    echo "2. 账号登录"
    local login_mode
    tui_input "选择 (1/2)" "1" "login_mode"
    
    mkdir -p "$install_path"
    install_steamcmd
    
    echo -e "${CYAN}启动 SteamCMD...${NC}"
    local steam_script="${install_path}/update_script.txt"
    
    if [ "$login_mode" == "2" ]; then
        local steam_user steam_pass
        tui_input "Steam 账号" "" "steam_user"
        tui_input "Steam 密码" "" "steam_pass" "true"
        echo "force_install_dir \"$install_path\"" > "$steam_script"
        echo "login $steam_user $steam_pass" >> "$steam_script"
        echo "app_update $DEFAULT_APPID validate" >> "$steam_script"
        echo "quit" >> "$steam_script"
        "${STEAMCMD_DIR}/steamcmd.sh" +runscript "$steam_script"
    else
        "${STEAMCMD_DIR}/steamcmd.sh" +force_install_dir "$install_path" +login anonymous +app_update $DEFAULT_APPID validate +quit
    fi
    
    if [ ! -f "${install_path}/srcds_run" ]; then
        echo -e "${RED}部署失败。${NC}"
        read -n 1 -s -r -p "按任意键返回..."
        return 1
    fi
    
    generate_configs "$srv_name" "$install_path"
    echo "${srv_name}|${install_path}|STOPPED|27015" >> "$DATA_FILE"
    echo -e "${GREEN}部署成功！${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

generate_configs() {
    local name="$1"
    local path="$2"
    local cfg_path="${path}/left4dead2/cfg/server.cfg"
    mkdir -p "$(dirname "$cfg_path")"
    if [ ! -f "$cfg_path" ]; then
        cat > "$cfg_path" <<EOF
hostname "${name}"
rcon_password "password"
sv_lan 0
sv_cheats 0
sv_region 4
EOF
    fi
    
    local run_script="${path}/run_guard.sh"
    cat > "$run_script" <<EOF
#!/bin/bash
while true; do
    echo "Starting Server..."
    ./srcds_run -game left4dead2 -port 27015 +map c2m1_highway +maxplayers 8 -tickrate 60
    echo "Server crashed. Restarting in 5s..."
    sleep 5
done
EOF
    chmod +x "$run_script"
}

#=============================================================================
# 4. 服务器管理
#=============================================================================
get_server_status() {
    local name="$1"
    if tmux has-session -t "l4d2_${name}" 2>/dev/null; then echo "RUNNING"; else echo "STOPPED"; fi
}

manage_servers_menu() {
    local servers=()
    local display_options=()
    while IFS='|' read -r name path status port; do
        if [ -n "$name" ]; then
            local st=$(get_server_status "$name")
            local col=""
            if [ "$st" == "RUNNING" ]; then col="${GREEN}[运行]${NC}"; else col="${RED}[停止]${NC}"; fi
            servers+=("$name")
            display_options+=("${name} ${col}")
        fi
    done < "$DATA_FILE"
    
    if [ ${#servers[@]} -eq 0 ]; then
        echo -e "${YELLOW}无服务器。${NC}"; read -n 1 -s -r -p "按任意键返回..."; return
    fi
    display_options+=("返回")
    
    tui_menu "选择服务器:" "${display_options[@]}"
    local choice=$?
    if [ $choice -lt ${#servers[@]} ]; then
        server_control_panel "${servers[$choice]}"
    fi
}

server_control_panel() {
    local srv_name="$1"
    local srv_path=$(grep "^${srv_name}|" "$DATA_FILE" | cut -d'|' -f2)
    while true; do
        local st=$(get_server_status "$srv_name")
        tui_menu "管理: ${srv_name} [$st]" "启动" "停止" "重启" "控制台" "日志" "参数" "插件" "返回"
        case $? in
            0) start_server "$srv_name" "$srv_path" ;;
            1) stop_server "$srv_name" ;;
            2) stop_server "$srv_name"; sleep 1; start_server "$srv_name" "$srv_path" ;;
            3) attach_console "$srv_name" ;;
            4) view_logs "$srv_path" ;;
            5) edit_startup_args "$srv_path" ;;
            6) plugin_manager_adapter "$srv_path" ;;
            7) return ;;
        esac
    done
}

start_server() {
    local name="$1"
    local path="$2"
    if [ "$(get_server_status "$name")" == "RUNNING" ]; then return; fi
    cd "$path" || return
    tmux new-session -d -s "l4d2_${name}" "./run_guard.sh"
    echo -e "${GREEN}已启动。${NC}"; sleep 1
}

stop_server() {
    local name="$1"
    tmux send-keys -t "l4d2_${name}" C-c
    sleep 1
    if tmux has-session -t "l4d2_${name}" 2>/dev/null; then tmux kill-session -t "l4d2_${name}"; fi
    echo -e "${GREEN}已停止。${NC}"; sleep 1
}

attach_console() {
    local name="$1"
    if [ "$(get_server_status "$name")" == "STOPPED" ]; then echo -e "${RED}未运行。${NC}"; sleep 1; return; fi
    echo -e "${YELLOW}按 Ctrl+B, D 退出控制台。${NC}"; read -n 1 -s -r
    tmux attach-session -t "l4d2_${name}"
}

view_logs() {
    local path="$1"
    local log="${path}/left4dead2/console.log"
    if [ -f "$log" ]; then tail -f "$log"; else echo -e "${RED}无日志(需 -condebug)${NC}"; read -n 1 -s -r; fi
}

edit_startup_args() {
    local path="$1"
    local script="${path}/run_guard.sh"
    local curr=$(grep "./srcds_run" "$script")
    tui_header
    echo -e "${CYAN}当前:${NC} $curr"
    echo -e "${YELLOW}新命令:${NC}"
    read -e -i "$curr" new_line
    if [ -n "$new_line" ]; then
        local escaped=$(printf '%s\n' "$new_line" | sed 's:[][\/.^$*]:\\&:g')
        sed -i "s|^\./srcds_run.*|$new_line|" "$script"
        echo -e "${GREEN}已保存。${NC}"
    fi
    sleep 1
}

#=============================================================================
# 5. 插件管理
#=============================================================================
plugin_manager_adapter() {
    local srv_path="$1"
    if [ ! -d "${srv_path}/left4dead2" ]; then echo -e "${RED}目录异常${NC}"; read -n 1 -s -r; return; fi
    while true; do
        tui_menu "插件管理" "安装插件" "安装平台(SM/MM)" "返回"
        case $? in
            0) install_plugins_tui "$srv_path" ;;
            1) install_platform_tui "$srv_path" ;;
            2) return ;;
        esac
    done
}

install_plugins_tui() {
    local target_root="$1/left4dead2"
    # 自动搜索 JS-MODS
    if [ ! -d "$JS_MODS_DIR" ]; then
        local found=$(find "$MANAGER_ROOT" -maxdepth 4 -type d -name "JS-MODS" -print -quit)
        if [ -n "$found" ]; then JS_MODS_DIR="$found"; fi
    fi
    
    if [ ! -d "$JS_MODS_DIR" ]; then echo -e "${RED}未找到 JS-MODS。${NC}"; read -n 1 -s -r; return; fi
    
    local plugins=()
    local display=()
    while IFS= read -r -d '' dir; do
        local name=$(basename "$dir")
        plugins+=("$name")
        if [ -d "${target_root}/addons/${name}" ]; then display+=("${name} ${GREEN}[已装]${NC}"); else display+=("${name}"); fi
    done < <(find "$JS_MODS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    
    if [ ${#plugins[@]} -eq 0 ]; then echo -e "${YELLOW}空目录。${NC}"; read -n 1 -s -r; return; fi
    
    local sel=()
    local cur=0
    local start=0
    local size=15
    local total=${#plugins[@]}
    for ((j=0;j<total;j++)); do sel[j]=0; done
    
    tput civis; trap 'tput cnorm' EXIT
    while true; do
        tui_header
        echo -e "${YELLOW}Space选择 Enter确认${NC}"
        echo "----------------------------------------"
        local end=$((start+size)); if [ $end -gt $total ]; then end=$total; fi
        for ((j=start;j<end;j++)); do
            local mark="[ ]"; if [ "${sel[j]}" -eq 1 ]; then mark="[x]"; fi
            if [ $j -eq $cur ]; then echo -e "${GREEN}-> ${mark} ${display[j]}${NC}"; else echo -e "   ${mark} ${display[j]}"; fi
        done
        echo "----------------------------------------"
        read -rsn1 key 2>/dev/null
        case "$key" in
            "") break ;;
            " ") if [ "${sel[cur]}" -eq 0 ]; then sel[cur]=1; else sel[cur]=0; fi ;;
            "A") ((cur--)); if [ $cur -lt 0 ]; then cur=$((total-1)); fi; if [ $cur -lt $start ]; then start=$cur; fi ;;
            "B") ((cur++)); if [ $cur -ge $total ]; then cur=0; start=0; fi; if [ $cur -ge $((start+size)) ]; then start=$((cur-size+1)); fi ;;
            $'\x1b') read -rsn2 rest 2>/dev/null; if [[ "$rest" == "[A" ]]; then ((cur--)); fi; if [[ "$rest" == "[B" ]]; then ((cur++)); fi ;;
        esac
    done
    tput cnorm
    
    local count=0
    for ((j=0;j<total;j++)); do
        if [ "${sel[j]}" -eq 1 ]; then
            cp -rf "${JS_MODS_DIR}/${plugins[j]}/"* "${target_root}/" 2>/dev/null
            ((count++))
        fi
    done
    echo -e "${GREEN}安装了 $count 个插件。${NC}"; read -n 1 -s -r
}

install_platform_tui() {
    local srv_path="$1"
    local l4d2_dir="${srv_path}/left4dead2"
    mkdir -p "$l4d2_dir"; cd "$l4d2_dir" || return
    echo -e "${CYAN}下载 SM/MM...${NC}"
    
    local mms=$(curl -s "https://www.sourcemm.net/downloads.php?branch=stable" | grep -Eo "https://[^']+linux.tar.gz" | head -n 1)
    local sm=$(curl -s "http://www.sourcemod.net/downloads.php?branch=stable" | grep -Eo "https://[^']+linux.tar.gz" | head -n 1)
    
    if [ -z "$mms" ] || [ -z "$sm" ]; then echo -e "${RED}链接获取失败。${NC}"; read -n 1 -s -r; return; fi
    wget -qO mm.tar.gz "$mms" && tar -zxf mm.tar.gz && rm mm.tar.gz
    wget -qO sm.tar.gz "$sm" && tar -zxf sm.tar.gz && rm sm.tar.gz
    
    local vdf="${l4d2_dir}/addons/metamod.vdf"
    if [ -f "$vdf" ]; then sed -i '/"file"/c\\t"file"\t"..\/left4dead2\/addons\/metamod\/bin\/server"' "$vdf"; fi
    echo -e "${GREEN}完成。${NC}"; read -n 1 -s -r
}

#=============================================================================
# 6. 主逻辑
#=============================================================================
main() {
    chmod +x "$0"
    
    # 参数处理
    case "$1" in
        "install") install_system_wide; exit 0 ;;
        "update") self_update; exit 0 ;;
    esac
    
    # 首次运行引导安装
    if [[ "$MANAGER_ROOT" != "$INSTALL_DIR" ]]; then
        tui_header
        echo -e "${YELLOW}检测到您未安装 L4D2 Manager 到系统。${NC}"
        echo -e "安装后，您可以通过输入 ${CYAN}l4m${NC} 随时打开管理器，且数据不会丢失。"
        echo ""
        read -p "是否现在安装? (y/n) [默认: y]: " choice
        choice=${choice:-y}
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            install_system_wide
            exit 0
        fi
    fi
    
    check_and_install_deps
    if [ ! -f "$DATA_FILE" ]; then touch "$DATA_FILE"; fi
    
    while true; do
        tui_menu "主菜单" "部署新服务器" "服务器管理" "依赖管理" "系统更新" "退出"
        case $? in
            0) deploy_server_wizard ;;
            1) manage_servers_menu ;;
            2) check_and_install_deps ;;
            3) self_update ;;
            4) exit 0 ;;
        esac
    done
}

main "$@"
