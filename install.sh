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
            # Stop semua service dulu
            pkill -9 nginx 2>/dev/null; kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
            sleep 1
            umount -l /www 2>/dev/null; sleep 1
            rm -rf "$INSTALL_PATH"
            echo -e "${BGREEN}done${NC}" ;;
        *) echo -e "  ${CYAN}→${NC}  Cancelled."; exit 0 ;;
    esac
else
    echo -e "${BGREEN}clean${NC}"
    pkill -9 nginx 2>/dev/null; kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
    sleep 1; umount -l /www 2>/dev/null; sleep 1
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

# login.html — coba dari theme folder dulu, fallback ke root repo
printf "        ${DIM}%-22s${NC} " "login.html"
do_wget "$THEME_BASE_URL/login.html" "$INSTALL_PATH/login.html"
if [ $? -ne 0 ] || [ ! -s "$INSTALL_PATH/login.html" ]; then
    do_wget "$BASE_URL/login.html" "$INSTALL_PATH/login.html" 2>/dev/null
fi
if [ -s "$INSTALL_PATH/login.html" ]; then
    SIZE=$(ls -lh "$INSTALL_PATH/login.html" | awk '{print $5}')
    echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
else
    rm -f "$INSTALL_PATH/login.html" 2>/dev/null; echo -e "${DIM}skipped${NC}"
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

# Simpan credentials
HTTP_USER=$(nvram get http_username)
HTTP_PASS=$(nvram get http_passwd)
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
    [ -f "$INSTALL_PATH/bgmp4.gif" ] && cp "$INSTALL_PATH/bgmp4.gif" "$NGINX_PATH/static/"

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
    proxy_buffer_size     32k;
    proxy_buffers         8 32k;
    proxy_busy_buffers_size 64k;

    map \$http_x_login_auth \$auth_header {
        default       "Basic $B64";
        "~^Basic .+"  \$http_x_login_auth;
    }

    server {
        listen 80;
        root $NGINX_PATH/static;

        # Logout — hapus cookie ft_auth, redirect ke login dengan flag
        location ~* ^/logout {
            add_header Set-Cookie "ft_auth=; Path=/; Max-Age=0; SameSite=Lax" always;
            return 302 /login.html?logout=1;
        }

        # Login page — no-cache agar selalu fresh, tidak pernah redirect
        location = /login.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
            add_header Pragma "no-cache" always;
            try_files \$uri =404;
        }

        # Root — serve login.html
        # JS di login.html cek cookie ft_auth, redirect jika ada
        location = / {
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
            try_files /login.html =404;
        }

        # bgmp4.gif sebagai video
        location = /bgmp4.gif {
            types { video/mp4 gif; }
            try_files \$uri =404;
        }

        # Static files dari nginx/static
        location ~* \.(css|js|png|jpg|jpeg|ico|svg|woff|woff2|html)$ {
            try_files \$uri @proxy;
        }

        # Semua lain → proxy ke httpd
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

    # Start nginx
    nginx -c "$NGINX_PATH/nginx.conf" -t >/dev/null 2>&1 && {
        pkill -9 nginx 2>/dev/null
        kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
        sleep 2
        nginx -c "$NGINX_PATH/nginx.conf"
    }

    # Mount dan restart httpd
    mount --bind "$INSTALL_PATH" /www
    service httpd restart >/dev/null 2>&1

    BOOT_HOOK="# --- Theme Startup ---
sleep 10
[ -d $SAFE_PATH ] || exit 0
mount | grep -q $SAFE_PATH || mount --bind $SAFE_PATH /www
grep -q $SAFE_SCRIPT $SAFE_PATH/tomato.js 2>/dev/null || echo 'document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$SAFE_SCRIPT\";document.head.appendChild(s);});' >> $SAFE_PATH/tomato.js
nvram set http_lanport=8008
service httpd restart
sleep 2
mkdir -p /var/log/nginx /var/lib/nginx/client /var/lib/nginx/proxy
pkill -9 nginx 2>/dev/null
kill -9 \$(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
sleep 2
nginx -c $SAFE_NGINX/nginx.conf
# --- End Theme Startup ---"

    LOGIN_STATUS="${BGREEN}Custom login page (nginx)${NC}"

else
    # Fallback tanpa nginx
    mount --bind "$INSTALL_PATH" /www
    service httpd restart >/dev/null 2>&1

    BOOT_HOOK="# --- Theme Startup ---
sleep 10
[ -d $SAFE_PATH ] || exit 0
mount | grep -q $SAFE_PATH || { mount --bind $SAFE_PATH /www && service httpd restart; }
grep -q $SAFE_SCRIPT $SAFE_PATH/tomato.js 2>/dev/null || echo 'document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$SAFE_SCRIPT\";document.head.appendChild(s);});' >> $SAFE_PATH/tomato.js
# --- End Theme Startup ---"

    LOGIN_STATUS="${YELLOW}Basic Auth (nginx unavailable)${NC}"
fi

# Simpan boot hook
CLEAN=$(nvram get script_init | awk '/# --- Theme Startup ---/{f=1} f{next} {print} /# --- End Theme Startup ---/{f=0}')
if [ -n "$(nvram get script_init)" ]; then
    nvram set script_init="$CLEAN
$BOOT_HOOK"
else
    nvram set script_init="$BOOT_HOOK"
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
