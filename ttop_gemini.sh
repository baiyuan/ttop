#!/bin/bash

# ==========================================
# TTOP - Universal Linux Version (v1.2)
# ==========================================

# --- [Check] 相依性檢查 ---
check_dependencies() {
    local missing_deps=()
    local dependencies=("tput" "awk" "uptime" "df" "grep" "uname")

    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "\e[1;31m[Error] 缺少必要的系統工具，無法執行：\e[0m"
        echo -e "Missing commands: \e[1;33m${missing_deps[*]}\e[0m"
        echo ""
        echo "請依照您的作業系統執行以下安裝指令："
        echo "---------------------------------------------------"
        if [ -f /etc/alpine-release ]; then
            echo -e "Alpine: \e[1;32mapk add ncurses gawk procps coreutils\e[0m"
        elif [ -f /etc/debian_version ]; then
            echo -e "Debian/Ubuntu: \e[1;32msudo apt-get update && sudo apt-get install ncurses-bin gawk procps\e[0m"
        elif [ -f /etc/redhat-release ]; then
            echo -e "CentOS/RHEL: \e[1;32msudo yum install ncurses gawk procps-ng\e[0m"
        elif [ -f /etc/arch-release ]; then
            echo -e "Arch Linux: \e[1;32msudo pacman -S ncurses gawk procps-ng\e[0m"
        else
            echo "其他系統請安裝: ncurses, gawk, procps"
        fi
        echo "---------------------------------------------------"
        exit 1
    fi
}
check_dependencies

# --- [Config] 設定區 ---
REFRESH_RATE=1
BAR_WIDTH=40

# --- [Color] 顏色定義 ---
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

# --- [Exit] 清理函數 ---
cleanup() {
    tput cnorm
    echo -e "${RESET}"
    clear
    exit 0
}
trap cleanup INT

# 初始化
tput civis
clear

# --- [Info] 靜態系統資訊 ---
if [ -f /etc/os-release ]; then
    OS_NAME=$(grep -E '^(PRETTY_NAME|NAME)=' /etc/os-release | head -1 | cut -d'"' -f2)
else
    OS_NAME=$(uname -s)
fi
KERNEL=$(uname -r)
HOSTNAME=$(hostname)

# --- [Draw] 繪圖函數 ---
draw_bar() {
    local percent=$1
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
    
    printf "${BG_DARK}${bar_color}${fill_str// /█}${GRAY}${empty_str// /░}${RESET}"
}

# --- [CPU] 計算邏輯 ---
read cpu a b c idle rest < /proc/stat
prev_total=$((a+b+c+idle))
prev_idle=$idle

get_cpu_usage() {
    read cpu a b c idle rest < /proc/stat
    local total=$((a+b+c+idle))
    local diff_total=$((total - prev_total))
    local diff_idle=$((idle - prev_idle))
    
    if (( diff_total == 0 )); then echo "0"; else
        echo $(( (100 * (diff_total - diff_idle)) / diff_total ))
    fi
    prev_total=$total
    prev_idle=$idle
}

# --- [Disk] 磁碟列表 ---
print_disk_info() {
    printf "${BOLD}${BLUE}%-15s %-8s %-8s %-8s %-6s %s${RESET}\n" "Device" "Size" "Used" "Avail" "Use%" "Mount"
    echo -e "${GRAY}────────────────────────────────────────────────────────────${RESET}"
    
    df -h -x tmpfs -x devtmpfs -x squashfs -x overlay -x iso9660 --output=source,size,used,avail,pcent,target 2>/dev/null | \
    tail -n +2 | \
    while read -r src size used avail pcent target; do
        local p_val=${pcent%\%}
        [[ "$p_val" =~ ^[0-9]+$ ]] || p_val=0

        local p_color=$GREEN
        if (( p_val >= 90 )); then p_color=$RED; elif (( p_val >= 70 )); then p_color=$YELLOW; fi
        
        printf "%-15s %-8s %-8s %-8s ${p_color}%-6s${RESET} %s\n" \
            "${src:0:14}" "$size" "$used" "$avail" "$pcent" "$target"
    done
}

# --- [Main] 主迴圈 ---
while true; do
    tput cup 0 0

    # 1. 計算
    CPU_USAGE=$(get_cpu_usage)
    eval $(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf "MEM_TOTAL=%d; MEM_AVAIL=%d", t, a}' /proc/meminfo)
    : ${MEM_TOTAL:=1}
    : ${MEM_AVAIL:=0}
    MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
    MEM_PERCENT=$(( (MEM_USED * 100) / MEM_TOTAL ))
    
    read load1 load5 load15 rest < /proc/loadavg
    
    UPTIME_RAW=$(uptime -p 2>/dev/null)
    if [ -z "$UPTIME_RAW" ]; then
        UP_SEC=$(awk '{print int($1)}' /proc/uptime)
        UPTIME="${UP_SEC}s"
    else
        UPTIME=$(echo "$UPTIME_RAW" | sed 's/up //;s/ hours/h/;s/ minutes/m/')
    fi

    # 2. 顯示
    echo -e "${BOLD}${WHITE}TTOP v1.2${RESET} | ${CYAN}${HOSTNAME}${RESET} | ${GRAY}${OS_NAME}${RESET}"
    echo -e "${GRAY}Kernel: ${KERNEL} | Uptime: ${UPTIME}${RESET}"
    echo ""

    printf "${BOLD}CPU ${RESET} [%3d%%] %s  ${GRAY}Load: ${load1} ${load5} ${load15}${RESET}\n" "$CPU_USAGE" "$(draw_bar "$CPU_USAGE")"
    
    MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_USED/1024/1024}")
    MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_TOTAL/1024/1024}")
    
    printf "${BOLD}RAM ${RESET} [%3d%%] %s  ${GRAY}${MEM_USED_GB}G / ${MEM_TOTAL_GB}G${RESET}\n" "$MEM_PERCENT" "$(draw_bar "$MEM_PERCENT")"

    echo ""
    print_disk_info

    echo ""
    echo -e "${GRAY}Press [q] or Ctrl+C to exit${RESET}"
    tput ed 

    # 3. 監聽
    read -t $REFRESH_RATE -n 1 -s key
    if [[ "$key" == "q" || "$key" == "Q" ]]; then cleanup; fi
done
