#!/bin/sh

# =================================================================
# GLOBAL CONFIGURATION
# =================================================================
BASE_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main"
LIST_FILE="ThemeList.txt"
INSTALL_PATH="/jffs/mywww"
NGINX_PATH="/jffs/nginx"
TEMP_WORKSPACE="/tmp/theme_deploy"

# ANSI Colors
CYAN='\033[0;36m'
BCYAN='\033[1;36m'
GREEN='\033[0;32m'
BGREEN='\033[1;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PINK='\033[1;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

cleanup() { [ -d "$TEMP_WORKSPACE" ] && rm -rf "$TEMP_WORKSPACE"; }
trap cleanup EXIT INT TERM

divider() { echo -e "${DIM}  ────────────────────────────────────────────────${NC}"; }
ok()      { echo -e "  ${BGREEN}✔${NC}  $1"; }
fail()    { echo -e "  ${RED}✘${NC}  $1"; }
info()    { echo -e "  ${CYAN}→${NC}  $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }

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
divider
echo ""

mkdir -p "$TEMP_WORKSPACE"
echo -ne "  ${CYAN}↓${NC}  Fetching theme catalog... "
do_wget "$BASE_URL/$LIST_FILE" "$TEMP_WORKSPACE/list.txt"
if [ ! -s "$TEMP_WORKSPACE/list.txt" ]; then
    echo -e "${RED}failed${NC}"
    fail "Cannot reach GitHub. Check internet connection."
    exit 1
fi
echo -e "${BGREEN}done${NC}"
echo ""
echo -e "  ${WHITE}Available Themes${NC}"
divider

i=1
while IFS='|' read -r name folder || [ -n "$name" ]; do
    clean_name=$(echo "$name" | tr -d '\r\n')
    clean_folder=$(echo "$folder" | tr -d '\r\n')
    [ -z "$clean_name" ] && continue
    echo -e "  ${PINK}$i)${NC}  $clean_name  ${DIM}← $clean_folder${NC}"
    echo "$clean_name"   >> "$TEMP_WORKSPACE/names.txt"
    echo "$clean_folder" >> "$TEMP_WORKSPACE/folders.txt"
    i=$((i+1))
done < "$TEMP_WORKSPACE/list.txt"

total_themes=$((i-1))
[ "$total_themes" -eq 0 ] && fail "No themes found." && exit 1

divider
echo ""
printf "  Select a theme (1-$total_themes): "
read choice < /dev/tty

case "$choice" in
    ''|*[!0-9]*) fail "Invalid input."; exit 1 ;;
esac
[ "$choice" -lt 1 ] || [ "$choice" -gt "$total_themes" ] && fail "Out of range." && exit 1

SELECTED_NAME=$(sed -n "${choice}p" "$TEMP_WORKSPACE/names.txt")
SELECTED_FOLDER=$(sed -n "${choice}p" "$TEMP_WORKSPACE/folders.txt")
THEME_BASE_URL="$BASE_URL/$SELECTED_FOLDER"

# =================================================================
# PHASE 2: SYSTEM CHECKS
# =================================================================
echo ""
echo -e "  ${WHITE}System Checks${NC}"
divider

! mount | grep -q "/jffs" && fail "JFFS not mounted. Enable JFFS in Administration first." && exit 1
ok "JFFS partition active"

FREE_JFFS=$(df -k /jffs | awk 'NR==2 {print $4}')
[ "$FREE_JFFS" -lt 10240 ] && warn "Low JFFS space (${FREE_JFFS}KB)" || ok "JFFS space OK (${FREE_JFFS}KB free)"

# Cek nginx
if ! which nginx > /dev/null 2>&1; then
    warn "nginx not found — login page will use Basic Auth fallback"
    HAS_NGINX=0
else
    ok "nginx available ($(nginx -v 2>&1 | cut -d/ -f2))"
    HAS_NGINX=1
fi

echo ""
echo -e "  ${WHITE}Installing:${NC} ${PINK}$SELECTED_NAME${NC}"
divider

# =================================================================
# PHASE 3: PREPARATION
# =================================================================
echo -ne "  ${CYAN}[1/5]${NC}  Checking previous installation...       "
if [ -d "$INSTALL_PATH" ] && [ "$(ls -A $INSTALL_PATH 2>/dev/null)" ]; then
    echo -e "${YELLOW}found${NC}"
    warn "Previous installation at ${DIM}$INSTALL_PATH${NC}"
    printf "  Overwrite? (y/n): "
    read confirm < /dev/tty
    case "$confirm" in
        y|Y)
            echo -ne "  ${CYAN}[1/5]${NC}  Removing previous...                    "
            mount | grep -q " /www " && umount -l /www 2>/dev/null
            rm -rf "$INSTALL_PATH"
            echo -e "${BGREEN}done${NC}"
            ;;
        *) info "Cancelled."; exit 0 ;;
    esac
else
    echo -e "${BGREEN}clean${NC}"
    mount | grep -q " /www " && umount -l /www 2>/dev/null
fi

echo -ne "  ${CYAN}[2/5]${NC}  Mirroring /www to JFFS...               "
mkdir -p "$INSTALL_PATH"
cp -a /www/. "$INSTALL_PATH/"
rm -f "$INSTALL_PATH/default.css"
echo -e "${BGREEN}done${NC}"

# =================================================================
# PHASE 4: DOWNLOAD & DEPLOY
# =================================================================
THEME_URL="$THEME_BASE_URL/Theme.tar"
echo -ne "  ${CYAN}[3/5]${NC}  Downloading theme...                    "
do_wget "$THEME_URL" "$TEMP_WORKSPACE/Theme.tar"
if [ $? -ne 0 ] || [ ! -s "$TEMP_WORKSPACE/Theme.tar" ]; then
    echo -e "${RED}failed${NC}"
    fail "Cannot download Theme.tar"
    exit 1
fi
echo -e "${BGREEN}done${NC}"

echo -ne "  ${CYAN}[4/5]${NC}  Extracting theme assets...              "
tar -xf "$TEMP_WORKSPACE/Theme.tar" -C "$INSTALL_PATH/" 2>/dev/null
[ $? -ne 0 ] && echo -e "${RED}failed${NC}" && fail "Extraction failed." && exit 1
echo -e "${BGREEN}done${NC}"

# =================================================================
# PHASE 5: LOGIN PAGE + NGINX SETUP
# =================================================================
echo -ne "  ${CYAN}[5/5]${NC}  Setting up login page & boot hooks...   "

# Deteksi VIDEO_SCRIPT
if [ -f "$INSTALL_PATH/adaptiverealtime.js" ]; then
    VIDEO_SCRIPT="adaptiverealtime.js"
elif [ -f "$INSTALL_PATH/adaptive.js" ]; then
    VIDEO_SCRIPT="adaptive.js"
else
    VIDEO_SCRIPT="bg-video.js"
fi

# Inject script ke tomato.js
if [ -f "$INSTALL_PATH/tomato.js" ]; then
    if ! grep -q "$VIDEO_SCRIPT" "$INSTALL_PATH/tomato.js"; then
        echo "document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$VIDEO_SCRIPT\";document.head.appendChild(s);});" >> "$INSTALL_PATH/tomato.js"
    fi
fi

# Permissions
chmod 755 "$INSTALL_PATH"
chmod 644 "$INSTALL_PATH"/* 2>/dev/null
chmod 755 "$INSTALL_PATH"/*.cgi 2>/dev/null

# Download login.html
do_wget "$THEME_BASE_URL/login.html" "$INSTALL_PATH/login.html" 2>/dev/null
[ ! -s "$INSTALL_PATH/login.html" ] && do_wget "$BASE_URL/login.html" "$INSTALL_PATH/login.html" 2>/dev/null

# Buat index.html redirect
cat > "$INSTALL_PATH/index.html" << 'IDXEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8">
<meta http-equiv="refresh" content="0;url=/login.html">
<script>window.location.replace('/login.html');</script>
</head><body></body></html>
IDXEOF

# Simpan credentials ke .passwd
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

SAFE_PATH=$(echo "$INSTALL_PATH" | tr -cd 'a-zA-Z0-9/_-')
SAFE_SCRIPT=$(echo "$VIDEO_SCRIPT" | tr -cd 'a-zA-Z0-9/_.-')

# =================================================================
# NGINX SETUP (jika tersedia)
# =================================================================
if [ "$HAS_NGINX" -eq 1 ]; then
    # Generate B64 credentials untuk nginx
    B64=$(echo -n "${HTTP_USER}:${HTTP_PASS}" | openssl base64 | tr -d '\n')

    # Pindahkan httpd ke port 8008
    nvram set http_lanport=8008
    nvram commit >/dev/null 2>&1
    service httpd restart >/dev/null 2>&1
    sleep 2

    # Buat nginx dirs
    mkdir -p "$NGINX_PATH"
    mkdir -p /var/log/nginx /var/lib/nginx/client /var/lib/nginx/proxy

    # Buat static folder (tanpa .asp agar nginx tidak serve mentah)
    mkdir -p "$NGINX_PATH/static"
    cp "$INSTALL_PATH"/*.css "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH"/*.js  "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH"/*.png "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH"/*.ico "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH/login.html" "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH/bgmp4.gif"  "$NGINX_PATH/static/" 2>/dev/null

    # Buat mime.types
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

    # Buat nginx.conf
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

        location = / {
            try_files /login.html =404;
        }

        location = /login.html {
            try_files \$uri =404;
        }

        location ~* ^/logout {
            return 302 /login.html?logout=1;
        }

        location = /bgmp4.gif {
            types { video/mp4 gif; }
            try_files \$uri =404;
        }

        location ~* \.(css|js|png|jpg|jpeg|ico|svg|woff|woff2|html)$ {
            try_files \$uri @proxy;
        }

        location / {
            proxy_pass http://192.168.1.1:8008;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_buffering on;
        }

        location @proxy {
            proxy_pass http://192.168.1.1:8008;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_buffering on;
        }
    }
}
NGINXEOF

    # Test dan start nginx
    nginx -c "$NGINX_PATH/nginx.conf" -t >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        pkill nginx 2>/dev/null
        sleep 1
        nginx -c "$NGINX_PATH/nginx.conf"
    fi

    # Boot hook dengan nginx
    BOOT_HOOK="# --- Theme Startup ---
sleep 10
[ -d $SAFE_PATH ] || exit 0
mount | grep -q $SAFE_PATH || mount --bind $SAFE_PATH /www
grep -q $SAFE_SCRIPT $SAFE_PATH/tomato.js 2>/dev/null || echo 'document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$SAFE_SCRIPT\";document.head.appendChild(s);});' >> $SAFE_PATH/tomato.js
nvram set http_lanport=8008
service httpd restart
sleep 2
mkdir -p /var/log/nginx /var/lib/nginx/client /var/lib/nginx/proxy
pkill nginx 2>/dev/null; sleep 1
nginx -c $NGINX_PATH/nginx.conf
# --- End Theme Startup ---"

else
    # Tanpa nginx — pakai Basic Auth biasa
    mount --bind "$INSTALL_PATH" /www
    service httpd restart >/dev/null 2>&1

    BOOT_HOOK="# --- Theme Startup ---
sleep 10
[ -d $SAFE_PATH ] || exit 0
mount | grep -q $SAFE_PATH || { mount --bind $SAFE_PATH /www && service httpd restart; }
grep -q $SAFE_SCRIPT $SAFE_PATH/tomato.js 2>/dev/null || echo 'document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$SAFE_SCRIPT\";document.head.appendChild(s);});' >> $SAFE_PATH/tomato.js
# --- End Theme Startup ---"
fi

# Simpan boot hook
CLEAN_INIT=$(nvram get script_init | awk '/# --- Theme Startup ---/{f=1} f{next} {print} /# --- End Theme Startup ---/{f=0}')
if [ -n "$(nvram get script_init)" ]; then
    nvram set script_init="$CLEAN_INIT
$BOOT_HOOK"
else
    nvram set script_init="$BOOT_HOOK"
fi
nvram commit >/dev/null 2>&1

# Mount dan activate
mount --bind "$INSTALL_PATH" /www
service httpd restart >/dev/null 2>&1

echo -e "${BGREEN}done${NC}"

# =================================================================
# DONE
# =================================================================
echo ""
divider
echo ""
echo -e "  ${BGREEN}✔  Installation complete!${NC}"
echo ""
echo -e "  ${WHITE}Theme     ${NC}${PINK}$SELECTED_NAME${NC}"
echo -e "  ${WHITE}Path      ${NC}${DIM}$INSTALL_PATH${NC}"
echo -e "  ${WHITE}Script    ${NC}${DIM}$VIDEO_SCRIPT${NC}"
if [ "$HAS_NGINX" -eq 1 ]; then
echo -e "  ${WHITE}Login     ${NC}${BGREEN}Custom login page (nginx proxy)${NC}"
echo -e "  ${WHITE}httpd     ${NC}${DIM}port 8008 (behind nginx)${NC}"
else
echo -e "  ${WHITE}Login     ${NC}${YELLOW}Basic Auth (nginx not available)${NC}"
fi
echo -e "  ${WHITE}Status    ${NC}${BGREEN}Active & persistent${NC}"
echo ""
echo -e "  ${YELLOW}⚑  Press Ctrl+F5 to clear browser cache.${NC}"
echo ""
divider
echo ""
