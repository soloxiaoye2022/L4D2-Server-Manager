
#=============================================================================
# 5. 插件管理适配器 (Plugin Manager)
#=============================================================================
plugin_manager_adapter() {
    local srv_path="$1"
    local addons_path="${srv_path}/left4dead2/addons"
    
    # 简单的检查
    if [ ! -d "${srv_path}/left4dead2" ]; then
        echo -e "${RED}服务端目录结构异常，无法安装插件。${NC}"
        read -n 1 -s -r -p "按任意键返回..."
        return
    fi
    
    while true; do
        tui_menu "插件管理: $(basename "$srv_path")" \
            "安装插件 (从 JS-MODS)" \
            "安装 SourceMod/MetaMod 平台" \
            "返回上一级"
            
        local choice=$?
        case $choice in
            0) install_plugins_tui "$srv_path" ;;
            1) install_platform_tui "$srv_path" ;;
            2) return ;;
        esac
    done
}

install_plugins_tui() {
    local target_root="$1/left4dead2"
    
    # 扫描 JS-MODS
    if [ ! -d "$JS_MODS_DIR" ]; then
        # 尝试自动搜索
        local found=$(find "$MANAGER_ROOT" -maxdepth 4 -type d -name "JS-MODS" -print -quit)
        if [ -n "$found" ]; then
            JS_MODS_DIR="$found"
        else
            echo -e "${RED}未找到 JS-MODS 目录。请确保它在脚本附近。${NC}"
            read -n 1 -s -r -p "按任意键返回..."
            return
        fi
    fi
    
    local plugins=()
    local display_list=()
    
    # 读取插件列表
    while IFS= read -r -d '' dir; do
        local name=$(basename "$dir")
        plugins+=("$name")
        # 简单检查是否已安装 (检测 addons 下是否有同名目录，虽然不一定准确)
        if [ -d "${target_root}/addons/${name}" ]; then
             display_list+=("${name} ${GREEN}[已安装]${NC}")
        else
             display_list+=("${name}")
        fi
    done < <(find "$JS_MODS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    
    if [ ${#plugins[@]} -eq 0 ]; then
        echo -e "${YELLOW}JS-MODS 目录为空。${NC}"
        read -n 1 -s -r -p "按任意键返回..."
        return
    fi
    
    local selected_indices=()
    local cursor=0
    local page_start=0
    local page_size=15
    local total=${#plugins[@]}
    
    # 初始化选择状态
    for ((j=0; j<total; j++)); do selected_indices[j]=0; done
    
    tput civis
    trap 'tput cnorm' EXIT
    
    while true; do
        tui_header
        echo -e "${YELLOW}选择要安装的插件 [Space选择, Enter确认]${NC}"
        echo "----------------------------------------"
        
        local page_end=$((page_start + page_size))
        if [ $page_end -gt $total ]; then page_end=$total; fi
        
        for ((j=page_start; j<page_end; j++)); do
            local mark="[ ]"
            if [ "${selected_indices[j]}" -eq 1 ]; then mark="[x]"; fi
            
            if [ $j -eq $cursor ]; then
                echo -e "${GREEN}-> ${mark} ${display_list[j]} ${NC}"
            else
                echo -e "   ${mark} ${display_list[j]} "
            fi
        done
        echo "----------------------------------------"
        echo -e "${GREY}[↑/↓] 滚动  [Space] 切换  [Enter] 安装${NC}"
        
        read -rsn1 key 2>/dev/null
        case "$key" in
            "") # Enter
                break
                ;;
            " ") # Space
                if [ "${selected_indices[cursor]}" -eq 0 ]; then
                    selected_indices[cursor]=1
                else
                    selected_indices[cursor]=0
                fi
                ;;
            "A") # Up
                ((cursor--))
                if [ $cursor -lt 0 ]; then cursor=$((total-1)); fi
                if [ $cursor -lt $page_start ]; then page_start=$cursor; fi
                if [ $cursor -ge $((page_start + page_size)) ]; then page_start=$((cursor - page_size + 1)); fi
                ;;
            "B") # Down
                ((cursor++))
                if [ $cursor -ge $total ]; then cursor=0; page_start=0; fi
                if [ $cursor -ge $((page_start + page_size)) ]; then page_start=$((cursor - page_size + 1)); fi
                ;;
             $'\x1b') # Escape
                read -rsn2 rest 2>/dev/null || rest=""
                if [[ "$rest" == "[A" ]]; then
                     ((cursor--))
                     if [ $cursor -lt 0 ]; then cursor=$((total-1)); fi
                     if [ $cursor -lt $page_start ]; then page_start=$cursor; fi
                elif [[ "$rest" == "[B" ]]; then
                     ((cursor++))
                     if [ $cursor -ge $total ]; then cursor=0; page_start=0; fi
                     if [ $cursor -ge $((page_start + page_size)) ]; then page_start=$((cursor - page_size + 1)); fi
                fi
                ;;
        esac
    done
    tput cnorm
    
    # 执行安装
    echo ""
    local count=0
    for ((j=0; j<total; j++)); do
        if [ "${selected_indices[j]}" -eq 1 ]; then
            local p_name="${plugins[j]}"
            echo -e "${CYAN}正在安装: $p_name ...${NC}"
            # 复制逻辑：将 JS-MODS/插件名/* 复制到 left4dead2/
            cp -rf "${JS_MODS_DIR}/${p_name}/"* "${target_root}/" 2>/dev/null
            ((count++))
        fi
    done
    
    if [ $count -gt 0 ]; then
        echo -e "${GREEN}成功安装了 $count 个插件。${NC}"
    else
        echo -e "${YELLOW}未选择任何插件。${NC}"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

install_platform_tui() {
    local srv_path="$1"
    tui_header
    echo -e "${CYAN}正在初始化 SourceMod/MetaMod 平台安装...${NC}"
    
    local l4d2_dir="${srv_path}/left4dead2"
    mkdir -p "$l4d2_dir"
    cd "$l4d2_dir" || return
    
    echo -e "${YELLOW}正在下载 MetaMod (Stable)...${NC}"
    # 自动获取最新链接逻辑比较复杂，这里用固定的常用版本或最新稳定版链接
    # 为保证稳定性，最好还是去官网爬，但这里为了脚本简洁，使用硬编码的较新版本，或者依然使用旧脚本的爬虫逻辑
    # 考虑到稳定性，我们尝试复用 curl 爬虫逻辑
    
    local mms_url=$(curl -s "https://www.sourcemm.net/downloads.php?branch=stable" | grep -Eo "https://[^']+linux.tar.gz" | head -n 1)
    local sm_url=$(curl -s "http://www.sourcemod.net/downloads.php?branch=stable" | grep -Eo "https://[^']+linux.tar.gz" | head -n 1)
    
    if [ -z "$mms_url" ] || [ -z "$sm_url" ]; then
        echo -e "${RED}获取下载链接失败，请检查网络。${NC}"
        read -n 1 -s -r -p "按任意键返回..."
        return
    fi
    
    echo -e "下载 MetaMod: $mms_url"
    wget -qO mm.tar.gz "$mms_url" && tar -zxf mm.tar.gz && rm mm.tar.gz
    
    echo -e "下载 SourceMod: $sm_url"
    wget -qO sm.tar.gz "$sm_url" && tar -zxf sm.tar.gz && rm sm.tar.gz
    
    # 修复 vdf (SourceMod 需要这个修正吗？通常不需要，但 Metamod 可能需要)
    # 旧脚本里有 sed 操作，我们保留
    local vdf_file="${l4d2_dir}/addons/metamod.vdf"
    if [ -f "$vdf_file" ]; then
         sed -i '/"file"/c\\t"file"\t"..\/left4dead2\/addons\/metamod\/bin\/server"' "$vdf_file"
    fi
    
    echo -e "${GREEN}平台安装完成！${NC}"
    read -n 1 -s -r -p "按任意键继续..."
}

#=============================================================================
# 6. 主循环
#=============================================================================
main() {
    # 赋予执行权限
    chmod +x "$0"
    
    check_and_install_deps
    
    while true; do
        tui_menu "主菜单" \
            "部署新服务器" \
            "服务器管理" \
            "依赖管理 (重检)" \
            "退出系统"
            
        case $? in
            0) deploy_server_wizard ;;
            1) manage_servers_menu ;;
            2) check_and_install_deps ;;
            3) 
                echo -e "${GREEN}感谢使用！再见。${NC}"
                exit 0 
                ;;
        esac
    done
}

# 启动
main
