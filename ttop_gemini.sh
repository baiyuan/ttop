#!/bin/bash

# ==========================================
# TTOP - Improved by Gemini (v1.1)
# ==========================================

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

# --- 捕捉信號 ---
# 捕捉 Ctrl+C (SIGINT)
trap cleanup INT

# 初始化畫面
tput civis # 隱藏游標
clear

# --- 靜態系統資訊 ---
OS_NAME=$(grep -E '^(PRETTY_NAME|NAME)=' /etc/os-release | head -1 | cut -d'"' -f2)
KERNEL=$(uname -r)
HOSTNAME=$(hostname)

# --- 函數：繪製進度條 ---
draw_bar() {
    local percent=$1
    local filled=$(( (percent * BAR_WIDTH) / 100 ))
    local empty=$(( BAR_WIDTH - filled ))
    
    local bar_color=$GREEN
    if (( percent >= 80 )); then bar_color=$RED
    elif (( percent >= 50 )); then bar_color=$YELLOW
    fi

    local fill_str=$(printf "%${filled}s")
    local empty_str=$(printf "%${empty}s")
    
    printf "${BG_DARK}${bar_color}${fill_str// /█}${GRAY}${empty_str// /░}${RESET}"
}

# --- 函數：獲取 CPU 使用率 ---
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
    
    df -h -x tmpfs -x devtmpfs -x squashfs -x overlay --output=source,size,used,avail,pcent,target | \
    tail -n +2 | \
    while read -r src size used avail pcent target; do
        local p_val=${pcent%\%}
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
    
    eval $(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf "MEM_TOTAL=%d; MEM_AVAIL=%d", t, a}' /proc/meminfo)
    MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
    MEM_PERCENT=$(( (MEM_USED * 100) / MEM_TOTAL ))
    
    read load1 load5 load15 rest < /proc/loadavg
    UPTIME=$(uptime -p | sed 's/up //;s/ hours/h/;s/ minutes/m/')

    # 2. 顯示內容
    echo -e "${BOLD}${WHITE}TTOP v1.1${RESET} | ${CYAN}${HOSTNAME}${RESET} | ${GRAY}${OS_NAME}${RESET}"
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

    # 3. 按鍵監聽 (核心修改部分)
    # -t: 超時時間(等於刷新率)
    # -n 1: 讀取一個字元
    # -s: 靜默模式(不回顯按下的鍵)
    read -t $REFRESH_RATE -n 1 -s key
    
    # 判斷是否按下 q 或 Q
    if [[ "$key" == "q" || "$key" == "Q" ]]; then
        cleanup # 呼叫清理函數退出
    fi
done
