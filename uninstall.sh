#!/bin/sh

# =================================================================
# FreshTomato Theme Uninstaller
# Menghapus semua perubahan dan mengembalikan router ke kondisi awal
# =================================================================

INSTALL_PATH="/jffs/mywww"
NGINX_PATH="/jffs/nginx"
LAN_IP=$(nvram get lan_ipaddr 2>/dev/null)
[ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"

# ANSI Colors
BGREEN='\033[1;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
WHITE='\033[1;37m'; CYAN='\033[0;36m'; PINK='\033[1;35m'
DIM='\033[2m'; NC='\033[0m'

divider() { echo -e "${DIM}  ────────────────────────────────────────────────${NC}"; }
ok()   { echo -e "  ${BGREEN}✔${NC}  $1"; }
fail() { echo -e "  ${RED}✘${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }

# =================================================================
# HEADER
# =================================================================
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

# Cek apakah ada instalasi
if [ ! -d "$INSTALL_PATH" ] && [ ! -d "$NGINX_PATH" ]; then
    warn "No theme installation found."
    warn "Nothing to uninstall."
    echo ""; exit 0
fi

echo -e "  ${WHITE}This will restore your router to its original state:${NC}"
echo ""
echo -e "  ${DIM}  • Stop and remove nginx${NC}"
echo -e "  ${DIM}  • Remove theme files from /jffs${NC}"
echo -e "  ${DIM}  • Restore httpd to port 80${NC}"
echo -e "  ${DIM}  • Restore /www to original${NC}"
echo -e "  ${DIM}  • Remove boot hook from script_init${NC}"
echo -e "  ${DIM}  • Restore root SSH login${NC}"
echo -e "  ${DIM}  • Remove custom SSH user (if any)${NC}"
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

# =================================================================
# STEP 1: RESTORE HTTPD PORT 80 — sebelum nginx distop
# =================================================================
echo -ne "  ${CYAN}[1/7]${NC}  Restoring httpd to port 80...           "
nvram set http_lanport=80
nvram commit >/dev/null 2>&1
service httpd restart >/dev/null 2>&1
sleep 2
echo -e "${BGREEN}done${NC}"

# =================================================================
# STEP 2: STOP NGINX (semua proses termasuk zombie workers)
# =================================================================
echo -ne "  ${CYAN}[2/7]${NC}  Stopping nginx...                       "
# Kill master via PID file
kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
# Kill semua proses nginx by name
pkill -9 nginx 2>/dev/null
sleep 1
# Kill worker zombie yang mungkin masih hidup
for _pid in $(ps | grep nginx | grep -v grep | awk '{print $1}'); do
    kill -9 "$_pid" 2>/dev/null
done
rm -f /tmp/nginx.pid 2>/dev/null
sleep 1
echo -e "${BGREEN}done${NC}"

# =================================================================
# STEP 3: UNMOUNT /www
# =================================================================
echo -ne "  ${CYAN}[3/7]${NC}  Restoring /www mount...                 "
umount -l /www 2>/dev/null
sleep 1
if mount | grep -q "$INSTALL_PATH"; then
    umount -f /www 2>/dev/null
fi
echo -e "${BGREEN}done${NC}"

# =================================================================
# STEP 4: REMOVE BOOT HOOK FROM script_init
# =================================================================
echo -ne "  ${CYAN}[4/7]${NC}  Removing boot hook from script_init...  "
CURRENT=$(nvram get script_init 2>/dev/null)
if [ -n "$CURRENT" ]; then
    # Hapus blok theme (support kedua format marker)
    CLEANED=$(printf '%s\n' "$CURRENT" | awk "
        /^# --- FreshTomato Theme ---\$/ { skip=1; next }
        /^# --- End FreshTomato Theme ---\$/ { skip=0; next }
        /^# --- Theme Startup ---\$/ { skip=1; next }
        /^# --- End Theme Startup ---\$/ { skip=0; next }
        skip { next }
        { print }
    ")
    # Trim blank lines
    CLEANED=$(printf '%s' "$CLEANED" | sed '/^[[:space:]]*$/d')
    if [ -n "$CLEANED" ]; then
        nvram set script_init="$CLEANED"
    else
        nvram unset script_init 2>/dev/null || nvram set script_init=""
    fi
    nvram commit >/dev/null 2>&1
fi
echo -e "${BGREEN}done${NC}"

# =================================================================
# STEP 5: RESTORE SSH
# =================================================================
echo -ne "  ${CYAN}[5/7]${NC}  Restoring SSH configuration...          "

# Baca custom user dari .passwd jika ada
CUSTOM_USER=""
if [ -f "$INSTALL_PATH/.passwd" ]; then
    CUSTOM_USER=$(cut -d: -f1 "$INSTALL_PATH/.passwd" 2>/dev/null)
    [ "$CUSTOM_USER" = "root" ] && CUSTOM_USER=""
fi

# Restore root shell ke /bin/sh (jika sempat diset /bin/false)
if grep -q "^root:.*:/bin/false$" /etc/passwd 2>/dev/null; then
    awk 'BEGIN{FS=OFS=":"} /^root:/{$7="/bin/sh"} {print}' \
        /etc/passwd > /tmp/passwd.tmp && cp /tmp/passwd.tmp /etc/passwd
fi

# Hapus custom SSH user jika ada
if [ -n "$CUSTOM_USER" ]; then
    grep -v "^${CUSTOM_USER}:" /etc/passwd > /tmp/passwd.tmp 2>/dev/null && \
        cp /tmp/passwd.tmp /etc/passwd
    grep -v "^${CUSTOM_USER}:" /etc/shadow > /tmp/shadow.tmp 2>/dev/null && \
        cp /tmp/shadow.tmp /etc/shadow
fi

# Cleanup tmp files
rm -f /tmp/passwd.tmp /tmp/shadow.tmp 2>/dev/null

echo -e "${BGREEN}done${NC}"

# =================================================================
# STEP 6: REMOVE THEME FILES
# =================================================================
echo -ne "  ${CYAN}[6/7]${NC}  Removing theme files...                 "
rm -rf "$INSTALL_PATH" 2>/dev/null
rm -rf "$NGINX_PATH" 2>/dev/null
rm -f /tmp/ft_reboot_now /tmp/ft_reboot_log 2>/dev/null
rm -f /tmp/nginx.pid /tmp/nginx_error.log 2>/dev/null
echo -e "${BGREEN}done${NC}"

# =================================================================
# STEP 7: APPLY CREDENTIALS + RESTART HTTPD
# =================================================================
echo -ne "  ${CYAN}[7/7]${NC}  Applying credentials & restarting httpd...  "
# Pastikan tidak ada sisa nginx yang masih jalan
for _pid in $(ps | grep nginx | grep -v grep | awk '{print $1}'); do
    kill -9 "$_pid" 2>/dev/null
done
if [ "$RESET_CREDS" = "1" ]; then
    nvram set http_username="root"
    nvram set http_passwd="admin"
    nvram commit >/dev/null 2>&1
    # Update /etc/shadow untuk SSH
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

# =================================================================
# SUMMARY
# =================================================================
echo ""
divider; echo ""
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

# =================================================================
# SSHD RESTART — hanya jika credentials di-reset, di paling akhir
# =================================================================
if [ "$RESET_CREDS" = "1" ]; then
    echo -e "  ${YELLOW}⚠  SSH Service Restart${NC}"
    divider
    echo -e "  ${DIM}SSH credentials have been reset. The SSH daemon${NC}"
    echo -e "  ${DIM}must restart — your current session will disconnect.${NC}"
    echo ""
    echo -e "  ${WHITE}Reconnect using:${NC}"
    echo -e "  ${CYAN}  ssh root@${LAN_IP}${NC}"
    echo ""; divider; echo ""
    sleep 3
    service sshd restart >/dev/null 2>&1
fi
