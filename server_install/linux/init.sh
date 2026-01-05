#!/bin/bash
set -euo pipefail

DEFAULT_DIR="test"
DEFAULT_IP="0.0.0.0"
DEFAULT_PORT="27015"
DEFAULT_MAP="c2m1_highway"
DEFAULT_MODE="coop"
DEFAULT_CFG="server.cfg"
DEFAULT_TICK="100"
START_PARAMETERS="-strictportbind -nobreakpad -noassert -ip ${DEFAULT_IP} -port ${DEFAULT_PORT} +map ${DEFAULT_MAP} +mp_gamemode ${DEFAULT_MODE} +servercfgfile ${DEFAULT_CFG} -tickrate ${DEFAULT_TICK}"

STEAMCMD_URL="https://cdn.steamchina.eccdnx.com/client/installer/steamcmd_linux.tar.gz"
STEAMCMD_URL_BACKUP1="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
STEAMCMD_URL_BACKUP2="https://media.steampowered.com/client/installer/steamcmd_linux.tar.gz"
STEAMCMD_BASE_URI="https://github.com/apples1949/SteamCmdLinuxFile/releases/download/steamcmd-latest/steamcmd_linux.tar.gz"
QUICK_UPDATE_BASE_PACKAGE="https://github.com/apples1949/SteamCmdLinuxFile/releases/download/steamcmd-latest/package.tar.gz"

# 保存原始URL，避免重复修改
STEAMCMD_BASE_URI_ORIGINAL="${STEAMCMD_BASE_URI}"
QUICK_UPDATE_BASE_PACKAGE_ORIGINAL="${QUICK_UPDATE_BASE_PACKAGE}"

NETWORK_TEST_DONE=false
PROXY_URL_BUILT=false

function format_speed() {
    local speed_bps=$1
    if (( speed_bps > 1048576 )); then
        local speed_mbs=$((speed_bps / 1048576))
        echo "${speed_mbs} MB/s"
    elif (( speed_bps > 1024 )); then
        local speed_kbs=$((speed_bps / 1024))
        echo "${speed_kbs} KB/s"
    else
        echo "${speed_bps} B/s"
    fi
}

function test_steam_download_speed() {
    local steam_urls=("$STEAMCMD_URL" "$STEAMCMD_URL_BACKUP1" "$STEAMCMD_URL_BACKUP2")
    local steam_names=("Steam中国CDN" "AkamaiCDN" "Steam官方媒体")
    local best_steam_url=""
    local best_steam_speed=0
    local timeout=5
    
    echo -e "\e[34m正在测试Steam下载源速度...\e[0m"
    
    for i in "${!steam_urls[@]}"; do
        local url="${steam_urls[$i]}"
        local name="${steam_names[$i]}"
        echo -e "\e[34m测试 ${name}: \e[36m${url}\e[0m"
        
        local curl_output
        curl_output=$(curl -k -L --connect-timeout ${timeout} --max-time ${timeout} -o /dev/null -s -w "%{http_code}:%{speed_download}" "${url}" 2>/dev/null) || curl_output="000:0"
        local status=$(echo "${curl_output}" | cut -d: -f1)
        local download_speed=$(echo "${curl_output}" | cut -d: -f2 | cut -d. -f1)
        
        if [ "${status}" = "200" ] && [ -n "${download_speed}" ] && [ "${download_speed}" -gt 0 ]; then
            local formatted_speed=$(format_speed "${download_speed}")
            echo -e "\e[34m${name} 速度: \e[92m${formatted_speed}\e[0m"
            
            if [ "${download_speed}" -gt "${best_steam_speed}" ]; then
                best_steam_speed=${download_speed}
                best_steam_url=${url}
            fi
        else
            echo -e "\e[33m${name} 连接失败或不可用\e[0m"
        fi
    done
    
    if [ -n "${best_steam_url}" ]; then
        echo -e "\e[34m选择最优Steam下载源: \e[92m${best_steam_url}\e[0m"
        STEAMCMD_URL="${best_steam_url}"
    else
        echo -e "\e[33m所有Steam下载源都不可用，将使用默认源\e[0m"
    fi
}

function network_test() {
    local timeout=5                    # 减少超时时间到5秒
    local best_proxy=""
    local best_speed=0
    
    # 优化代理列表 - 保留速度较好的代理
    local proxy_arr=("https://gh-proxy.com" "https://ghm.078465.xyz" "https://ghfast.top" "https://github.tbedu.top")
    local check_url="https://raw.githubusercontent.com/soloxiaoye2022/server_install/main/README.md"  # 使用更小的文件

    echo -e "\e[34m开始执行 Github 代理测速...\e[0m"

    # 测试直连
    echo -e "\e[34m正在测试直连...\e[0m"
    local curl_output
    curl_output=$(curl -k -L --connect-timeout ${timeout} --max-time $((timeout * 3)) -o /dev/null -s -w "%{http_code}:%{speed_download}" "${check_url}") || curl_output="000:0"
    local status=$(echo "${curl_output}" | cut -d: -f1)
    local download_speed=$(echo "${curl_output}" | cut -d: -f2 | cut -d. -f1)
    local curl_exit_code=0
    [ "${status}" != "000" ] && [ -n "${download_speed}" ] && curl_exit_code=0 || curl_exit_code=1

    if [ "${curl_exit_code}" -eq 0 ] && [ "${status}" -eq 200 ]; then
        local formatted_speed=$(format_speed "${download_speed}")
        echo -e "\e[34m直连速度: \e[92m${formatted_speed}\e[0m"
        best_speed=${download_speed}
    else
        echo -e "\e[33m直连失败或超时\e[0m"
    fi

    # 测试代理 - 直接测速
    echo -e "\e[34m正在测试代理可用性...\e[0m"
    
    for proxy in "${proxy_arr[@]}"; do
        proxy=${proxy%/}
        local test_url="${proxy}/${check_url}"
        
        echo -e "\e[34m测试代理: \e[36m${proxy}\e[0m"
        
        # 下载到临时文件进行验证
        local temp_test_file="/tmp/proxy_test_$$.tmp"
        curl_output=$(curl -k -L --connect-timeout ${timeout} --max-time ${timeout} -o "${temp_test_file}" -s -w "%{http_code}:%{speed_download}" "${test_url}" 2>/dev/null) || curl_output="000:0"
        status=$(echo "${curl_output}" | cut -d: -f1)
        download_speed=$(echo "${curl_output}" | cut -d: -f2 | cut -d. -f1)
        
        if [ "${status}" = "200" ] && [ -n "${download_speed}" ] && [ "${download_speed}" -gt 0 ]; then
            # 检查文件内容，确保不是HTML页面
            if [ -f "${temp_test_file}" ] && ! head -c 100 "${temp_test_file}" | grep -qi "html\|DOCTYPE\|<!DOCTYPE"; then
                local formatted_speed=$(format_speed "${download_speed}")
                echo -e "\e[34m  速度: \e[92m${formatted_speed}\e[0m"
                if (( download_speed > best_speed )); then
                    best_speed=${download_speed}
                    best_proxy=${proxy}
                fi
            else
                echo -e "\e[33m  代理返回HTML页面，不可用\e[0m"
            fi
        else
            echo -e "\e[33m  代理不可用 (状态: ${status})\e[0m"
        fi
        
        # 清理临时文件
        rm -f "${temp_test_file}"
    done

    if [ -n "${best_proxy}" ]; then
        echo -e "\e[34m选用最快代理: \e[92m${best_proxy}\e[0m"
        SELECTED_PROXY="${best_proxy}"
    else
        if (( best_speed > 0 )); then
            echo -e "\e[34m选用直连\e[0m"
            SELECTED_PROXY=""
        else
            echo -e "\e[33m代理测速较慢或失败，将使用默认代理并继续\e[0m"
            SELECTED_PROXY="https://gh-proxy.com"
        fi
    fi
    
    # 如果测速过程较慢，给出提示
    if [ -z "${best_proxy}" ] && [ -z "${SELECTED_PROXY}" ]; then
        echo -e "\e[33m网络连接较慢，后续下载可能需要更长时间\e[0m"
    fi
}

function ensure_network_test() {
    if [ "$NETWORK_TEST_DONE" = true ]; then
        return
    fi
    network_test
    
    # 只为GitHub相关URL添加代理，Steam CDN使用直连，且只构建一次
    if [ -n "${SELECTED_PROXY}" ] && [ "$PROXY_URL_BUILT" = false ]; then
        # 判断代理服务的类型，避免双重代理
        case "${SELECTED_PROXY}" in
            *"github.com"*|*"raw.githubusercontent.com"*)
                # 这是直连或特定GitHub代理，使用完整URL
                STEAMCMD_BASE_URI="${SELECTED_PROXY}/${STEAMCMD_BASE_URI_ORIGINAL}"
                QUICK_UPDATE_BASE_PACKAGE="${SELECTED_PROXY}/${QUICK_UPDATE_BASE_PACKAGE_ORIGINAL}"
                ;;
            *"gh-proxy.com"*|*"ghm.078465.xyz"*|*"ghfast.top"*|*"github.tbedu.top"*)
                # 这些是GitHub代理加速服务，需要GitHub路径部分
                # 提取GitHub路径（去掉https://github.com部分）
                local github_path_steam=$(echo "${STEAMCMD_BASE_URI_ORIGINAL}" | sed 's|https://github.com/||')
                local github_path_package=$(echo "${QUICK_UPDATE_BASE_PACKAGE_ORIGINAL}" | sed 's|https://github.com/||')
                STEAMCMD_BASE_URI="${SELECTED_PROXY}/${github_path_steam}"
                QUICK_UPDATE_BASE_PACKAGE="${SELECTED_PROXY}/${github_path_package}"
                ;;
            *)
                # 默认处理方式 - 使用完整URL
                STEAMCMD_BASE_URI="${SELECTED_PROXY}/${STEAMCMD_BASE_URI_ORIGINAL}"
                QUICK_UPDATE_BASE_PACKAGE="${SELECTED_PROXY}/${QUICK_UPDATE_BASE_PACKAGE_ORIGINAL}"
                ;;
        esac
        # Steam CDN使用直连，不通过代理，并测试选择最优源
        echo -e "\e[34mSteam CDN将使用直连，GitHub资源使用代理: \e[92m${SELECTED_PROXY}\e[0m"
        PROXY_URL_BUILT=true
    fi
    
    # 测试并选择最优Steam下载源
    test_steam_download_speed
    
    NETWORK_TEST_DONE=true
}


DEFAULT_SH=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)

case "${DEFAULT_SH:-}" in
    /proc/*|/dev/*|/tmp/*|"")
        DEFAULT_SH=$HOME
        echo "[INFO] 检测到管道/source执行，自动切换到 $DEFAULT_SH"
        ;;
esac

PLUGIN_VERSION=(-s -d -n)
folder_path=${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/JS-MODS
l4d2_menu=${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}
plugins_name=${DEFAULT_DIR}_plugins.txt
progress_name=${DEFAULT_DIR}_progress.txt
selected_folders=()

SKIP_SCRIPT=""
SKIP_PACKAGE=""
SKIP_DELETE=""
# 当你想默认通过你自己的Steam账户使用steamcmd下载服务端 请在SKIP_UPDATE内填入account STEAM_ACCOUNT和STEAM_PASSWORD分别填入账号密码
SKIP_UPDATE=""
STEAM_ACCOUNT=""
STEAM_PASSWORD=""

if [ ! -e "$plugins_name" ]; then
    touch "$plugins_name"
fi

if [ ! -e "$progress_name" ]; then
    touch "$progress_name"
fi

function wait_with_param() {
    local wait_param="$1"
    local timeout="$2"
    local skip_message="$3"
    local execute_message="$4"
    local action_func="$5"
    
    if [ -z "$wait_param" ] || ([ "$wait_param" != "true" ] && [ "$wait_param" != "false" ]); then
        echo -e "\e[33m3秒内按任意键跳过，否则将自动执行...\e[0m"
        # 使用更稳定的方式处理超时输入
        local user_input=""
        if read -t $timeout -n 1 -s user_input; then
            echo -e "\n\e[32m${skip_message}\e[0m"
            return 1
        else
            echo -e "\n\e[32m${execute_message}\e[0m"
            # 确保函数执行错误不会导致脚本退出
            if ! eval "$action_func"; then
                echo -e "\e[31m执行函数失败: ${action_func}\e[0m"
                return 1
            fi
            return 0
        fi
    elif [ "$wait_param" = "true" ]; then
        echo -e "\n\e[32m${execute_message}\e[0m"
        if ! eval "$action_func"; then
            echo -e "\e[31m执行函数失败: ${action_func}\e[0m"
            return 1
        fi
        return 0
    elif [ "$wait_param" = "false" ]; then
        echo -e "\n\e[32m${skip_message}\e[0m"
        return 1
    fi
}

function execute_dependency_script() {
    echo -e "\e[34m正在下载换源脚本...\e[0m"
    
    local temp_script
    temp_script=$(mktemp)
    
    if curl -m 30 -fSL https://linuxmirrors.cn/main.sh -o "$temp_script"; then
        if [ ! -s "$temp_script" ] || ! grep -q "bash" "$temp_script"; then
            echo -e "\e[31m换源脚本下载失败，文件内容无效\e[0m"
            rm -f "$temp_script"
            return 1
        fi
        
        echo -e "\e[34m换源脚本下载成功，开始执行...\e[0m"
        echo -e "\e[33m请在执行脚本后按上下键选择镜像源\e[0m"
        
        bash "$temp_script" --use-intranet-source false --upgrade-software false --install-epel false --backup false --ignore-backup-tips
        
        rm -f "$temp_script"
        return 0
    else
        local curl_exit_code=$?
        

        case $curl_exit_code in
            6)
                echo -e "\e[31m换源脚本下载失败：无法解析主机地址\e[0m"
                ;;
            7)
                echo -e "\e[31m换源脚本下载失败：无法连接到服务器\e[0m"
                ;;
            28)
                echo -e "\e[31m换源脚本下载失败：连接超时（30秒）\e[0m"
                ;;
            22)
                echo -e "\e[31m换源脚本下载失败：HTTP错误（404页面不存在等）\e[0m"
                ;;
            52)
                echo -e "\e[31m换源脚本下载失败：服务器无响应\e[0m"
                ;;
            *)
                echo -e "\e[31m换源脚本下载失败：错误代码 $curl_exit_code\e[0m"
                ;;
        esac
        
        echo -e "\e[33m将跳过依赖换源脚本执行，继续安装过程\e[0m"
        return 1
    fi
}


function centos() {
    echo -e "\e[92m安装依赖...\e[0m"
    case "${VERSION_ID}" in
        7|8)
            sudo yum update
            sudo yum install glibc.i686 libstdc++.i686 curl screen zip unzip
        ;;
        *)
            echo -e "\e[34m不支持的系统版本\e[0m \e[31m${VERSION_ID}\e[0m"
            exit 1
        ;;
    esac

    if [ "${?}" -ne 0 ]; then
        echo -e "\e[31m依赖安装失败\e[0m"
        exit 1
    else
        echo -e "\e[92m依赖安装成功，开始安装服务器\e[0m"
    fi
}

function ubuntu() {
    echo -e "\e[92m安装依赖...\e[0m"
    sudo dpkg --add-architecture i386 && \
    sudo apt update && \
    case "${VERSION_ID}" in
        16.04|18.04|20.04)
            sudo apt -y install lib32gcc1 lib32stdc++6 lib32z1-dev curl screen zip unzip
        ;;
        22.04|24.04)
            sudo apt -y install lib32gcc-s1 lib32stdc++6 lib32z1-dev curl screen zip unzip
        ;;
        *)
            echo -e "\e[34m不支持的系统版本\e[0m \e[31m${VERSION_ID}\e[0m"
            exit 1
        ;;
    esac

    if [ "${?}" -ne 0 ]; then
        echo -e "\e[31m依赖安装失败\e[0m"
        exit 1
    else
        echo -e "\e[92m依赖安装成功\e[0m"
    fi
}

function debian() {
    echo -e "\e[92m安装依赖...\e[0m"
    sudo dpkg --add-architecture i386 && \
    sudo apt update && \
    case "${VERSION_ID}" in
        9|10)
            sudo apt -y install lib32gcc1 lib32stdc++6 lib32z1-dev curl screen zip unzip
        ;;
        11|12)
            sudo apt -y install lib32gcc-s1 lib32stdc++6 lib32z1-dev curl screen zip unzip
        ;;
        *)
            echo -e "\e[34m不支持的系统版本\e[0m \e[31m${VERSION_ID}\e[0m"
            exit 1
        ;;
    esac

    if [ "${?}" -ne 0 ]; then
        echo -e "\e[31m依赖安装失败\e[0m"
        exit 1
    else
        echo -e "\e[92m依赖安装成功\e[0m"
    fi
}

function install_dependencies() {
    echo -e "\e[34m开始安装依赖，当前用户ID: $(id -u)\e[0m"
    
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "\e[33m当前用户无root权限，自动跳过执行换源脚本\e[0m"
    else
        echo -e "\e[0m即将下载执行\e[31m换源脚本\e[0m"
        echo -e "\e[0m大厂云（如腾讯云，阿里云）可跳过\e[0m"
        echo -e "\e[33m请在执行脚本后按上下键选择镜像源\e[0m"
        
        wait_with_param "$SKIP_SCRIPT" 3 \
            "已跳过依赖换源脚本执行" \
            "正在执行依赖换源脚本..." \
            "execute_dependency_script" || true
    fi

    echo -e "\e[34m检测系统信息...\e[0m"
    source "/etc/os-release"
    echo -e "\e[34m系统ID: ${ID}, 版本: ${VERSION_ID:-未知}\e[0m"
    
    case "${ID}" in
        ubuntu)
            echo -e "\e[34m执行Ubuntu依赖安装\e[0m"
            ubuntu
            ;;
        debian)
            echo -e "\e[34m执行Debian依赖安装\e[0m"
            debian
            ;;
        centos)
            echo -e "\e[34m执行CentOS依赖安装\e[0m"
            centos
            ;;
        *)
            echo -e "\e[31m不支持的操作系统: ${ID}\e[0m"
            echo -e "\e[33m支持的系统: Ubuntu, Debian, CentOS\e[0m"
            exit 1
            ;;
    esac
    
    echo -e "\e[34m依赖安装函数执行完成\e[0m"
}



function environment() {
    install_dependencies
    install_server
}

function execute_quick_package_download() {
    local package_dir="${DEFAULT_SH}/steamcmd/package"
    
    # 确保目录存在
    if [ ! -d "${package_dir}" ]; then
        echo -e "\e[34m创建package目录...\e[0m"
        mkdir -p "${package_dir}"
    fi
    
    echo -e "\e[34m正在清除package目录...\e[0m"
    rm -rf "${package_dir}"/*
    
    echo -e "\e[34m正在下载快速更新包...\e[0m"
    echo -e "\e[34m下载地址: \e[36m${QUICK_UPDATE_BASE_PACKAGE}\e[0m"
    
    # 下载到临时文件进行验证
    local temp_file="${package_dir}/package.tar.gz.tmp"
    if curl -m 300 -fSLo "${temp_file}" "${QUICK_UPDATE_BASE_PACKAGE}"; then
        echo -e "\e[34m快速更新包下载成功，正在验证文件...\e[0m"
        
        # 检查文件类型和内容
        file_type=$(file "${temp_file}" 2>/dev/null | cut -d: -f2)
        echo -e "\e[34m文件类型: \e[36m${file_type}\e[0m"
        
        # 检查是否为HTML文件（代理返回的错误页面）
        if head -c 100 "${temp_file}" | grep -qi "html\|DOCTYPE"; then
            echo -e "\e[33m警告：代理返回了HTML页面，可能URL格式不正确\e[0m"
            echo -e "\e[33m文件大小: $(ls -lh "${temp_file}" | awk '{print $5}')\e[0m"
            echo -e "\e[33m前100字符: $(head -c 100 "${temp_file}" 2>/dev/null)\e[0m"
            rm -f "${temp_file}"
            return 1
        fi
        
        # 验证文件是否为有效的gzip格式
        if tar -tzf "${temp_file}" >/dev/null 2>&1; then
            mv "${temp_file}" "${package_dir}/package.tar.gz"
            if tar -zxf "${package_dir}/package.tar.gz" -C "${package_dir}"; then
                echo -e "\e[92m快速更新包解压成功\e[0m"
                rm -f "${package_dir}/package.tar.gz"
                return 0
            else
                echo -e "\e[31m快速更新包解压失败\e[0m"
                rm -f "${package_dir}/package.tar.gz"
                return 1
            fi
        else
            echo -e "\e[31m下载的文件不是有效的gzip格式\e[0m"
            echo -e "\e[33m文件大小: $(ls -lh "${temp_file}" | awk '{print $5}')\e[0m"
            echo -e "\e[33m前100字符: $(head -c 100 "${temp_file}" 2>/dev/null)\e[0m"
            rm -f "${temp_file}"
            return 1
        fi
    else
        echo -e "\e[33m快速更新包下载失败，将使用常规安装方式\e[0m"
        return 1
    fi
}

function download_and_extract_quick_package() {
    echo -e "\e[0m即将下载安装\e[31mSteamcmd快速更新包\e[0m"
    echo -e "\e[0m如果最近几小时有完整执行下载服务端或更新服务端行为可跳过\e[0m"
    echo -e "\e[0m如果跳过后更新速度慢可不跳过\e[0m"
    
    wait_with_param "$SKIP_PACKAGE" 3 \
        "已跳过下载安装Steamcmd快速更新包" \
        "正在下载安装Steamcmd快速更新包..." \
        "execute_quick_package_download" || true
}

function install_server() {
    ensure_network_test
    trap 'rm -rf "${TMPDIR}"' EXIT
    TMPDIR=$(mktemp -d)
    if [ "${?}" -ne 0 ]; then
        echo -e "\e[31m临时目录\e[0m \e[31m创建失败\e[0m"
        exit 1
    fi

    if [ -f "${DEFAULT_SH}/steamcmd/steamcmd.sh" ] && \
       [ -f "${DEFAULT_SH}/steamcmd/linux32/crashhandler.so" ] && \
       [ -f "${DEFAULT_SH}/steamcmd/linux32/libstdc++.so.6" ] && \
       [ -f "${DEFAULT_SH}/steamcmd/linux32/steamcmd" ] && \
       [ -f "${DEFAULT_SH}/steamcmd/linux32/steamerrorreporter" ]; then
        echo -e "\e[34msteamcmd\e[0m 已经安装，跳过下载步骤"
        rm -rf "${TMPDIR}"

        download_and_extract_quick_package

        echo -e "\e[0m即将删除\e[31m服务端目录\e[0m"
        echo -e "\e[0m请检查\e[31m服务端目录\e[0m\e[0m是否还有未备份的文件\e[0m"
        echo -e "\e[0m第一次下载服务端可无视此提示\e[0m"
        
        execute_delete_server_dir() {
            rm -rf "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}"
            steam_login
        }
        
        wait_with_param "$SKIP_DELETE" 3 \
            "已退出脚本" \
            "正在删除安装服务端..." \
            "execute_delete_server_dir"
        return 0
    fi
    
    [ ! -d "${DEFAULT_SH}/steamcmd" ] && mkdir "${DEFAULT_SH}/steamcmd"
    
    if [ -f "${DEFAULT_SH}/steamcmd.tar.gz" ]; then
        echo -e "\e[34msteamcmd.tar.gz\e[0m 已经存在，正在解压"
        if ! tar -zxf "${DEFAULT_SH}/steamcmd.tar.gz" -C "${DEFAULT_SH}/steamcmd"; then
            rm -f "${DEFAULT_SH}/steamcmd.tar.gz"
            echo -e "\e[34msteamcmd.tar.gz\e[0m \e[31m解压失败，已删除\e[0m"
        else
            echo -e "\e[34msteamcmd\e[0m \e[92m解压成功\e[0m"
        fi
    fi

    echo -e "\e[34msteamcmd\e[0m 正在使用Steam CDN直连: \e[92m${STEAMCMD_URL}\e[0m"
    if ! curl -m 180 -fSLo "${TMPDIR}/steamcmd.tar.gz" "${STEAMCMD_URL}"; then
        echo -e "\e[34msteamcmd\e[0m \e[31m主CDN下载失败，尝试备用源\e[0m"
        echo -e "\e[34msteamcmd\e[0m 尝试备用源1: \e[92m${STEAMCMD_URL_BACKUP1}\e[0m"
        if ! curl --connect-timeout 10 -m 60 -fSLo "${TMPDIR}/steamcmd.tar.gz" "${STEAMCMD_URL_BACKUP1}"; then
            echo -e "\e[34msteamcmd\e[0m \e[31m备用源1下载失败\e[0m"
            echo -e "\e[34msteamcmd\e[0m 尝试备用源2: \e[92m${STEAMCMD_URL_BACKUP2}\e[0m"
            if ! curl --connect-timeout 10 -m 60 -fSLo "${TMPDIR}/steamcmd.tar.gz" "${STEAMCMD_URL_BACKUP2}"; then
                echo -e "\e[34msteamcmd\e[0m \e[31m所有Steam下载源都失败，尝试GitHub代理源\e[0m"
                echo -e "\e[34msteamcmd\e[0m 尝试GitHub代理: \e[92m${STEAMCMD_BASE_URI}\e[0m"
                if ! curl -m 180 -fSLo "${TMPDIR}/steamcmd.tar.gz" "${STEAMCMD_BASE_URI}"; then
                    echo -e "\e[34msteamcmd\e[0m \e[31m所有下载源都失败，请检查网络连接\e[0m"
                    exit 1
                fi
            fi
        fi
    fi

    echo -e "\e[34msteamcmd\e[0m \e[92m下载成功\e[0m"
    if ! tar -zxf "${TMPDIR}/steamcmd.tar.gz" -C "${DEFAULT_SH}/steamcmd"; then
        echo -e "\e[34msteamcmd.tar.gz\e[0m \e[31m解压失败\e[0m"
        rm -f "${TMPDIR}/steamcmd.tar.gz"
        exit 1
    fi
    
    rm -rf "${TMPDIR}"
    rm -rf "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}"
    steam_login
}

function start_server() {
    stop_server
    ln_lib32
    screen -dmS "${DEFAULT_DIR}" "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/srcds_run" -game left4dead2 ${START_PARAMETERS}
    sleep 1s
    screen -wipe > /dev/null 2>&1
    if ! screen -ls | grep -E "[0-9]+\.${DEFAULT_DIR}" > /dev/null 2>&1; then
        echo -e "\e[34m${DEFAULT_DIR}\e[0m \e[31m启动失败\e[0m"
        echo -e "\e[31m请检查相关参数是否配置正确\e[0m"
        exit 1
    else
        echo -e "\e[34m${DEFAULT_DIR}\e[0m \e[92m启动成功\e[0m"
        echo -e "\e[34m输入\e[0m \e[92mscreen -r ${DEFAULT_DIR}\e[0m \e[34m进入控制台\e[0m"
        echo -e "\e[34m快捷键\e[0m \e[92mCtrl + A + D\e[0m \e[34m退出控制台\e[0m"
    fi
}

function stop_server() {
    screen -wipe > /dev/null 2>&1
    screen -ls | grep -Eo "[0-9]+\.${DEFAULT_DIR}" | xargs -i screen -S {} -X quit
}

function restart_server() {
    start_server
}

function steam_login() {
    if [ "$SKIP_UPDATE" = "account" ] && [ -n "$STEAM_ACCOUNT" ] && [ -n "$STEAM_PASSWORD" ]; then
        echo -e "使用提供的 Steam 账户登录..."
        first_account_update_server
        return
    fi

    echo -e "\e[33m请输入数字并回车以选择要选择的\e[0m\e[31mSteam\e[0m\e[33m登录操作:\e[0m"
    echo -e "\e[92m1\e[0m.\e[34m选择匿名登录\e[0m"
    echo -e "\e[92m2\e[0m.\e[34m选择账号登录\e[0m\e[32m（登录的账号必须已购买求生之路2）\e[0m"
    echo -e "\e[33m5秒内未输入将自动选择匿名登录...\e[0m"
    
    # 使用更稳定的超时输入方式，增加超时时间到5秒
    local login_number=""
    # 如果超时，read 返回非零，使用 || true 防止 set -e 导致脚本退出
    read -t 5 -p "您的选择是: " login_number 2>/dev/null || true
    
    if [ -z "$login_number" ]; then
        echo -e "\n\e[32m超时，自动选择匿名登录\e[0m"
        first_anonymous_update_server
        return
    fi
    
    echo -e "\n\e[34m您选择了: ${login_number}\e[0m"
    case "${login_number}" in
        1)
            first_anonymous_update_server
            ;;
        2)
            first_account_update_server
            ;;
        *)
            echo -e "\e[31m无效输入 '${login_number}'，自动选择匿名登录\e[0m"
            first_anonymous_update_server
            ;;
    esac
}

function first_anonymous_update_server() {
    stop_server
    echo -e "\e[34mleft4dead2\e[0m 安装中 \e[92m...\e[0m"

    if ! "${DEFAULT_SH}/steamcmd/steamcmd.sh" +force_install_dir "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}" +login anonymous +@sSteamCmdForcePlatformType linux +app_info_update 1 +quit; then
        echo -e "\e[34mleft4dead2\e[0m \e[31m安装失败（若多次匿名安装失败,建议请账号登录安装）\e[0m"
        exit 1
    else
        if ! "${DEFAULT_SH}/steamcmd/steamcmd.sh" +force_install_dir "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}" +login anonymous +@sSteamCmdForcePlatformType windows +app_info_update 1 +quit; then
            echo -e "\e[34mleft4dead2\e[0m \e[31m安装失败（若多次匿名安装失败,建议请账号登录安装）\e[0m"
            exit 1
        else
            if ! "${DEFAULT_SH}/steamcmd/steamcmd.sh" +force_install_dir "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}" +login anonymous +@sSteamCmdForcePlatformType windows +app_info_update 1 +app_update 222860 validate +quit; then
                echo -e "\e[34mleft4dead2\e[0m \e[31m安装失败（若多次匿名安装失败,建议请账号登录安装）\e[0m"
                exit 1
            else
                if ! "${DEFAULT_SH}/steamcmd/steamcmd.sh" +force_install_dir "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}" +login anonymous +@sSteamCmdForcePlatformType linux +app_update 222860 validate +quit; then
                    echo -e "\e[34mleft4dead2\e[0m \e[31m安装失败（若多次匿名安装失败,建议账号登录安装）\e[0m"
                    exit 1
                else
                    echo -e "\e[34mleft4dead2\e[0m \e[92m安装成功\e[0m"
                fi
            fi
        fi
    fi
}

function first_account_update_server() {
    stop_server

    if [ -n "$STEAM_ACCOUNT" ] && [ -n "$STEAM_PASSWORD" ]; then
        STEAM_NAME="$STEAM_ACCOUNT"
        STEAM_PASS="$STEAM_PASSWORD"
        echo -e "使用预设的 Steam 账户: $STEAM_NAME"
    else
        while true; do
            echo 请输入账号
            read STEAM_NAME
            echo 确认账号为：${STEAM_NAME} 【输入Y/N，Y为确认，N为不确认并重新输入】
            read user_input
            if [ "$user_input" == "y" ]; then
                break
            elif [ "$user_input" == "n" ]; then
                echo 确认账号输错，重新输入
            else
                echo "无效输入，请输入 'y' 或 'n'。"
            fi
        done

        while true; do
            echo 请输入密码
            read STEAM_PASS
            echo 确认密码为：${STEAM_PASS} 【输入Y/N，Y为确认，N为不确认并重新输入】
            read user_input
            if [ "$user_input" == "y" ]; then
                break
            elif [ "$user_input" == "n" ]; then
                echo 确认密码输错，重新输入
            else
                echo "无效输入，请输入 'y' 或 'n'。"
            fi
        done
    fi

    echo -e "\e[34mleft4dead2\e[0m 安装中，期间需要输入\e[36m邮箱验证码\e[0m或\e[36m手机设备安全码\e[0m \e[92m...\e[0m"
     if ! "${DEFAULT_SH}/steamcmd/steamcmd.sh" +force_install_dir "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}" +login ${STEAM_NAME} ${STEAM_PASS} +app_update 222860 validate +quit; then
         echo -e "\e[34mleft4dead2\e[0m \e[31m安装失败\e[0m，请查看\e[31m Error \e[0m报错内容，若无则检查 \e[36m账号密码\e[0m 是否正确"
         exit 1
     else
         echo -e "\e[34mleft4dead2\e[0m \e[92m安装成功\e[0m"
     fi
}

function update_server() {
    ensure_network_test
    stop_server

    download_and_extract_quick_package

    echo -e "\e[34mleft4dead2\e[0m 安装中 \e[92m...\e[0m"
    if ! "${DEFAULT_SH}/steamcmd/steamcmd.sh" +force_install_dir "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}" +login anonymous +@sSteamCmdForcePlatformType linux +app_update 222860 validate +quit; then
        echo -e "\e[34mleft4dead2\e[0m \e[31m安装失败\e[0m"
        exit 1
    else
        echo -e "\e[34mleft4dead2\e[0m \e[92m安装成功\e[0m"
    fi
}

trap 'onCtrlC' INT
function onCtrlC () {
        kill -9 ${do_sth_pid} ${progress_pid}
        echo
        echo 你按了"CTRL+C"，已停止脚本
        exit 1
}

function do_sthi() {
        cp -rf "$folder_path/$folder_name/left4dead2" "$l4d2_menu"
}

function do_sthii() {
        for subfold in "${subfolde[@]}"; do
                rm -r "$l4d2_menu/$subfold"
        done
}

function progress() {
        local main_pid=$1
        local length=20
        local ratio=1
        while [ "$(ps -p ${main_pid} | wc -l)" -ne "1" ] ; do
                mark='>'
                progress_bar=
                for i in $(seq 1 "${length}"); do
                        if [ "$i" -gt "${ratio}" ] ; then
                                mark='-'
                        fi
                        progress_bar="${progress_bar}${mark}"
                done
                printf "操作中: ${progress_bar}\r"
                printf "操作中: ${progress_bar}\n" > "$progress_name"
                ratio=$((ratio+1))
                if [ "${ratio}" -gt "${length}" ] ; then
                        ratio=1
                fi
                sleep 0.1
        done
}

function progress_runi() {
do_sthi &
do_sth_pid=$(jobs -p | tail -1)
progress "${do_sth_pid}" &
progress_pid=$(jobs -p | tail -1)
wait "${do_sth_pid}"
cat "$progress_name"
}

function progress_runii() {
do_sthii &
do_sth_pid=$(jobs -p | tail -1)
progress "${do_sth_pid}" &
progress_pid=$(jobs -p | tail -1)
wait "${do_sth_pid}"
cat "$progress_name"
}

load_arrayi() {
if [ -s "$plugins_name" ]; then
    mapfile -t selected_folder < "$plugins_name"
else
    echo -e "\e[31m未安装插件，请安装插件后再使用此选项\e[0m"
    exit
fi
}

load_arrayii() {
if [ -s "$plugins_name" ]; then
    mapfile -t selected_folder < "$plugins_name"
fi
}

get_namei() {
load_arrayii

subfolders=($(ls -d "$folder_path"/*/))

count=1
for subfolder in "${subfolders[@]}"; do
    folder_name=$(basename "$subfolder")
    if [[ " ${selected_folder[*]} " == *" $folder_name "* ]]; then
        continue
    fi

    echo -e "\e[92m$count\e[0m.\e[34m$folder_name\e[0m"
    subfolde+=($folder_name)
    ((count++))
done
}

get_nameii() {
load_arrayi
count=1
for subfolder in "${selected_folder[@]}"; do
    folder_name=$(basename "$subfolder")
    echo -e "\e[92m$count\e[0m.\e[34m$folder_name\e[0m"
    ((count++))
done

}

plugins_install() {
echo -e "\e[36m请输入需要安装的插件数字，用分号\e[0m\e[41m（;）\e[0m\e[36m隔开\e[0m\e[41m（注意；数字如果错误一个则需要全部重新输入）\e[0m"
read user_input
IFS=";" read -ra input_numbers <<< "$user_input"

for number in "${input_numbers[@]}"; do
    if [[ $number =~ ^[0-9]+$ ]]; then
        index=$((number - 1))
        if [[ $number -ge 1 && $number -le ${#subfolde[@]} ]]; then
            selected_folders+=("${subfolde[number-1]}")
        else
            echo -e "\e[31m无效的数字\e[0m：\e[36m$number\e[0m，\e[31m请重新输入\e[0m"
        fi
        
        if ((index >= 0 && index < ${#subfolde[@]})); then
            selected_subfolder="${subfolde[index]}"
            folder_name=$(basename "$selected_subfolder")
            test_name+=($(basename "$folder_name"))
            echo -e "\e[46;34m正在安装插件\e[0m：\e[36m$folder_name\e[0m"
            progress_runi
            echo -e "\e[46;34m安装完成\e[0m"

        else
            echo -e "\e[31m无效的数字\e[0m：\e[36m$number\e[0m，\e[31m请重新输入\e[0m"
            plugins_install
        fi
    else
        echo -e "\e[31m无效的输入\e[0m：\e[36m$number\e[0m，\e[31m请重新输入\e[0m"
        plugins_install
    fi
done

printf "%s\n" "${test_name[@]}" >> "$plugins_name"


}

plugins_unload() {
echo -e "\e[36m请输入需要卸载的插件数字，用分号\e[0m\e[41m（;）\e[0m\e[36m隔开\e[0m\e[41m（注意；数字如果错误一个则需要全部重新输入）\e[0m"
read user_input
IFS=";" read -ra input_numbers <<< "$user_input"

for number in "${input_numbers[@]}"; do
    if [[ $number =~ ^[0-9]+$ ]]; then
        index=$((number - 1))
        if ((index >= 0 && index < ${#selected_folder[@]})); then
            selected_subfolder="${selected_folder[index]}"
            folder_name=$(basename "$selected_subfolder")
            test_name+=($(basename "$folder_name"))
            subfolde=($(find "$folder_path/$folder_name" -type f | sed "s|^$folder_path/$folder_name/||"))
            echo -e "\e[46;34m正在卸载插件\e[0m：\e[36m$folder_name\e[0m"
            progress_runii
            echo -e "\e[46;34m卸载完成\e[0m"
        else
            echo -e "\e[31m无效的数字\e[0m：\e[36m$number\e[0m，\e[31m请重新输入\e[0m"
            plugins_unload
        fi
    else
        echo -e "\e[31m无效的输入\e[0m：\e[36m$number\e[0m"
        plugins_unload
    fi
done

for name in "${test_name[@]}"; do
    grep -v "$name" "$plugins_name" > temp.txt
    mv temp.txt "$plugins_name"
done
}

function mixed_platform() {
    trap 'rm -rf "${DLDIR}"' EXIT
    DLDIR=$(mktemp -d)
    if [ "${?}" -ne 0 ]; then
        echo -e "\e[31m临时目录\e[0m \e[31m创建失败\e[0m"
        exit 1
    fi

    if [ -z "${1}" ]; then
        echo -e "\e[33m请选择要安装的插件平台版本:\e[0m"
        echo -e "\e[92m1\e[0m.\e[34m稳定版(默认)\e[0m"
        echo -e "\e[92m2\e[0m.\e[34m测试版\e[0m"
        read -p "您的选择是: " res
        if [ "${res}" == "2" ]; then
            MMS_URL=$(curl -s "https://www.sourcemm.net/downloads.php?branch=dev" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
            SM_URL=$(curl -s "http://www.sourcemod.net/downloads.php?branch=dev" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
        else
            MMS_URL=$(curl -s "https://www.sourcemm.net/downloads.php?branch=stable" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
            SM_URL=$(curl -s "http://www.sourcemod.net/downloads.php?branch=stable" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
        fi
    else
        if [ "${1}" == "-d" ]; then
            MMS_URL=$(curl -s "https://www.sourcemm.net/downloads.php?branch=dev" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
            SM_URL=$(curl -s "http://www.sourcemod.net/downloads.php?branch=dev" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
        else
            MMS_URL=$(curl -s "https://www.sourcemm.net/downloads.php?branch=stable" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
            SM_URL=$(curl -s "http://www.sourcemod.net/downloads.php?branch=stable" | grep "download-link" | grep -Eo "https://[^']+linux.tar.gz" | sort -nr | head -n 1)
        fi
    fi

    echo -e "\e[34mmmsource\e[0m 下载中 \e[92m${MMS_URL}\e[0m"
    if ! curl --connect-timeout 10 -m 600 -fSLo "${DLDIR}/mmsource-linux.tar.gz" "${MMS_URL}"; then
        echo -e "\e[34mmmsource\e[0m \e[31m下载失败\e[0m"
        exit 1
    fi

    if ! tar -zxf "${DLDIR}/mmsource-linux.tar.gz" -C "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/left4dead2"; then
        echo -e "\e[34mmmsource-linux.tar.gz\e[0m \e[31m解压失败\e[0m"
        exit 1
    fi

    sed -i '/"file"/c\\t"file"\t"..\/left4dead2\/addons\/metamod\/bin\/server"' "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/left4dead2/addons/metamod.vdf"
    sed -i '/"file"/c\\t"file"\t"..\/left4dead2\/addons\/metamod\/bin\/server"' "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/left4dead2/addons/metamod_x64.vdf"
    echo -e "\e[34mmmsource\e[0m \e[92m下载成功\e[0m"

    echo -e "\e[34msourcemod\e[0m 下载中 \e[92m${SM_URL}\e[0m"
    if ! curl --connect-timeout 10 -m 600 -fSLo "${DLDIR}/sourcemod-linux.tar.gz" "${SM_URL}"; then
        echo -e "\e[34msourcemod\e[0m \e[31m下载失败\e[0m"
        exit 1
    fi

    if ! tar -zxf "${DLDIR}/sourcemod-linux.tar.gz" -C "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/left4dead2"; then
        echo -e "\e[34msourcemod-linux.tar.gz\e[0m \e[31m解压失败\e[0m"
        exit 1
    fi

    rm -f "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/left4dead2/addons/sourcemod/plugins/nextmap.smx"
    echo -e "\e[34msourcemod\e[0m \e[92m下载成功\e[0m"
    rm -rf "${DLDIR}"
}

function ln_lib32() {
    [ -e "/lib32/libgcc_s.so.1" ] && [ -e "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/bin/libgcc_s.so.1" ] && ln -sf "/lib32/libgcc_s.so.1" "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/bin/libgcc_s.so.1"
    [ -e "/lib32/libstdc++.so.6" ] && [ -e "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/bin/libstdc++.so.6" ] && ln -sf "/lib32/libstdc++.so.6" "${DEFAULT_SH}/steamcmd/${DEFAULT_DIR}/bin/libstdc++.so.6"
}

function main() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --skip-script|-ws)
                if [ -n "$2" ] && ([ "$2" = "true" ] || [ "$2" = "false" ]); then
                    SKIP_SCRIPT="$2"
                    shift 2
                else
                    echo -e "\e[33m警告：--skip-script 参数需要 true 或 false 值，使用默认行为\e[0m"
                    SKIP_SCRIPT=""
                    shift
                fi
                ;;
            --skip-package|-wp)
                if [ -n "$2" ] && ([ "$2" = "true" ] || [ "$2" = "false" ]); then
                    SKIP_PACKAGE="$2"
                    shift 2
                else
                    echo -e "\e[33m警告：--skip-package 参数需要 true 或 false 值，使用默认行为\e[0m"
                    SKIP_PACKAGE=""
                    shift
                fi
                ;;
            --skip-delete|-wd)
                if [ -n "$2" ] && ([ "$2" = "true" ] || [ "$2" = "false" ]); then
                    SKIP_DELETE="$2"
                    shift 2
                else
                    echo -e "\e[33m警告：--skip-delete 参数需要 true 或 false 值，使用默认行为\e[0m"
                    SKIP_DELETE=""
                    shift
                fi
                ;;
            --skip-update|-su)
                if [ -n "$2" ] && [ -n "$3" ]; then
                    STEAM_ACCOUNT="$2"
                    STEAM_PASSWORD="$3"
                    SKIP_UPDATE="account"
                    shift 3
                else
                    echo -e "\e[33m警告：--skip-update 参数需要 Steam 账户和密码，使用默认行为\e[0m"
                    shift
                fi
                ;;
            *)
                break
                ;;
        esac
    done
    
    if [ "${#}" -gt 0 ]; then
        case "${1}" in
            -0|--install-all|0|"environment")
                echo "执行: 安装依赖软件包并下载游戏服务端"
                environment
                ;;
            -1|--deps-only|1|"install_dependencies")
                echo "执行: 安装依赖软件包"
                install_dependencies
                ;;
            -2|--server-only|2|"install")
                echo "执行: 下载游戏服务端"
                install_server
                ;;
            -3|--start|3|"start_server")
                echo "执行: 启动游戏服务端"
                start_server
                ;;
            -4|--stop|4|"stop_server")
                echo "执行: 停止游戏服务端"
                stop_server
                ;;
            -5|--restart|5|"restart"|"restart_server")
                echo "执行: 重启游戏服务端"
                restart_server
                ;;
            -6|--update|6|"update"|"update_server")
                echo "执行: 更新游戏服务端"
                update_server
                ;;
            -9|--install-platform|9|"mixed")
                echo "执行: 安装插件平台"
                if [ "${#}" -ge 2 ] && [[ "${PLUGIN_VERSION[@]}" =~ "${2}" ]]; then
                    mixed_platform "${2}"
                else
                    mixed_platform
                fi
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "未知选项: ${1}"
                echo "使用 -h 或 --help 查看帮助信息"
                exit 1
                ;;
        esac
        if [ "${#}" -gt 1 ]; then
            echo "注意: 脚本只执行第一个启动项 '${1}'，忽略其余参数"
        fi
        exit 0
    else
        echo -e "\e[33m请输入数字并回车以选择要执行的操作:\e[0m"
        echo -e "\e[92m0\e[0m.\e[34m(初次选这个)安装依赖软件包并下载游戏服务端\e[0m"
        echo -e "\e[92m1\e[0m.\e[34m安装依赖软件包\e[0m"
        echo -e "\e[92m2\e[0m.\e[34m下载游戏服务端\e[0m"
        echo -e "\e[92m3\e[0m.\e[34m启动游戏服务端\e[0m"
        echo -e "\e[92m4\e[0m.\e[34m停止游戏服务端\e[0m"
        echo -e "\e[92m5\e[0m.\e[34m重启游戏服务端\e[0m"
        echo -e "\e[92m6\e[0m.\e[34m更新游戏服务端\e[0m"
        echo -e "\e[92m7\e[0m.\e[34m安装插件\e[0m"
        echo -e "\e[92m8\e[0m.\e[34m卸载插件\e[0m"
        echo -e "\e[92m9\e[0m.\e[34m安装插件平台\e[0m"
        read -p "您的选择是: " res
        case "${res}" in
            0)
                environment
                ;;
            1)
                install_dependencies
                ;;
            2)
                install_server
                ;;
            3)
                start_server
                ;;
            4)
                stop_server
                ;;
            5)
                restart_server
                ;;
            6)
                update_server
                ;;
            7)
                get_namei
                plugins_install
                ;;
            8)
                get_nameii
                plugins_unload
                ;;
            9)
                mixed_platform
                ;;
            *)
                echo "未知选项: ${res}"
                exit 1
                ;;
        esac
    fi
}

function show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "主要选项:"
    echo "  -0, --install-all      安装依赖软件包并下载游戏服务端"
    echo "  -1, --deps-only        仅安装依赖软件包"
    echo "  -2, --server-only      仅下载游戏服务端"
    echo "  -3, --start            启动游戏服务端"
    echo "  -4, --stop             停止游戏服务端"
    echo "  -5, --restart          重启游戏服务端"
    echo "  -6, --update           更新游戏服务端"
    echo "  -9, --install-platform 安装插件平台"
    echo ""
    echo "等待控制参数:"
    echo "  --skip-script, -ws [true/false]  控制依赖安装等待"
    echo "  --skip-package, -wp [true/false]  控制快速更新包等待"
    echo "  --skip-delete, -wd [true/false]  控制删除服务端目录等待"
    echo "  --skip-updata, -su <Steam账户> <Steam密码>  自动使用Steam账户登录Steamcmd"
    echo ""
    echo "等待行为说明:"
    echo "  true:  跳过等待，直接执行后续操作"
    echo "  false: 不等待，直接跳过后续操作"
    echo "  不传或异常: 保持原行为 (等待3秒，按键跳过，否则执行)"
    echo ""
    echo "示例:"
    echo "  $0 --skip-script true --skip-package false -0"
    echo "  $0 -ws true -wp false -wd true -2"
    echo "  $0 --skip-updata myaccount mypassword -2"
    echo ""
    echo "无参数时显示交互式菜单"
}

main ${*}

