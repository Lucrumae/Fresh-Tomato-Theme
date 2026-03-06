#!/bin/sh

# =================================================================
# FreshTomato Theme Uninstaller
# =================================================================

BASE_DIR="/jffs/Theme"
INSTALL_PATH="/jffs/Theme/www"
NGINX_PATH="/jffs/Theme/nginx"
LAN_IP=$(nvram get lan_ipaddr 2>/dev/null)
[ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"

BGREEN='\033[1;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
WHITE='\033[1;37m'; CYAN='\033[0;36m'; PINK='\033[1;35m'
DIM='\033[2m'; NC='\033[0m'

divider() { echo -e "${DIM}  ────────────────────────────────────────────────${NC}"; }
ok()   { echo -e "  ${BGREEN}✔${NC}  $1"; }
fail() { echo -e "  ${RED}✘${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }

clear
echo ""
echo -e "${PINK}  ████████╗██╗  ██╗███████╗███╗   ███╗███████╗${NC}"
echo -e "${PINK}     ██╔══╝██║  ██║██╔════╝████╗ ████║██╔════╝${NC}"
echo -e "${PINK}     ██║   ███████║█████╗  ██╔████╔██║█████╗  ${NC}"
echo -e "${PINK}     ██║   ██╔══██║██╔══╝  ██║╚██╔╝██║██╔══╝  ${NC}"
echo -e "${PINK}     ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗${NC}"
echo -e "${PINK}     ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝${NC}"
echo ""
echo -e "${WHITE}        FreshTomato Theme Uninstaller${NC}  ${DIM}by Lucrumae${NC}"
divider; echo ""

if [ ! -d "$BASE_DIR" ]; then
    warn "No theme installation found at $BASE_DIR."
    warn "Nothing to uninstall."
    echo ""; exit 0
fi

echo -e "  ${WHITE}This will restore your router to its original state.${NC}"
echo ""
printf "  Proceed with uninstall? (y/n): "; read confirm < /dev/tty; echo ""
case "$confirm" in
    y|Y) ;;
    *) echo -e "  ${CYAN}->  Cancelled.${NC}"; echo ""; exit 0 ;;
esac

echo ""
printf "  Reset credentials to default (root/admin)? (y/n): "; read reset_creds < /dev/tty; echo ""
case "$reset_creds" in
    y|Y) RESET_CREDS=1 ;;
    *)   RESET_CREDS=0 ;;
esac

divider; echo ""

# [1/7] Restore httpd port 80
echo -ne "  ${CYAN}[1/7]${NC}  Restoring httpd to port 80...           "
nvram set http_lanport=80
nvram commit >/dev/null 2>&1
service httpd restart >/dev/null 2>&1
sleep 2
echo -e "${BGREEN}done${NC}"

# [2/7] Stop nginx
echo -ne "  ${CYAN}[2/7]${NC}  Stopping nginx...                       "
kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
pkill -9 nginx 2>/dev/null
sleep 1
for _pid in $(ps | grep nginx | grep -v grep | awk '{print $1}'); do
    kill -9 "$_pid" 2>/dev/null
done
rm -f /tmp/nginx.pid 2>/dev/null
sleep 1
echo -e "${BGREEN}done${NC}"

# [3/7] Unmount /www
echo -ne "  ${CYAN}[3/7]${NC}  Restoring /www mount...                 "
umount -l /www 2>/dev/null
sleep 1
if mount | grep -q "$INSTALL_PATH"; then
    umount -f /www 2>/dev/null
fi
echo -e "${BGREEN}done${NC}"

# [4/7] Remove boot hook dari script_init
echo -ne "  ${CYAN}[4/7]${NC}  Removing boot hook from script_init...  "
CURRENT=$(nvram get script_init 2>/dev/null)
if [ -n "$CURRENT" ]; then
    CLEANED=$(printf '%s\n' "$CURRENT" | awk "
        /^# --- FreshTomato Theme ---\$/ { skip=1; next }
        /^# --- End FreshTomato Theme ---\$/ { skip=0; next }
        /^# --- Theme Startup ---\$/ { skip=1; next }
        /^# --- End Theme Startup ---\$/ { skip=0; next }
        skip { next }
        { print }
    ")
    CLEANED=$(printf '%s' "$CLEANED" | sed '/^[[:space:]]*$/d')
    if [ -n "$CLEANED" ]; then
        nvram set script_init="$CLEANED"
    else
        nvram unset script_init 2>/dev/null || nvram set script_init=""
    fi
    nvram commit >/dev/null 2>&1
fi
echo -e "${BGREEN}done${NC}"

# [5/7] Restore SSH
echo -ne "  ${CYAN}[5/7]${NC}  Restoring SSH configuration...          "
CUSTOM_USER=""
if [ -f "$INSTALL_PATH/.passwd" ]; then
    CUSTOM_USER=$(cut -d: -f1 "$INSTALL_PATH/.passwd" 2>/dev/null)
    [ "$CUSTOM_USER" = "root" ] && CUSTOM_USER=""
fi
if grep -q "^root:.*:/bin/false$" /etc/passwd 2>/dev/null; then
    awk 'BEGIN{FS=OFS=":"} /^root:/{$7="/bin/sh"} {print}' \
        /etc/passwd > /tmp/passwd.tmp && cp /tmp/passwd.tmp /etc/passwd
fi
if [ -n "$CUSTOM_USER" ]; then
    grep -v "^${CUSTOM_USER}:" /etc/passwd > /tmp/passwd.tmp 2>/dev/null && \
        cp /tmp/passwd.tmp /etc/passwd
    grep -v "^${CUSTOM_USER}:" /etc/shadow > /tmp/shadow.tmp 2>/dev/null && \
        cp /tmp/shadow.tmp /etc/shadow
fi
rm -f /tmp/passwd.tmp /tmp/shadow.tmp 2>/dev/null
echo -e "${BGREEN}done${NC}"

# [6/7] Remove theme files
echo -ne "  ${CYAN}[6/7]${NC}  Removing theme files...                 "
rm -rf "$BASE_DIR" 2>/dev/null
rm -f /tmp/ft_reboot_now /tmp/ft_reboot_log 2>/dev/null
rm -f /tmp/nginx.pid /tmp/nginx_error.log 2>/dev/null
echo -e "${BGREEN}done${NC}"

# [7/7] Apply credentials + restart httpd
echo -ne "  ${CYAN}[7/7]${NC}  Applying credentials & restarting...    "
for _pid in $(ps | grep nginx | grep -v grep | awk '{print $1}'); do
    kill -9 "$_pid" 2>/dev/null
done
if [ "$RESET_CREDS" = "1" ]; then
    nvram set http_username="root"
    nvram set http_passwd="admin"
    nvram commit >/dev/null 2>&1
    _H=$(openssl passwd -1 "admin" 2>/dev/null)
    if [ -n "$_H" ]; then
        grep -v "^root:" /etc/shadow > /tmp/shadow.tmp 2>/dev/null || true
        echo "root:${_H}:18000:0:99999:7:::" >> /tmp/shadow.tmp
        cp /tmp/shadow.tmp /etc/shadow
        rm -f /tmp/shadow.tmp
    fi
fi
service httpd restart >/dev/null 2>&1
sleep 1
echo -e "${BGREEN}done${NC}"

# Summary
echo ""; divider; echo ""
echo -e "  ${BGREEN}✔  Uninstall complete!${NC}"; echo ""
echo -e "  ${WHITE}Restored:${NC}"
echo -e "  ${DIM}  • nginx stopped and removed${NC}"
echo -e "  ${DIM}  • /www restored to original${NC}"
echo -e "  ${DIM}  • httpd running on port 80${NC}"
echo -e "  ${DIM}  • boot hook removed from script_init${NC}"
echo -e "  ${DIM}  • root SSH login restored${NC}"
[ -n "$CUSTOM_USER" ] && \
    echo -e "  ${DIM}  • custom SSH user '${CUSTOM_USER}' removed${NC}"
if [ "$RESET_CREDS" = "1" ]; then
    echo -e "  ${DIM}  • credentials reset to ${WHITE}root${DIM} / ${WHITE}admin${NC}"
else
    echo -e "  ${DIM}  • credentials unchanged${NC}"
fi
echo ""
warn "Clear browser cache (Ctrl+F5) to see original router UI."
echo ""
echo -e "  ${DIM}To reinstall the theme, run:${NC}"
echo -e "  ${CYAN}  wget -O - https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/install.sh | sh${NC}"
echo ""; divider; echo ""

if [ "$RESET_CREDS" = "1" ]; then
    echo -e "  ${YELLOW}⚠  SSH Service Restart${NC}"
    divider
    echo -e "  ${DIM}SSH credentials have been reset. Reconnect using:${NC}"
    echo -e "  ${CYAN}  ssh root@${LAN_IP}${NC}"
    echo ""; divider; echo ""
    # Restart sshd di background agar session tidak langsung putus
    ( sleep 3
      killall -9 dropbear 2>/dev/null
      sleep 1
      service sshd start >/dev/null 2>&1
    ) &
fi
