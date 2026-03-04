#!/bin/sh
# =================================================================
# FreshTomato Theme — Dynamic MOTD Generator
# Dibaca tiap login SSH, info diambil live dari sistem
# =================================================================

# --- Colors ---
R='\033[0m'
B='\033[1m'
D='\033[2m'
CY='\033[0;36m'
GR='\033[0;32m'
YL='\033[1;33m'
PK='\033[1;35m'
WH='\033[1;37m'
RD='\033[0;31m'
BL='\033[0;34m'

# --- Load theme info ---
INFO_FILE="/jffs/Theme/www/.theme_info"
THEME_NAME="Unknown"
THEME_SCRIPT="bg-video.js"
INSTALLED_DATE="-"
if [ -f "$INFO_FILE" ]; then
    . "$INFO_FILE"
fi

# --- Collect system info ---
ROUTER=$(nvram get t_model_name 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null)
FW=$(nvram get os_version 2>/dev/null | cut -c1-32)
LAN_IP=$(nvram get lan_ipaddr 2>/dev/null || echo "?")
WAN_IP=$(nvram get wan_ipaddr 2>/dev/null || echo "?")
WAN_IF=$(nvram get wan_ifname 2>/dev/null || echo "?")
WAN_MAC=$(nvram get wan_hwaddr 2>/dev/null || echo "?")
UPTIME=$(awk '{d=int($1/86400);h=int(($1%86400)/3600);m=int(($1%3600)/60); printf "%dd %02dh %02dm",d,h,m}' /proc/uptime 2>/dev/null)
CPU_MHZ=$(grep 'cpu MHz' /proc/cpuinfo 2>/dev/null | head -1 | awk '{printf "%.0f",$4}')
CPU_CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
MEM_TOTAL=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null)
MEM_FREE=$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null)
MEM_USED=$((MEM_TOTAL - MEM_FREE))
MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
LOAD=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)
DATE_NOW=$(date "+%a %d %b %Y  %H:%M:%S")
CLIENTS=$(arp -n 2>/dev/null | grep -c 'ether' || echo "?")

# Bar helper (10 chars)
bar() {
    PCT=$1; FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
    BAR=""
    i=0; while [ $i -lt $FILLED ]; do BAR="${BAR}█"; i=$((i+1)); done
    i=0; while [ $i -lt $EMPTY  ]; do BAR="${BAR}░"; i=$((i+1)); done
    echo "$BAR"
}

MEM_BAR=$(bar $MEM_PCT)
[ $MEM_PCT -ge 80 ] && MEM_COLOR=$RD || MEM_COLOR=$GR

# --- MOTD Output ---
printf "${PK}"
printf "  ╔══════════════════════════════════════════════════╗\n"
printf "  ║   ${B}${WH}⚡ FreshTomato Theme  ${D}by Lucrumae${R}${PK}              ║\n"
printf "  ╚══════════════════════════════════════════════════╝${R}\n"
printf "\n"

# Router & Firmware
printf "  ${D}┌─ System ─────────────────────────────────────────${R}\n"
printf "  ${D}│${R}  ${WH}Router   ${R}${CY}%-34s${R}\n" "$ROUTER"
printf "  ${D}│${R}  ${WH}Firmware ${R}${D}%-34s${R}\n" "$FW"
printf "  ${D}│${R}  ${WH}Date     ${R}${D}${DATE_NOW}${R}\n"
printf "  ${D}│${R}  ${WH}Uptime   ${R}${GR}${UPTIME}${R}\n"
printf "  ${D}└──────────────────────────────────────────────────${R}\n"
printf "\n"

# Theme
printf "  ${D}┌─ Theme ──────────────────────────────────────────${R}\n"
printf "  ${D}│${R}  ${WH}Name     ${R}${PK}%-34s${R}\n" "$THEME_NAME"
printf "  ${D}│${R}  ${WH}Engine   ${R}${D}%-34s${R}\n" "$THEME_SCRIPT"
printf "  ${D}│${R}  ${WH}Installed${R}${D}%-34s${R}\n" "$INSTALLED_DATE"
printf "  ${D}└──────────────────────────────────────────────────${R}\n"
printf "\n"

# Network
printf "  ${D}┌─ Network ────────────────────────────────────────${R}\n"
printf "  ${D}│${R}  ${WH}LAN IP   ${R}${CY}%-34s${R}\n" "$LAN_IP"
printf "  ${D}│${R}  ${WH}WAN IP   ${R}${CY}%-34s${R}\n" "$WAN_IP"
printf "  ${D}│${R}  ${WH}WAN If   ${R}${D}%-20s${R}  ${WH}Clients ${R}${YL}${CLIENTS}${R}\n" "$WAN_IF"
printf "  ${D}└──────────────────────────────────────────────────${R}\n"
printf "\n"

# Resources
printf "  ${D}┌─ Resources ──────────────────────────────────────${R}\n"
printf "  ${D}│${R}  ${WH}CPU      ${R}${D}${CPU_CORES}x @ ${CPU_MHZ} MHz    ${R}${WH}Load ${R}${YL}${LOAD}${R}\n"
printf "  ${D}│${R}  ${WH}Memory   ${R}${MEM_COLOR}${MEM_BAR}${R} ${MEM_PCT}%%  ${D}(${MEM_USED}/${MEM_TOTAL} kB)${R}\n"
printf "  ${D}└──────────────────────────────────────────────────${R}\n"
printf "\n"

# Footer
printf "  ${D}  http://${LAN_IP}   •   ssh $(nvram get http_username 2>/dev/null)@${LAN_IP}${R}\n"
printf "\n"
