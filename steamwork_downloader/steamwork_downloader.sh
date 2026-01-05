#!/bin/bash
DEBUG=${DEBUG:-0}
MAX_CONCURRENT=5
MODE="ask"  # 默认模式: ask|auto|query

debug_info() {
    [ "$DEBUG" -eq 1 ] && echo "[DEBUG] $*"
}
show_help() {
    echo "Steam 创意工坊下载工具"
    echo "用法: $0 [选项] <文件ID列表>"
    echo "选项:"
    echo "  -a    自动模式 (直接下载)"
    echo "  -q    仅查询模式 (不下载)"
    echo "  -c NUM 设置并发数 (默认: 5)"
    echo "  -d    启用调试模式"
    echo "示例:"
    echo "  $0 -a -c 10 123 456 789     自动下载3个文件，10并发"
    echo "  $0 -q 123456                仅查询文件信息"
}

parse_args() {
    while getopts "aqdc:h" opt; do
        case $opt in
            a) MODE="auto" ;;
            q) MODE="query" ;;
            c) MAX_CONCURRENT=$OPTARG ;;
            d) DEBUG=1 ;;
            h) show_help; exit 0 ;;
            *) show_help; exit 1 ;;
        esac
    done
    shift $((OPTIND-1))
    IDS=("$@")
}

download_file() {
    local url="$1"
    local filename="$2"
    local retries=3
    
    debug_info "开始下载: $filename"
    for ((i=1; i<=retries; i++)); do
        if wget --show-progress -q -c -O "$filename" "$url"; then
            echo "[成功] 已下载: $filename"
            return 0
        else
            echo "[重试] 第 $i 次下载失败: $filename"
            sleep $((i*2))
        fi
    done
    echo "[错误] 无法下载: $filename"
    return 1
}

process_id() {
    local id="$1"
    local tmpfile=$(mktemp)
    
    debug_info "处理ID: $id => $tmpfile"
    
    # API请求
    if ! wget --header="Content-Type: application/x-www-form-urlencoded" \
              --post-data "itemcount=1&publishedfileids[0]=$id" \
              -qO "$tmpfile" \
              "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/"; then
        flock -x 200 echo "[错误] ID $id 请求失败"
        return 1
    fi

    # 解析结果
    local result=$(jq -r '.response.result' "$tmpfile")
    if [ "$result" != "1" ]; then
        flock -x 200 echo "[错误] ID $id 无效 (代码 $result)"
        return 1
    fi

    local title=$(jq -r '.response.publishedfiledetails[0].title' "$tmpfile")
    local url=$(jq -r '.response.publishedfiledetails[0].file_url' "$tmpfile")
    local filename=$(jq -r '.response.publishedfiledetails[0].filename' "$tmpfile")

    # 输出结果
    {
        flock -x 200
        echo "================"
        echo "ID:        $id"
        echo "标题:      $title"
        echo "文件名:    $filename"
        echo "文件大小:  $(numfmt --to=iec $(jq -r '.response.publishedfiledetails[0].file_size' "$tmpfile"))"
        echo "URL:       $url"
    } >> /dev/stdout

    # 处理下载
    case $MODE in
        "auto")
            download_file "$url" "$filename" &
            ;;
        "ask")
            {
                flock -x 200
                read -p "是否下载 '$filename'? [y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    download_file "$url" "$filename"
                fi
            } 
            ;;
    esac

    rm "$tmpfile"
}

main() {
    parse_args "$@"
    [[ ${#IDS[@]} -eq 0 ]] && show_help && exit 1

    debug_info "启动模式: $MODE"
    debug_info "并发数: $MAX_CONCURRENT"
    debug_info "目标ID数: ${#IDS[@]}"

    # 准备进程池
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    mkfifo "$tmpdir/pipe"
    exec 200<>"$tmpdir/pipe"
    for ((i=0; i<MAX_CONCURRENT; i++)); do echo >&200; done

    # 进度跟踪
    total=${#IDS[@]}
    completed=0
    echo "开始处理 $total 个文件..."

    # 启动任务
    for id in "${IDS[@]}"; do
        read -u 200
        {
            process_id "$id"
            echo >&200
            completed=$((completed + 1))
            printf "进度: %d/%d (%.1f%%)\r" "$completed" "$total" "$(echo "scale=1; 100*$completed/$total" | bc)"
        } &
    done

    wait
    echo -e "\n全部任务已完成"
}

main "$@"
