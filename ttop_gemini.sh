#!/bin/bash

# ==========================================
# TTOP - Universal Linux Version (v1.2)
# ==========================================

# --- [新增] 相依性檢查與安裝建議 ---
check_dependencies() {
    local missing_deps=()
    
    # 定義需要檢查的指令
    local dependencies=("tput" "awk" "uptime" "df" "grep" "uname")

    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # 如果有缺少的指令
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "\e[1;31m[錯誤] 缺少必要的系統工具，無法執行：\e[0m"
        echo -e "缺少指令: \e[1;33m${missing_deps[*]}\e[0m"
        echo ""
        echo "請依照您的作業系統執行以下安裝指令："
        echo "---------------------------------------------------"

        # 簡單的發行版偵測邏輯
        if [ -f /etc/alpine-release ]; then
            # Alpine Linux
            echo -e "Alpine: \e[1;32mapk add ncurses gawk procps coreutils\e[0m"
        elif [ -f /etc/debian_version ]; then
            # Debian / Ubuntu
            echo -e "Debian/Ubuntu: \e[1;32msudo apt-get update && sudo apt-get install ncurses-bin gawk procps\e[0m"
        elif [ -f /etc/redhat-release ]; then
            # CentOS / RHEL / Fedora
            echo -e "CentOS/RHEL: \e[1;32msudo yum install ncurses gawk procps-ng\e[0m"
        elif [ -f /etc/arch-release ]; then
            # Arch Linux
            echo -e "Arch Linux: \e[1;32msudo pacman -S ncurses gawk procps-ng\e[0m"
        else
            echo "其他系統請安裝包含以下指令的套件: ncurses, gawk, procps"
        fi
        echo "---------------------------------------------------"
        exit 1
    fi
}

# 執行檢查
check_dependencies

# --- 配置區 ---
REFRESH_RATE=1
BAR_WIDTH=40

# --- 顏色定義 ---
RESET="\e[0m"
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
GRAY="\e[90m"
WHITE="\e[97m"
BG_DARK="\e[48;5;236m"

# --- 退出清理函數 ---
cleanup() {
    tput cnorm  # 恢復游標
    echo -e "${RESET}"
    clear
    exit 0
}

# --- 捕捉信號 (Ctrl+C) ---
trap cleanup INT

# 初始化畫面
tput civis # 隱藏游標
clear

# --- 靜態系統資訊 ---
# 嘗試多種方式獲取 OS 名稱以兼容不同發行版
if [ -f /etc/os-release ]; then
    OS_NAME=$(grep -E '^(PRETTY_NAME|NAME)=' /etc/os-release | head -1 | cut -d'"' -f2)
else
    OS_NAME=$(uname -s)
fi

KERNEL=$(uname -r)
HOSTNAME=$(hostname)

# --- 函數：繪製進度條 ---
draw_bar() {
    local percent=$1
    # 邊界檢查，防止數值超過 100 破壞排版
    (( percent > 100 )) && percent=100
    (( percent < 0 )) && percent=0

    local filled=$(( (percent * BAR_WIDTH) / 100 ))
    local empty=$(( BAR_WIDTH - filled ))
    
    local bar_color=$GREEN
    if (( percent >= 80 )); then bar_color=$RED
    elif (( percent >= 50 )); then bar_color=$YELLOW
    fi

    local fill_str=$(printf "%${filled}s")
    local empty_str=$(printf "%${empty}s")
    
    # 注意：某些極簡 bash 環境可能不支援 // 替換，但現代 bash 4.0+ 都支援
    # 若需極致兼容，可用 sed，但效能較差。此處假設 Bash 4.0+
    printf "${BG_DARK}${bar_color}${fill_str// /█}${GRAY}${empty_str// /░}${RESET}"
}

# --- 函數：獲取 CPU 使用率 ---
# 初始化變數
read cpu a b c idle rest < /proc/stat
prev_total=$((a+b+c+idle))
prev_idle=$idle

get_cpu_usage() {
    read cpu a b c idle rest < /proc/stat
    local total=$((a+b+c+idle))
    local diff_total=$((total - prev_total))
    local diff_idle=$((idle - prev_idle))
    
    if (( diff_total == 0 )); then
        echo "0"
    else
        echo $(( (100 * (diff_total - diff_idle)) / diff_total ))
    fi

    prev_total=$total
    prev_idle=$idle
}

# --- 函數：格式化輸出磁碟資訊 ---
print_disk_info() {
    printf "${BOLD}${BLUE}%-15s %-8s %-8s %-8s %-6s %s${RESET}\n" "裝置" "容量" "已用" "可用" "使用%" "掛載點"
    echo -e "${GRAY}────────────────────────────────────────────────────────────${RESET}"
    
    # 增加更多排除項目以適應 snap/docker 環境
    # 增加錯誤轉向 2>/dev/null 避免 df 在某些特殊掛載點報錯
    df -h -x tmpfs -x devtmpfs -x squashfs -x overlay -x iso9660 --output=source,size,used,avail,pcent,target 2>/dev/null | \
    tail -n +2 | \
    while read -r src size used avail pcent target; do
        local p_val=${pcent%\%}
        # 處理無效數值 (例如 -)
        [[ "$p_val" =~ ^[0-9]+$ ]] || p_val=0

        local p_color=$GREEN
        if (( p_val >= 90 )); then p_color=$RED; elif (( p_val >= 70 )); then p_color=$YELLOW; fi
        
        printf "%-15s %-8s %-8s %-8s ${p_color}%-6s${RESET} %s\n" \
            "${src:0:14}" "$size" "$used" "$avail" "$pcent" "$target"
    done
}

# --- 主迴圈 ---
while true; do
    tput cup 0 0

    # 1. 數據計算
    CPU_USAGE=$(get_cpu_usage)
    
    # 兼容性調整：某些 awk 版本需要明確參數
    eval $(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf "MEM_TOTAL=%d; MEM_AVAIL=%d", t, a}' /proc/meminfo)
    
    # 如果無法從 meminfo 獲取 (極罕見)，防止報錯
    : ${MEM_TOTAL:=1}
    : ${MEM_AVAIL:=0}

    MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
    MEM_PERCENT=$(( (MEM_USED * 100) / MEM_TOTAL ))
    
    read load1 load5 load15 rest < /proc/loadavg
    
    # Uptime 格式化 (如果 uptime 指令輸出非標準格式，sed 可能失效，但不會崩潰)
    UPTIME_RAW=$(uptime -p 2>/dev/null)
    if [ -z "$UPTIME_RAW" ]; then
        # 如果 uptime -p 不支援 (如某些 busybox)，嘗試讀取 /proc/uptime
        UP_SEC=$(awk '{print int($1)}' /proc/uptime)
        UPTIME="${UP_SEC}s (raw)"
    else
        UPTIME=$(echo "$UPTIME_RAW" | sed 's/up //;s/ hours/h/;s/ minutes/m/')
    fi

    # 2. 顯示內容
    echo -e "${BOLD}${WHITE}TTOP v1.2${RESET} | ${CYAN}${HOSTNAME}${RESET} | ${GRAY}${OS_NAME}${RESET}"
    echo -e "${GRAY}Kernel: ${KERNEL} | Uptime: ${UPTIME}${RESET}"
    echo ""

    # CPU & RAM
    printf "${BOLD}CPU ${RESET} [%3d%%] %s  ${GRAY}Load: ${load1} ${load5} ${load15}${RESET}\n" \
        "$CPU_USAGE" "$(draw_bar "$CPU_USAGE")"
    
    MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_USED/1024/1024}")
    MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_TOTAL/1024/1024}")
    
    printf "${BOLD}RAM ${RESET} [%3d%%] %s  ${GRAY}${MEM_USED_GB}G / ${MEM_TOTAL_GB}G${RESET}\n" \
        "$MEM_PERCENT" "$(draw_bar "$MEM_PERCENT")"

    echo ""

    # Disk
    print_disk_info

    echo ""
    echo -e "${GRAY}Press [q] or Ctrl+C to exit${RESET}"
    tput ed 

    # 3. 按鍵監聽
    # 為了兼容性，有些舊系統的 read 不支援 -t 0 或小數點，這裡維持整數
    read -t $REFRESH_RATE -n 1 -s key
    
    if [[ "$key" == "q" || "$key" == "Q" ]]; then
        cleanup
    fi
done
