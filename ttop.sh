#!/bin/bash
TTOP_VERSION="ttop v0.1"

trap "tput cnorm; clear; exit" INT

bar() {
  local percent=$1 color=$2
  ((percent>100)) && percent=100
  local filled=$(( percent / 2 ))
  local empty=$(( 50 - filled ))
  printf "\e[48;5;${color}m%${filled}s\e[0m" "" | tr ' ' '█'
  printf "%*s" "${empty}" ""
}

# 一次性取得較少變動的資訊
OS_NAME=$( . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-$(uname -s)}" )  # 發行版名稱[web:92][web:96]
KERNEL=$(uname -r)                                                             # 內核版本[web:96]
BASH_VER=$(echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}")# Bash 版本[web:90]

clear
tput civis

while true; do
  tput cup 0 0

  CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
  RAM=$(free | awk 'NR==2{printf "%.0f",$3*100/$2}')
  DISK_ROOT=$(df / | awk 'NR==2{gsub("%","",$5); print $5}')
  UPTIME_STR=$(uptime -p 2>/dev/null | sed 's/^up //')                         # 人類可讀 uptime[web:88]

  # 標題：ttop 版本 + OS + Kernel + Bash
  printf "\e[1;35m%s\e[0m\n" "$TTOP_VERSION"
  printf "\e[36mOS: %s\e[0m  \e[36mKernel: %s\e[0m  \e[36mBash: %s\e[0m\n" \
    "$OS_NAME" "$KERNEL" "$BASH_VER"
  printf "\e[90mUptime: %s\e[0m\n\n" "$UPTIME_STR"

  printf "\e[1;36m CPU \e[0m\e[38;5;208m%3s%%\e[0m [%s]\n"  "$CPU"      "$(bar "$CPU"      2)"
  printf "\e[1;36m RAM \e[0m\e[38;5;208m%3s%%\e[0m [%s]\n"  "$RAM"      "$(bar "$RAM"      4)"
  printf "\e[1;36mDisk \e[0m\e[38;5;208m%3s%%\e[0m [%s]\n\n" "$DISK_ROOT" "$(bar "$DISK_ROOT" 1)"

  printf "\e[1;34m──────────────────────── 所有硬碟可用空間 ────────────────────────\e[0m\n"
  printf "%-18s %-8s %-8s %-8s %-6s %s\n" "裝置" "大小" "已用" "可用" "使用" "掛載點"

  df -h --output=source,size,used,avail,pcent,target | \
    sed 's/\x1b\[[0-9;]*m//g' | \
    awk 'NR>1{
      printf "%-18s %-8s %-8s %-8s %-6s %s\n",
             $1,$2,$3,$4,$5,$6
    }'

  printf "\e[1;34m────────────────────────────────────────────────────────────────\e[0m\n"
  printf "\e[1;33m按 Ctrl+C 退出\e[0m\n"

  sleep 1
done
