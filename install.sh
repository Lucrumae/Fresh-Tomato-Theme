#!/bin/sh

# =================================================================
# GLOBAL CONFIGURATION
# =================================================================
BASE_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main"
THEME_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/Theme"
LIST_FILE="ThemeList.txt"
INSTALL_PATH="/jffs/mywww"
NGINX_PATH="/jffs/nginx"
TEMP_WORKSPACE="/tmp/theme_deploy"
THEME_FILES="default.css logol.png logor.png bgmp4.gif"

# ANSI Colors
CYAN='\033[0;36m'; BGREEN='\033[1;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; PINK='\033[1;35m'; WHITE='\033[1;37m'
DIM='\033[2m'; NC='\033[0m'

cleanup() { [ -d "$TEMP_WORKSPACE" ] && rm -rf "$TEMP_WORKSPACE"; }
trap cleanup EXIT INT TERM

divider() { echo -e "${DIM}  ────────────────────────────────────────────────${NC}"; }
ok()   { echo -e "  ${BGREEN}✔${NC}  $1"; }
fail() { echo -e "  ${RED}✘${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
do_wget() { wget --no-check-certificate -T 15 "$1" -O "$2" 2>/dev/null; }

# =================================================================
# PHASE 1: THEME SELECTION
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
echo -e "${WHITE}        FreshTomato Theme Installer${NC}  ${DIM}by Lucrumae${NC}"
divider; echo ""

mkdir -p "$TEMP_WORKSPACE"
echo -ne "  ${CYAN}↓${NC}  Fetching theme catalog... "
do_wget "$BASE_URL/$LIST_FILE" "$TEMP_WORKSPACE/list.txt"
[ ! -s "$TEMP_WORKSPACE/list.txt" ] && echo -e "${RED}failed${NC}" && fail "Cannot reach GitHub." && exit 1
echo -e "${BGREEN}done${NC}"; echo ""

echo -e "  ${WHITE}Available Themes${NC}"; divider
i=1
while IFS='|' read -r name folder || [ -n "$name" ]; do
    n=$(echo "$name" | tr -d '\r\n'); f=$(echo "$folder" | tr -d '\r\n')
    [ -z "$n" ] && continue
    echo -e "  ${PINK}$i)${NC}  $n  ${DIM}← $f${NC}"
    echo "$n" >> "$TEMP_WORKSPACE/names.txt"
    echo "$f" >> "$TEMP_WORKSPACE/folders.txt"
    i=$((i+1))
done < "$TEMP_WORKSPACE/list.txt"
total=$((i-1))
[ "$total" -eq 0 ] && fail "No themes found." && exit 1

divider; echo ""
printf "  Select a theme (1-$total): "
read choice < /dev/tty
case "$choice" in ''|*[!0-9]*) fail "Invalid input."; exit 1 ;; esac
[ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ] && fail "Out of range." && exit 1

SELECTED_NAME=$(sed -n "${choice}p" "$TEMP_WORKSPACE/names.txt")
SELECTED_FOLDER=$(sed -n "${choice}p" "$TEMP_WORKSPACE/folders.txt")
THEME_BASE_URL="$THEME_URL/$SELECTED_FOLDER"

# =================================================================
# PHASE 2: SYSTEM CHECKS
# =================================================================
echo ""; echo -e "  ${WHITE}System Checks${NC}"; divider
! mount | grep -q "/jffs" && fail "JFFS not mounted." && exit 1
ok "JFFS partition active"
FREE=$(df -k /jffs | awk 'NR==2{print $4}')
[ "$FREE" -lt 10240 ] && warn "Low JFFS space (${FREE}KB)" || ok "JFFS space OK (${FREE}KB free)"

HAS_NGINX=0
which nginx > /dev/null 2>&1 && {
    ok "nginx available ($(nginx -v 2>&1 | cut -d/ -f2))"
    HAS_NGINX=1
} || warn "nginx not found — Basic Auth fallback"

# Deteksi LAN IP router
LAN_IP=$(nvram get lan_ipaddr 2>/dev/null)
[ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"
ok "Router LAN IP: $LAN_IP"

echo ""; echo -e "  ${WHITE}Installing:${NC} ${PINK}$SELECTED_NAME${NC}"; divider

# =================================================================
# PHASE 3: PREPARATION
# =================================================================
echo -ne "  ${CYAN}[1/5]${NC}  Checking previous installation...       "
if [ -d "$INSTALL_PATH" ] && [ "$(ls -A $INSTALL_PATH 2>/dev/null)" ]; then
    echo -e "${YELLOW}found${NC}"; echo ""
    warn "Previous installation at ${DIM}$INSTALL_PATH${NC}"; echo ""
    printf "  Overwrite? (y/n): "; read confirm < /dev/tty; echo ""
    case "$confirm" in
        y|Y)
            echo -ne "  ${CYAN}[1/5]${NC}  Removing previous...                    "
            # Stop semua nginx dulu
            pkill -9 nginx 2>/dev/null
            kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
            rm -f /tmp/nginx.pid 2>/dev/null
            sleep 1
            umount -l /www 2>/dev/null; sleep 1
            # Hapus keduanya: install path dan nginx config
            rm -rf "$INSTALL_PATH"
            rm -rf "$NGINX_PATH"
            echo -e "${BGREEN}done${NC}" ;;
        *) echo -e "  ${CYAN}→${NC}  Cancelled."; exit 0 ;;
    esac
else
    echo -e "${BGREEN}clean${NC}"
    # Jika nginx folder ada dari install sebelumnya, hapus juga
    pkill -9 nginx 2>/dev/null
    kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
    rm -f /tmp/nginx.pid 2>/dev/null
    sleep 1
    umount -l /www 2>/dev/null; sleep 1
    [ -d "$NGINX_PATH" ] && rm -rf "$NGINX_PATH"
fi

echo -ne "  ${CYAN}[2/5]${NC}  Mirroring /www to JFFS...               "
mkdir -p "$INSTALL_PATH"
cp -a /www/. "$INSTALL_PATH/"
rm -f "$INSTALL_PATH/default.css"
echo -e "${BGREEN}done${NC}"

# =================================================================
# PHASE 4: DOWNLOAD
# =================================================================
failed_files=""
echo -e "  ${CYAN}[3/5]${NC}  Downloading theme files..."; echo ""

VIDEO_SCRIPT="bg-video.js"
for TRY_SCRIPT in adaptiverealtime.js adaptive.js; do
    printf "        ${DIM}%-22s${NC} " "$TRY_SCRIPT"
    do_wget "$THEME_BASE_URL/$TRY_SCRIPT" "$INSTALL_PATH/$TRY_SCRIPT"
    if [ $? -eq 0 ] && [ -s "$INSTALL_PATH/$TRY_SCRIPT" ]; then
        SIZE=$(ls -lh "$INSTALL_PATH/$TRY_SCRIPT" | awk '{print $5}')
        echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
        VIDEO_SCRIPT="$TRY_SCRIPT"; break
    else
        rm -f "$INSTALL_PATH/$TRY_SCRIPT" 2>/dev/null
        echo -e "${DIM}skipped${NC}"
    fi
done

if [ "$VIDEO_SCRIPT" = "bg-video.js" ]; then
    printf "        ${DIM}%-22s${NC} " "bg-video.js"
    do_wget "$BASE_URL/bg-video.js" "$INSTALL_PATH/bg-video.js"
    if [ $? -ne 0 ] || [ ! -s "$INSTALL_PATH/bg-video.js" ]; then
        echo -e "${RED}failed${NC}"; fail "Cannot download bg-video.js."; exit 1
    fi
    SIZE=$(ls -lh "$INSTALL_PATH/bg-video.js" | awk '{print $5}')
    echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
fi

for FILE in $THEME_FILES; do
    printf "        ${DIM}%-22s${NC} " "$FILE"
    do_wget "$THEME_BASE_URL/$FILE" "$INSTALL_PATH/$FILE"
    if [ $? -ne 0 ] || [ ! -s "$INSTALL_PATH/$FILE" ]; then
        case "$FILE" in logol.png|logor.png|bgmp4.gif) echo -e "${DIM}skipped${NC} ${DIM}(optional)${NC}" ;;
            *) echo -e "${RED}failed${NC}"; failed_files="$failed_files $FILE" ;; esac
    else
        SIZE=$(ls -lh "$INSTALL_PATH/$FILE" | awk '{print $5}')
        echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
    fi
done

# login.html — pull dari GitHub
printf "        ${DIM}%-22s${NC} " "login.html"
mkdir -p "$NGINX_PATH/static"
do_wget "$BASE_URL/login.html" "$INSTALL_PATH/login.html"
if [ $? -ne 0 ] || [ ! -s "$INSTALL_PATH/login.html" ]; then
    echo -e "${RED}failed${NC}"
    fail "Cannot download login.html from GitHub."
    exit 1
fi
cp "$INSTALL_PATH/login.html" "$NGINX_PATH/static/login.html"
SIZE=$(ls -lh "$INSTALL_PATH/login.html" | awk '{print $5}')
echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"

# reboot-wait.html — custom reboot waiting page dengan video background
printf "        ${DIM}%-22s${NC} " "reboot-wait.html"
do_wget "$BASE_URL/reboot-wait.html" "$INSTALL_PATH/reboot-wait.html"
if [ $? -eq 0 ] && [ -s "$INSTALL_PATH/reboot-wait.html" ]; then
    SIZE=$(ls -lh "$INSTALL_PATH/reboot-wait.html" | awk '{print $5}')
    echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
else
    echo -e "${RED}failed${NC}"; fail "Cannot download reboot-wait.html."; exit 1
fi

# reboot-daemon.sh — telnetd handler: eksekusi reboot saat ada koneksi di port 8009
printf "        ${DIM}%-22s${NC} " "reboot-daemon.sh"
do_wget "$BASE_URL/reboot-daemon.sh" "$INSTALL_PATH/reboot-daemon.sh"
if [ $? -eq 0 ] && [ -s "$INSTALL_PATH/reboot-daemon.sh" ]; then
    chmod 755 "$INSTALL_PATH/reboot-daemon.sh"
    SIZE=$(ls -lh "$INSTALL_PATH/reboot-daemon.sh" | awk '{print $5}')
    echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
else
    echo -e "${RED}failed${NC}"; fail "Cannot download reboot-daemon.sh."; exit 1
fi
echo ""

[ -n "$failed_files" ] && fail "Required files failed:$failed_files" && exit 1

# =================================================================
# PHASE 5: PERMISSIONS
# =================================================================
echo -ne "  ${CYAN}[4/5]${NC}  Setting permissions...                  "
chmod 755 "$INSTALL_PATH"
chmod 644 "$INSTALL_PATH"/* 2>/dev/null
chmod 755 "$INSTALL_PATH"/*.cgi 2>/dev/null
echo -e "${BGREEN}done${NC}"

# =================================================================
# PHASE 6: LOGIN PAGE + NGINX + BOOT HOOK
# =================================================================
echo -ne "  ${CYAN}[5/5]${NC}  Configuring login & boot hooks...       "

# Inject video script ke tomato.js
if [ -f "$INSTALL_PATH/tomato.js" ] && ! grep -q "$VIDEO_SCRIPT" "$INSTALL_PATH/tomato.js"; then
    echo "document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$VIDEO_SCRIPT\";document.head.appendChild(s);});" >> "$INSTALL_PATH/tomato.js"
fi

SAFE_PATH=$(echo "$INSTALL_PATH" | tr -cd 'a-zA-Z0-9/_-')
SAFE_SCRIPT=$(echo "$VIDEO_SCRIPT" | tr -cd 'a-zA-Z0-9/_.-')
SAFE_NGINX=$(echo "$NGINX_PATH" | tr -cd 'a-zA-Z0-9/_-')

# Kredensial — tanya user mau pakai yang sekarang atau custom
HTTP_USER=$(nvram get http_username)
HTTP_PASS=$(nvram get http_passwd)

echo ""
echo ""
echo -e "  ${WHITE}Login Credentials${NC}"
divider
echo -e "  ${DIM}Configure credentials for the web login page, SSH, and router admin.${NC}"
echo -e "  ${DIM}All three will be kept in sync automatically.${NC}"
echo ""
echo -e "  Detected credentials  ${DIM}→${NC}  ${WHITE}${HTTP_USER}${NC} / ${DIM}${HTTP_PASS}${NC}"
echo ""
printf "  Keep current credentials? [y/n]: "; read use_current < /dev/tty; echo ""

case "$use_current" in
    n|N)
        echo -e "  ${CYAN}Set new credentials${NC}"
        divider
        echo -e "  ${DIM}Changes will apply to: web login, SSH, and router admin.${NC}"
        echo -e "  ${DIM}If a new username is set, it will be added as a root-equivalent${NC}"
        echo -e "  ${DIM}system user (UID 0) and enabled for SSH access. The original${NC}"
        echo -e "  ${DIM}'root' account will be disabled for SSH login but kept intact${NC}"
        echo -e "  ${DIM}for system stability.${NC}"
        echo ""

        printf "  Username ${DIM}[leave blank to keep '${HTTP_USER}']${NC}: "
        read new_user < /dev/tty
        [ -z "$new_user" ] && new_user="$HTTP_USER"

        printf "  Password ${DIM}[leave blank to keep current]${NC}: "
        read new_pass < /dev/tty; echo ""

        if [ -z "$new_pass" ]; then
            warn "No password entered — keeping current password."
            new_pass="$HTTP_PASS"
        fi

        HTTP_USER="$new_user"
        HTTP_PASS="$new_pass"

        # Update web admin credentials
        nvram set http_username="$HTTP_USER"
        nvram set http_passwd="$HTTP_PASS"
        nvram commit >/dev/null 2>&1

        # Update SSH + system credentials
        # ── Fungsi apply SSH credentials ──────────────────────────
        # Fungsi generate password hash tanpa passwd command
        make_hash() {
            local pass="$1"
            local hash=""
            # Coba openssl dulu
            hash=$(openssl passwd -1 "$pass" 2>/dev/null)
            # Fallback ke MD5 via busybox
            [ -z "$hash" ] && hash=$(echo "$pass" | md5sum 2>/dev/null | awk "{print \$1}")
            echo "$hash"
        }

        # Fungsi update /etc/shadow langsung (tidak butuh passwd command)
        set_shadow_pass() {
            local uname="$1"
            local upass="$2"
            local hash
            hash=$(make_hash "$upass")
            [ -z "$hash" ] && return 1
            # Hapus entry lama, tulis baru
            grep -v "^${uname}:" /etc/shadow > /tmp/shadow.tmp 2>/dev/null || true
            echo "${uname}:${hash}:18000:0:99999:7:::" >> /tmp/shadow.tmp
            cp /tmp/shadow.tmp /etc/shadow
        }

        setup_ssh_user() {
            local uname="$1"
            local upass="$2"

            # Tandai untuk restart SSH di akhir script (agar koneksi tidak putus)
            nvram set sshd_enable=1
            nvram set sshd_pass=1
            SSHD_NEEDS_RESTART=1

            # Update password root di shadow
            set_shadow_pass "root" "$upass"

            if [ "$uname" = "root" ]; then
                # Pastikan root shell kembali ke /bin/sh
                awk 'BEGIN{FS=OFS=":"} /^root:/{$7="/bin/sh"} {print}'                     /etc/passwd > /tmp/passwd.tmp && cp /tmp/passwd.tmp /etc/passwd
                ok "SSH password updated for '${WHITE}root${NC}'"
                SSH_CUSTOM_USER=""
                return
            fi

            # Cek writable
            if ! touch /etc/passwd 2>/dev/null; then
                warn "/etc/passwd is read-only — SSH custom user cannot be created."
                warn "Web login will use '${uname}', SSH falls back to 'root'."
                SSH_CUSTOM_USER=""
                return
            fi

            # Hapus entry lama
            grep -v "^${uname}:" /etc/passwd > /tmp/passwd.tmp && cp /tmp/passwd.tmp /etc/passwd

            # Tambah user custom UID 0
            echo "${uname}:x:0:0::/root:/bin/sh" >> /etc/passwd

            # Set password di shadow
            set_shadow_pass "$uname" "$upass"

            # Block root SSH: ganti shell ke /bin/false
            awk 'BEGIN{FS=OFS=":"} /^root:/{$7="/bin/false"} {print}'                 /etc/passwd > /tmp/passwd.tmp && cp /tmp/passwd.tmp /etc/passwd

            ok "SSH user '${WHITE}${uname}${NC}' created → UID 0 (runs as root)"
            ok "SSH login for 'root' blocked → shell set to /bin/false"
            SSH_CUSTOM_USER="$uname"
        }

        setup_ssh_user "$HTTP_USER" "$HTTP_PASS"

        echo ""
        ok "Credentials applied  →  ${WHITE}${HTTP_USER}${NC} / ${DIM}${HTTP_PASS}${NC}"
        echo -e "  ${DIM}  Web login ✔   SSH ✔   Router admin ✔${NC}"
        ;;
    *)
        # Keep current — sync password SSH root
        printf "%s\n%s\n" "$HTTP_PASS" "$HTTP_PASS" | passwd root >/dev/null 2>&1
        SSH_CUSTOM_USER=""
        ok "Keeping current credentials  →  ${WHITE}${HTTP_USER}${NC}"
        echo -e "  ${DIM}  SSH password synced with current credentials.${NC}"
        ;;
esac

SSH_CUSTOM_USER="${SSH_CUSTOM_USER:-}"

echo ""

echo "${HTTP_USER}:${HTTP_PASS}" > "$INSTALL_PATH/.passwd"
chmod 600 "$INSTALL_PATH/.passwd"

# Buat auth.cgi
cat > "$INSTALL_PATH/auth.cgi" << 'AUTHEOF'
#!/bin/sh
printf "Content-Type: text/plain\r\n\r\n"
POST=$(cat)
USER=$(echo "$POST" | sed 's/&/\n/g' | grep '^user=' | cut -d= -f2-)
PASS=$(echo "$POST" | sed 's/&/\n/g' | grep '^pass=' | cut -d= -f2-)
CRED=$(cat /jffs/mywww/.passwd 2>/dev/null || cat /www/.passwd 2>/dev/null)
STORED_U="${CRED%%:*}"
STORED_P="${CRED#*:}"
if [ -n "$USER" ] && [ "$USER" = "$STORED_U" ] && [ "$PASS" = "$STORED_P" ]; then
    TOKEN=$(date +%s)$$
    printf "OK:%s" "$TOKEN"
else
    printf "FAIL"
fi
AUTHEOF
chmod 755 "$INSTALL_PATH/auth.cgi"

# Buat index.html
cat > "$INSTALL_PATH/index.html" << 'IDXEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8">
<meta http-equiv="refresh" content="0;url=/login.html">
<script>window.location.replace('/login.html');</script>
</head><body></body></html>
IDXEOF

# ── NGINX SETUP ───────────────────────────────────────────────────
if [ "$HAS_NGINX" -eq 1 ] && [ -s "$INSTALL_PATH/login.html" ]; then
    B64=$(echo -n "${HTTP_USER}:${HTTP_PASS}" | openssl base64 | tr -d '\n')

    # Pindahkan httpd ke port 8008
    nvram set http_lanport=8008
    nvram commit >/dev/null 2>&1
    service httpd restart >/dev/null 2>&1
    sleep 2

    # Buat dirs
    mkdir -p "$NGINX_PATH/static"
    mkdir -p /var/log/nginx /var/lib/nginx/client /var/lib/nginx/proxy

    # Salin static files ke nginx/static (TANPA .asp)
    cp "$INSTALL_PATH"/*.css  "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH"/*.js   "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH"/*.png  "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH"/*.ico  "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH/login.html" "$NGINX_PATH/static/"
    [ -f "$INSTALL_PATH/bgmp4.gif" ]      && cp "$INSTALL_PATH/bgmp4.gif"      "$NGINX_PATH/static/"
    [ -f "$INSTALL_PATH/reboot-wait.html" ] && cp "$INSTALL_PATH/reboot-wait.html" "$NGINX_PATH/static/"

    # mime.types
    cat > "$NGINX_PATH/mime.types" << 'MIMEEOF'
types {
    text/html                 html htm;
    text/css                  css;
    text/plain                txt;
    application/javascript    js;
    application/json          json;
    image/png                 png;
    image/jpeg                jpg jpeg;
    image/x-icon              ico;
    image/svg+xml             svg;
    image/gif                 gif;
    font/woff                 woff;
    font/woff2                woff2;
}
MIMEEOF

    # nginx.conf — pakai cookie ft_auth untuk cek session
    cat > "$NGINX_PATH/nginx.conf" << NGINXEOF
user nobody;
worker_processes 1;
pid /tmp/nginx.pid;
error_log /tmp/nginx_error.log;

events { worker_connections 128; }

http {
    access_log off;
    include $NGINX_PATH/mime.types;

    proxy_connect_timeout 10s;
    proxy_send_timeout    60s;
    proxy_read_timeout    60s;
    proxy_buffer_size     128k;
    proxy_buffers         8 128k;
    proxy_busy_buffers_size 256k;

    map \$http_x_login_auth \$auth_header {
        default       "Basic $B64";
        "~^Basic .+"  \$http_x_login_auth;
    }

    server {
        listen 80;
        root $NGINX_PATH/static;

        # Logout
        location ~* logout {
            add_header Set-Cookie "ft_auth=; Path=/; Max-Age=0; SameSite=Lax" always;
            return 302 /login.html?logout=1;
        }

        # Login page
        location = /login.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
            add_header Pragma "no-cache" always;
            try_files \$uri =404;
        }

        # Root "/" — cek cookie, proxy atau login
        location = / {
            set \$do_login "1";
            if (\$cookie_ft_auth) { set \$do_login "0"; }
            if (\$do_login = "1") { rewrite ^ /login.html last; }
            proxy_pass http://$LAN_IP:8008;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_buffering on;
        }

        # bgmp4.gif sebagai video
        location = /bgmp4.gif {
            types { video/mp4 gif; }
            try_files \$uri =404;
        }

        # Static files
        location ~* \.(css|js|png|jpg|jpeg|ico|svg|woff|woff2|html)$ {
            try_files \$uri @proxy;
        }

        # Semua lain → proxy
        location / {
            proxy_pass http://$LAN_IP:8008;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_buffering on;
        }

        location @proxy {
            proxy_pass http://$LAN_IP:8008;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_buffering on;
        }
    }
}
NGINXEOF

    # Jalankan reboot-daemon via telnetd di port 8009
    pkill -f "telnetd.*8009" 2>/dev/null
    fuser -k 8009/tcp 2>/dev/null
    sleep 1
    telnetd -p 8009 -l "$INSTALL_PATH/reboot-daemon.sh" -K -F &

    # Bebaskan port 80 — kill semua yang pakai port 80
    PORT80_PID=$(netstat -tlnp 2>/dev/null | grep ':80 ' | awk '{print $7}' | cut -d/ -f1 | head -1)
    if [ -n "$PORT80_PID" ]; then
        kill -9 "$PORT80_PID" 2>/dev/null
        sleep 1
    fi
    # Kill semua nginx instance
    pkill -9 nginx 2>/dev/null
    kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
    rm -f /tmp/nginx.pid 2>/dev/null
    sleep 2

    # Start nginx
    nginx -c "$NGINX_PATH/nginx.conf" -t >/dev/null 2>&1 && nginx -c "$NGINX_PATH/nginx.conf"
    sleep 1

    # Verifikasi nginx jalan di port 80
    if ! netstat -tlnp 2>/dev/null | grep -q ':80 '; then
        # Retry sekali lagi
        sleep 2; nginx -c "$NGINX_PATH/nginx.conf"
    fi

    # Mount dan restart httpd
    mount --bind "$INSTALL_PATH" /www
    service httpd restart >/dev/null 2>&1

    # Tulis boot script sebagai file (menghindari masalah quoting di NVRAM)
    cat > "$NGINX_PATH/boot.sh" << 'BOOTEOF'
#!/bin/sh
SAFE_PATH=/jffs/mywww
SAFE_NGINX=/jffs/nginx
BOOTEOF

    # Append bagian yang butuh variable expansion
    cat >> "$NGINX_PATH/boot.sh" << BOOTEOF2
SAFE_SCRIPT=$SAFE_SCRIPT
BOOTEOF2

    cat >> "$NGINX_PATH/boot.sh" << 'BOOTEOF3'
# =================================================================
# BOOT RESTORE — dijalankan setiap router restart via script_init
# Semua perubahan di /etc, /www bersifat tmpfs — hilang setiap reboot
# File permanen tersimpan di /jffs dan di-restore di sini
# =================================================================

# 1. MOUNT: bind /jffs/mywww → /www agar theme aktif
[ -d "$SAFE_PATH" ] || exit 0
mount | grep -q "$SAFE_PATH" || mount --bind "$SAFE_PATH" /www

# 2. THEME SCRIPT: pastikan video/adaptive script ter-inject ke tomato.js
if [ -f "$SAFE_PATH/tomato.js" ] && [ -n "$SAFE_SCRIPT" ]; then
    grep -q "$SAFE_SCRIPT" "$SAFE_PATH/tomato.js" 2>/dev/null || \
        printf 'document.addEventListener("DOMContentLoaded",function(){var s=document.createElement("script");s.src="/%s";document.head.appendChild(s);});\n' \
        "$SAFE_SCRIPT" >> "$SAFE_PATH/tomato.js"
fi

# 3. HTTPD: jalankan di port 8008, nginx yang handle port 80
nvram set http_lanport=8008
service httpd restart
sleep 2

# Jalankan reboot-daemon via telnetd di port 8009
pkill -f "telnetd.*8009" 2>/dev/null
fuser -k 8009/tcp 2>/dev/null
sleep 1
telnetd -p 8009 -l "$SAFE_PATH/reboot-daemon.sh" -K -F &

# 4. NGINX: start ulang dengan config dari JFFS
mkdir -p /var/log/nginx /var/lib/nginx/client /var/lib/nginx/proxy
PORT80_PID=$(netstat -tlnp 2>/dev/null | grep ':80 ' | awk '{print $7}' | cut -d/ -f1 | head -1)
[ -n "$PORT80_PID" ] && kill -9 "$PORT80_PID" 2>/dev/null && sleep 1
pkill -9 nginx 2>/dev/null
kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
rm -f /tmp/nginx.pid 2>/dev/null
sleep 2
nginx -c "$SAFE_NGINX/nginx.conf"

# 5. STATIC FILES: pastikan tersedia di nginx/static
[ -f "$SAFE_PATH/login.html" ] && \
    cp "$SAFE_PATH/login.html" "$SAFE_NGINX/static/login.html" 2>/dev/null
[ -f "$SAFE_PATH/reboot-wait.html" ] && \
    cp "$SAFE_PATH/reboot-wait.html" "$SAFE_NGINX/static/reboot-wait.html" 2>/dev/null

# 6. SSH CREDENTIALS: /etc/passwd + /etc/shadow di-reset tiap boot dari tmpfs
#    restore dari .passwd yang tersimpan permanen di /jffs/mywww
_F="$SAFE_PATH/.passwd"
_U=$(cut -d: -f1 "$_F" 2>/dev/null)
_P=$(cut -d: -f2- "$_F" 2>/dev/null)

if [ -n "$_P" ]; then
    _H=$(openssl passwd -1 "$_P" 2>/dev/null)
    if [ -n "$_H" ]; then
        # Restore password root
        grep -v "^root:" /etc/shadow > /tmp/shadow.tmp 2>/dev/null || true
        echo "root:${_H}:18000:0:99999:7:::" >> /tmp/shadow.tmp
        cp /tmp/shadow.tmp /etc/shadow

        if [ -n "$_U" ] && [ "$_U" != "root" ]; then
            # Re-create custom user UID 0 di /etc/passwd
            grep -v "^${_U}:" /etc/passwd > /tmp/passwd.tmp 2>/dev/null || cp /etc/passwd /tmp/passwd.tmp
            echo "${_U}:x:0:0::/root:/bin/sh" >> /tmp/passwd.tmp
            cp /tmp/passwd.tmp /etc/passwd

            # Set password custom user di shadow
            grep -v "^${_U}:" /etc/shadow > /tmp/shadow.tmp 2>/dev/null || true
            echo "${_U}:${_H}:18000:0:99999:7:::" >> /tmp/shadow.tmp
            cp /tmp/shadow.tmp /etc/shadow

            # Block root SSH: shell → /bin/false
            awk 'BEGIN{FS=OFS=":"} /^root:/{$7="/bin/false"} {print}' \
                /etc/passwd > /tmp/passwd.tmp && cp /tmp/passwd.tmp /etc/passwd
        fi
    fi
fi

# 7. SSH SERVICE: enable + restart agar semua credential di atas aktif
nvram set sshd_enable=1
nvram set sshd_pass=1
service sshd restart >/dev/null 2>&1
BOOTEOF3
    chmod 755 "$NGINX_PATH/boot.sh"

    LOGIN_STATUS="${BGREEN}Custom login page (nginx)${NC}"

else
    # Fallback tanpa nginx — buat boot.sh minimal
    mkdir -p "$NGINX_PATH"
    cat > "$NGINX_PATH/boot.sh" << FALLBACKEOF
#!/bin/sh
SAFE_PATH=$SAFE_PATH
SAFE_SCRIPT=$SAFE_SCRIPT
[ -d "\$SAFE_PATH" ] || exit 0
mount | grep -q "\$SAFE_PATH" || { mount --bind "\$SAFE_PATH" /www && service httpd restart; }
grep -q "\$SAFE_SCRIPT" "\$SAFE_PATH/tomato.js" 2>/dev/null || \
    printf 'document.addEventListener("DOMContentLoaded",function(){var s=document.createElement("script");s.src="/%s";document.head.appendChild(s);});\n' \
    "\$SAFE_SCRIPT" >> "\$SAFE_PATH/tomato.js"
FALLBACKEOF
    chmod 755 "$NGINX_PATH/boot.sh"

    mount --bind "$INSTALL_PATH" /www
    service httpd restart >/dev/null 2>&1

    LOGIN_STATUS="${YELLOW}Basic Auth (nginx unavailable)${NC}"
fi

# =================================================================
# INJECT KE script_init — hanya satu baris, semua logic di boot.sh
# Preserve semua konfigurasi custom user yang sudah ada di init
# =================================================================
BOOT_ENTRY="sh $SAFE_NGINX/boot.sh"
MARKER_START="# --- FreshTomato Theme ---"
MARKER_END="# --- End FreshTomato Theme ---"
BOOT_BLOCK="$MARKER_START
sleep 10
$BOOT_ENTRY
$MARKER_END"

# Ambil script_init yang ada, hapus blok theme lama (jika ada), preserve sisanya
CURRENT=$(nvram get script_init 2>/dev/null)

# Strip blok theme lama — antara marker (termasuk marker-nya)
STRIPPED=$(printf '%s
' "$CURRENT" | awk "
    /^# --- FreshTomato Theme ---\$/ { skip=1; next }
    /^# --- End FreshTomato Theme ---\$/ { skip=0; next }
    /^# --- Theme Startup ---\$/ { skip=1; next }
    /^# --- End Theme Startup ---\$/ { skip=0; next }
    skip { next }
    { print }
")

# Trim trailing blank lines dari STRIPPED
STRIPPED=$(printf '%s' "$STRIPPED" | sed '/^[[:space:]]*$/d')

# Gabungkan: konfigurasi user (jika ada) + blok theme baru
if [ -n "$STRIPPED" ]; then
    nvram set script_init="$STRIPPED

$BOOT_BLOCK"
else
    nvram set script_init="$BOOT_BLOCK"
fi
nvram commit >/dev/null 2>&1

echo -e "${BGREEN}done${NC}"

# =================================================================
# DONE
# =================================================================
echo ""; divider; echo ""
echo -e "  ${BGREEN}✔  Installation complete!${NC}"; echo ""
echo -e "  ${WHITE}Theme   ${NC}${PINK}$SELECTED_NAME${NC}"
echo -e "  ${WHITE}Path    ${NC}${DIM}$INSTALL_PATH${NC}"
echo -e "  ${WHITE}Script  ${NC}${DIM}$VIDEO_SCRIPT${NC}"
echo -e "  ${WHITE}Login   ${NC}$LOGIN_STATUS"
echo -e "  ${WHITE}Status  ${NC}${BGREEN}Active & persistent${NC}"
echo ""
echo -e "  ${YELLOW}⚑  Press Ctrl+F5 to clear browser cache.${NC}"
echo ""; divider; echo ""

if [ "${SSHD_NEEDS_RESTART:-0}" = "1" ]; then
    echo -e "  ${YELLOW}⚠  SSH Service Restart${NC}"
    divider
    echo -e "  ${DIM}New SSH credentials have been applied. The SSH daemon${NC}"
    echo -e "  ${DIM}must restart to apply changes — your current session${NC}"
    echo -e "  ${DIM}will be disconnected in 3 seconds.${NC}"
    echo ""
    echo -e "  ${WHITE}Reconnect using:${NC}"
    echo -e "  ${CYAN}  ssh ${HTTP_USER}@${LAN_IP}${NC}"
    echo ""; divider; echo ""
    sleep 3
    nvram commit >/dev/null 2>&1
    service sshd restart >/dev/null 2>&1
fi
