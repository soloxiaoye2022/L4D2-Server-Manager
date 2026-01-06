#!/bin/bash

# 获取脚本当前路径
DEFAULT_SH=$(cd "$(dirname "$0")" && pwd)

# 配置路径
# 插件源文件夹 (解压后的插件存放处)
PLUGIN_SRC_DIR="${DEFAULT_SH}/JS-MODS"
# 已安装插件清单目录 (用于存储每个插件安装了哪些文件)
INSTALLED_MANIFEST_DIR="${DEFAULT_SH}/installed_manifests"
# 插件列表文件 (保留原有逻辑，仅作为显示用)
PLUGINS_LIST_FILE="${DEFAULT_SH}/plugins.txt"

# 服务端根目录 (根据用户提供的信息设置)
# 注意：如果您的服务端路径不同，请修改此处
SERVER_ROOT="e:/123pan/steamcmd/steamapps/common/Left 4 Dead 2 Dedicated Server"

# 整合包仓库目录 (用于查找 .7z 整合包)
WAREHOUSE_PATH="e:/文档/开发环境/server_install/豆瓣酱战役整合包"

# 镜像站前缀 (如果需要从网络下载)
MIRROR_URL="https://ghproxy.com/"

# 确保必要目录存在
mkdir -p "$PLUGIN_SRC_DIR"
mkdir -p "$INSTALLED_MANIFEST_DIR"
touch "$PLUGINS_LIST_FILE"

# 颜色定义
RED='\e[31m'
GREEN='\e[92m'
YELLOW='\e[33m'
BLUE='\e[34m'
CYAN='\e[36m'
NC='\e[0m' # No Color

trap 'onCtrlC' INT
function onCtrlC () {
    echo
    echo -e "${RED}Ctrl+C 被捕获，程序退出${NC}"
    exit 1
}

# 检查依赖
check_dependencies() {
    if ! command -v 7z &> /dev/null && ! command -v 7za &> /dev/null; then
        echo -e "${YELLOW}警告: 未检测到 7z 或 7za 命令，解压 .7z 整合包可能会失败。${NC}"
        echo -e "${YELLOW}请确保已安装 p7zip 或将 7z.exe 加入环境变量。${NC}"
    fi
}

# 进度条函数
progress_bar() {
    local duration=${1}
    local block="█"
    local empty="░"
    local width=20
    
    for ((i=0; i<=100; i+=5)); do
        local filled=$((i * width / 100))
        local empty_len=$((width - filled))
        local bar=""
        for ((j=0; j<filled; j++)); do bar="${bar}${block}"; done
        for ((j=0; j<empty_len; j++)); do bar="${bar}${empty}"; done
        printf "\r${CYAN}操作中: [${bar}] ${i}%%${NC}"
        sleep $(awk "BEGIN {print $duration / 20}")
    done
    echo
}

# 扫描仓库中的整合包
scan_warehouse() {
    echo -e "${CYAN}正在扫描仓库: ${WAREHOUSE_PATH}${NC}"
    
    # 获取所有 .7z 文件
    mapfile -t mod_packs < <(find "$WAREHOUSE_PATH" -maxdepth 1 -name "*.7z" -o -name "*.zip")
    
    if [ ${#mod_packs[@]} -eq 0 ]; then
        echo -e "${RED}仓库中未找到任何 .7z 或 .zip 整合包。${NC}"
        return 1
    fi

    echo -e "${YELLOW}发现以下整合包:${NC}"
    local i=1
    for pack in "${mod_packs[@]}"; do
        echo -e "${GREEN}$i${NC}. ${BLUE}$(basename "$pack")${NC}"
        ((i++))
    done
}

# 下载并解压整合包 (这里实现了从本地仓库解压，模拟下载流程)
import_mod_pack() {
    scan_warehouse
    if [ $? -ne 0 ]; then return; fi

    echo -e "${CYAN}请输入要导入的整合包数字 (支持多选，用分号 ; 隔开):${NC}"
    read user_input
    IFS=";" read -ra input_numbers <<< "$user_input"

    for number in "${input_numbers[@]}"; do
        if [[ $number =~ ^[0-9]+$ ]] && [ $number -ge 1 ] && [ $number -le ${#mod_packs[@]} ]; then
            local index=$((number - 1))
            local pack_path="${mod_packs[index]}"
            local pack_name=$(basename "$pack_path")
            
            echo -e "${CYAN}正在处理整合包: ${pack_name}${NC}"
            echo -e "${CYAN}模拟从镜像站下载...${NC}"
            progress_bar 1 # 模拟下载进度
            
            echo -e "${CYAN}正在解压到插件目录...${NC}"
            # 使用 7z 解压，-y 自动覆盖，-o 指定输出目录
            if command -v 7z &> /dev/null; then
                7z x "$pack_path" -o"$PLUGIN_SRC_DIR" -y > /dev/null
            elif command -v 7za &> /dev/null; then
                7za x "$pack_path" -o"$PLUGIN_SRC_DIR" -y > /dev/null
            else
                # 尝试 unzip
                unzip -o "$pack_path" -d "$PLUGIN_SRC_DIR" > /dev/null
            fi
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}整合包 ${pack_name} 导入成功！${NC}"
            else
                echo -e "${RED}解压失败，请检查文件或解压工具。${NC}"
            fi
        else
            echo -e "${RED}无效的选择: $number${NC}"
        fi
    done
}

# 列出可用插件 (从 JS-MODS 目录)
list_available_plugins() {
    # 刷新插件列表
    available_plugins=($(ls -d "$PLUGIN_SRC_DIR"/*/ 2>/dev/null))
    
    if [ ${#available_plugins[@]} -eq 0 ]; then
        echo -e "${RED}插件目录为空，请先导入整合包。${NC}"
        return 1
    fi

    # 读取已安装列表
    if [ -f "$PLUGINS_LIST_FILE" ]; then
        mapfile -t installed_plugins < "$PLUGINS_LIST_FILE"
    else
        installed_plugins=()
    fi

    local count=1
    valid_indices=()
    
    for plugin_path in "${available_plugins[@]}"; do
        plugin_name=$(basename "$plugin_path")
        
        # 检查是否已安装
        is_installed=false
        for installed in "${installed_plugins[@]}"; do
            if [ "$installed" == "$plugin_name" ]; then
                is_installed=true
                break
            fi
        done
        
        if [ "$is_installed" == "true" ]; then
            continue # 跳过已安装
        fi

        echo -e "${GREEN}$count${NC}. ${BLUE}$plugin_name${NC}"
        valid_indices+=("$plugin_path")
        ((count++))
    done
    
    if [ ${#valid_indices[@]} -eq 0 ]; then
        echo -e "${YELLOW}所有插件均已安装。${NC}"
        return 1
    fi
}

# 安装插件 (记录清单)
install_plugins() {
    list_available_plugins
    if [ $? -ne 0 ]; then return; fi

    echo -e "${CYAN}请输入要安装的插件数字 (用分号 ; 隔开):${NC}"
    read user_input
    IFS=";" read -ra input_numbers <<< "$user_input"

    for number in "${input_numbers[@]}"; do
        if [[ $number =~ ^[0-9]+$ ]] && [ $number -ge 1 ] && [ $number -le ${#valid_indices[@]} ]; then
            local index=$((number - 1))
            local plugin_path="${valid_indices[index]}"
            local plugin_name=$(basename "$plugin_path")
            local manifest_file="${INSTALLED_MANIFEST_DIR}/${plugin_name}.txt"
            
            echo -e "${CYAN}正在安装插件: ${plugin_name}${NC}"
            
            # 检查插件结构
            if [ ! -d "$plugin_path/left4dead2" ]; then
                echo -e "${YELLOW}警告: 插件 ${plugin_name} 缺少 left4dead2 目录，可能结构不正确。${NC}"
                # 依然尝试复制，但可能位置不对
            fi

            # 1. 生成文件清单并复制
            # 使用 find 查找所有文件
            > "$manifest_file" # 清空或创建清单文件
            
            # 切换到插件目录以获取相对路径
            pushd "$plugin_path" > /dev/null
            
            # 查找所有文件
            find . -type f | while read -r file; do
                # 去掉开头的 ./
                rel_path="${file#./}"
                target_file="${SERVER_ROOT}/${rel_path}"
                target_dir=$(dirname "$target_file")
                
                # 记录到清单 (记录绝对路径以便删除)
                echo "$target_file" >> "$manifest_file"
                
                # 创建目标目录
                mkdir -p "$target_dir"
                
                # 复制文件
                cp -f "$rel_path" "$target_file"
            done
            
            popd > /dev/null
            
            # 2. 更新已安装列表
            echo "$plugin_name" >> "$PLUGINS_LIST_FILE"
            
            echo -e "${GREEN}插件 ${plugin_name} 安装完成！${NC}"
            
        else
            echo -e "${RED}无效的选择: $number${NC}"
        fi
    done
}

# 卸载插件 (基于清单)
uninstall_plugins() {
    if [ ! -f "$PLUGINS_LIST_FILE" ] || [ ! -s "$PLUGINS_LIST_FILE" ]; then
        echo -e "${RED}没有已安装的插件。${NC}"
        return
    fi
    
    mapfile -t installed_plugins < "$PLUGINS_LIST_FILE"
    
    echo -e "${YELLOW}已安装插件列表:${NC}"
    local i=1
    for plugin in "${installed_plugins[@]}"; do
        echo -e "${GREEN}$i${NC}. ${BLUE}$plugin${NC}"
        ((i++))
    done
    
    echo -e "${CYAN}请输入要卸载的插件数字 (用分号 ; 隔开):${NC}"
    read user_input
    IFS=";" read -ra input_numbers <<< "$user_input"
    
    # 倒序处理以免索引错乱? 不，直接通过名字处理
    # 先收集要卸载的名字
    local to_uninstall=()
    for number in "${input_numbers[@]}"; do
        if [[ $number =~ ^[0-9]+$ ]] && [ $number -ge 1 ] && [ $number -le ${#installed_plugins[@]} ]; then
             to_uninstall+=("${installed_plugins[$((number-1))]}")
        else
             echo -e "${RED}无效的选择: $number${NC}"
        fi
    done
    
    for plugin_name in "${to_uninstall[@]}"; do
        echo -e "${CYAN}正在卸载插件: ${plugin_name}${NC}"
        local manifest_file="${INSTALLED_MANIFEST_DIR}/${plugin_name}.txt"
        
        if [ -f "$manifest_file" ]; then
            # 读取清单并删除文件
            while read -r file_path; do
                if [ -f "$file_path" ]; then
                    rm -f "$file_path"
                    # echo "删除: $file_path"
                fi
                # 尝试删除空目录 (可选)
                dir_path=$(dirname "$file_path")
                rmdir "$dir_path" 2>/dev/null # 仅当为空时删除
            done < "$manifest_file"
            
            rm -f "$manifest_file"
            echo -e "${GREEN}文件清理完成。${NC}"
        else
            echo -e "${YELLOW}未找到插件清单文件，尝试使用旧方法或跳过文件删除...${NC}"
            # 回退逻辑：如果用户以前安装的没有清单，这里可能无法彻底删除
            # 但为了安全，不建议盲目删除
        fi
        
        # 从 plugins.txt 移除
        grep -v "^${plugin_name}$" "$PLUGINS_LIST_FILE" > "${PLUGINS_LIST_FILE}.tmp" && mv "${PLUGINS_LIST_FILE}.tmp" "$PLUGINS_LIST_FILE"
        echo -e "${GREEN}插件 ${plugin_name} 已卸载。${NC}"
    done
}

# 设置自定义源目录
set_custom_source() {
    echo -e "${CYAN}请输入新的插件整合包/源目录路径:${NC}"
    read new_path
    if [ -d "$new_path" ]; then
        PLUGIN_SRC_DIR="$new_path"
        echo -e "${GREEN}插件源目录已更新为: $PLUGIN_SRC_DIR${NC}"
    else
        echo -e "${RED}目录不存在！${NC}"
    fi
}

# 主循环
check_dependencies

while true; do
    echo -e "\n${YELLOW}====== L4D2 插件管理器 ======${NC}"
    echo -e "${GREEN}1${NC}. ${BLUE}导入/下载 战役整合包${NC} (从仓库: $(basename "$WAREHOUSE_PATH"))"
    echo -e "${GREEN}2${NC}. ${BLUE}安装插件${NC} (从: $(basename "$PLUGIN_SRC_DIR"))"
    echo -e "${GREEN}3${NC}. ${BLUE}卸载插件${NC}"
    echo -e "${GREEN}4${NC}. ${BLUE}设置插件源目录${NC}"
    echo -e "${GREEN}5${NC}. ${BLUE}退出${NC}"
    echo -e "${YELLOW}=============================${NC}"
    
    read -p "您的选择是: " choice
    
    case $choice in
        1) import_mod_pack ;;
        2) install_plugins ;;
        3) uninstall_plugins ;;
        4) set_custom_source ;;
        5) exit 0 ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac
done
