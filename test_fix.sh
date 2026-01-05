#!/bin/bash

# 测试修复后的网络功能
echo "=== 测试网络修复功能 ==="

# 模拟网络测试函数
source ./server_install/linux/init.sh

# 测试代理测速功能
echo "1. 测试代理测速功能..."
ensure_network_test

echo ""
echo "2. 当前选择的代理: ${SELECTED_PROXY:-\"无\"}"
echo "3. 当前选择的Steam下载源: ${STEAMCMD_URL}"
echo "4. GitHub代理源: ${STEAMCMD_BASE_URI}"

echo ""
echo "5. 测试各个Steam下载源是否可访问..."

# 测试各个下载源
steam_urls=(
    "https://cdn.steamchina.eccdnx.com/client/installer/steamcmd_linux.tar.gz"
    "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" 
    "https://media.steampowered.com/client/installer/steamcmd_linux.tar.gz"
)

for url in "${steam_urls[@]}"; do
    echo "测试: $url"
    if curl -I -s --connect-timeout 5 --max-time 10 "$url" > /dev/null; then
        echo "✅ 可访问"
    else
        echo "❌ 不可访问"
    fi
done

echo ""
echo "=== 测试完成 ==="