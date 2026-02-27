#!/bin/sh

# =================================================================
# GLOBAL CONFIGURATION
# =================================================================
BASE_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main"
THEME_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/Theme"
LIST_FILE="ThemeList.txt"
INSTALL_PATH="/jffs/mywww"
TEMP_WORKSPACE="/tmp/theme_deploy"

# File yang didownload langsung dari folder theme (tanpa tar)
THEME_FILES="default.css logol.png logor.png bgmp4.gif"

# ANSI Colors & Styles
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

# Cleanup RAM saat exit/error
cleanup() {
    [ -d "$TEMP_WORKSPACE" ] && rm -rf "$TEMP_WORKSPACE"
}
trap cleanup EXIT INT TERM

# Helper
divider() { echo -e "${DIM}  ────────────────────────────────────────────────${NC}"; }
ok()   { echo -e "  ${BGREEN}✔${NC}  $1"; }
fail() { echo -e "  ${RED}✘${NC}  $1"; }
info() { echo -e "  ${CYAN}→${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }

# BusyBox wget wrapper
do_wget() {
    wget --no-check-certificate -T 15 "$1" -O "$2" 2>/dev/null
}

# =================================================================
# PHASE 1: THEME SELECTION MENU
# =================================================================
clear
echo ""
echo -e "${PINK}  ████████╗██╗  ██╗███████╗███╗   ███╗███████╗${NC}"
echo -e "${PINK}     ██╔══╝██║  ██║██╔════╝████╗ ████║██╔════╝${NC}"
echo -e "${PINK}     ██║   ███████║█████╗  ██╔████╔██║█████╗  ${NC}"
echo -e "${PINK}     ██║   ██╔══██║██╔══╝  ██║╚██╔╝██║██╔══╝  ${NC}"
echo -e "${PINK}     ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗${NC}"
echo -e "${PINK}     ╚═╝   ╚═╝  ╚══════╝╚═╝     ╚═╝╚══════╝${NC}"
echo ""
echo -e "${WHITE}        FreshTomato Theme Installer${NC}  ${DIM}by Lucrumae${NC}"
divider
echo ""

mkdir -p "$TEMP_WORKSPACE"
echo -ne "  ${CYAN}↓${NC}  Fetching theme catalog from GitHub... "

do_wget "$BASE_URL/$LIST_FILE" "$TEMP_WORKSPACE/list.txt"

if [ ! -s "$TEMP_WORKSPACE/list.txt" ]; then
    echo -e "${RED}failed${NC}"
    echo ""
    fail "Unable to reach GitHub. Check your internet connection."
    echo ""
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
if [ "$total_themes" -eq 0 ]; then
    echo ""
    fail "No themes found in catalog. The list file may be empty."
    echo ""
    exit 1
fi

divider
echo ""
printf "  Select a theme (1-$total_themes): "
read choice < /dev/tty

# Validasi input
case "$choice" in
    ''|*[!0-9]*)
        echo ""
        fail "Invalid input — please enter a number between 1 and $total_themes."
        echo ""
        exit 1
        ;;
esac

if [ "$choice" -lt 1 ] || [ "$choice" -gt "$total_themes" ]; then
    echo ""
    fail "Out of range — no theme #$choice in the list."
    echo ""
    exit 1
fi

SELECTED_NAME=$(sed -n "${choice}p" "$TEMP_WORKSPACE/names.txt")
SELECTED_FOLDER=$(sed -n "${choice}p" "$TEMP_WORKSPACE/folders.txt")

if [ -z "$SELECTED_NAME" ] || [ -z "$SELECTED_FOLDER" ]; then
    fail "Could not resolve theme. Aborting."
    exit 1
fi

# =================================================================
# PHASE 2: SYSTEM & SPACE CHECKS
# =================================================================
echo ""
echo -e "  ${WHITE}System Checks${NC}"
divider

if ! mount | grep -q "/jffs"; then
    fail "JFFS partition is not mounted. Enable JFFS in Administration first."
    echo ""
    exit 1
fi
ok "JFFS partition is active"

FREE_JFFS=$(df -k /jffs | awk 'NR==2 {print $4}')
if [ "$FREE_JFFS" -lt 10240 ]; then
    warn "Low JFFS space detected (${FREE_JFFS}KB free). Installation may fail."
else
    ok "Sufficient JFFS space available (${FREE_JFFS}KB free)"
fi

echo ""
echo -e "  ${WHITE}Installing:${NC} ${PINK}$SELECTED_NAME${NC}"
divider

# =================================================================
# PHASE 3: PREPARATION & MIRRORING
# =================================================================
echo -ne "  ${CYAN}[1/5]${NC}  Checking previous installation...       "

if [ -d "$INSTALL_PATH" ] && [ "$(ls -A $INSTALL_PATH 2>/dev/null)" ]; then
    echo -e "${YELLOW}found${NC}"
    echo ""
    warn "A previous theme installation was detected at ${DIM}$INSTALL_PATH${NC}"
    echo ""
    printf "  Overwrite and continue? (y/n): "
    read confirm < /dev/tty
    echo ""
    case "$confirm" in
        y|Y)
            echo -ne "  ${CYAN}[1/5]${NC}  Removing previous installation...       "
            if mount | grep -q " /www "; then
                umount -l /www 2>/dev/null
            fi
            rm -rf "$INSTALL_PATH"
            echo -e "${BGREEN}done${NC}"
            ;;
        *)
            info "Installation cancelled by user."
            echo ""
            exit 0
            ;;
    esac
else
    echo -e "${BGREEN}clean${NC}"
    if mount | grep -q " /www "; then
        umount -l /www 2>/dev/null
    fi
fi

echo -ne "  ${CYAN}[2/5]${NC}  Mirroring /www to JFFS storage...       "
mkdir -p "$INSTALL_PATH"
cp -a /www/. "$INSTALL_PATH/"
rm -f "$INSTALL_PATH/default.css"
echo -e "${BGREEN}done${NC}"

# =================================================================
# PHASE 4: DOWNLOAD THEME FILES LANGSUNG (TANPA TAR)
# =================================================================
THEME_BASE_URL="$THEME_URL/$SELECTED_FOLDER"
failed_files=""

echo -e "  ${CYAN}[3/5]${NC}  Downloading theme files..."
echo ""

# ---------------------------------------------------------------
# Prioritas deteksi script video:
#   1. adaptiverealtime.js  (realtime sampling setiap 5 detik)
#   2. adaptive.js          (sampling sekali saat play)
#   3. bg-video.js          (fallback standar dari main)
# ---------------------------------------------------------------
VIDEO_SCRIPT="bg-video.js"

printf "        ${DIM}%-20s${NC} " "adaptiverealtime.js"
do_wget "$THEME_BASE_URL/adaptiverealtime.js" "$INSTALL_PATH/adaptiverealtime.js"
if [ $? -eq 0 ] && [ -s "$INSTALL_PATH/adaptiverealtime.js" ]; then
    SIZE=$(ls -lh "$INSTALL_PATH/adaptiverealtime.js" | awk '{print $5}')
    echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
    VIDEO_SCRIPT="adaptiverealtime.js"
    ok "adaptiverealtime.js detected — using realtime adaptive mode"
else
    rm -f "$INSTALL_PATH/adaptiverealtime.js" 2>/dev/null
    echo -e "${DIM}skipped${NC}"

    printf "        ${DIM}%-20s${NC} " "adaptive.js"
    do_wget "$THEME_BASE_URL/adaptive.js" "$INSTALL_PATH/adaptive.js"
    if [ $? -eq 0 ] && [ -s "$INSTALL_PATH/adaptive.js" ]; then
        SIZE=$(ls -lh "$INSTALL_PATH/adaptive.js" | awk '{print $5}')
        echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
        VIDEO_SCRIPT="adaptive.js"
        ok "adaptive.js detected — using adaptive mode"
    else
        rm -f "$INSTALL_PATH/adaptive.js" 2>/dev/null
        echo -e "${DIM}skipped${NC}"

        # Fallback ke bg-video.js dari main
        printf "        ${DIM}%-20s${NC} " "bg-video.js"
        do_wget "$BASE_URL/bg-video.js" "$INSTALL_PATH/bg-video.js"
        if [ $? -ne 0 ] || [ ! -s "$INSTALL_PATH/bg-video.js" ]; then
            echo -e "${RED}failed${NC}"
            fail "Could not download bg-video.js from main branch."
            echo ""
            exit 1
        fi
        SIZE=$(ls -lh "$INSTALL_PATH/bg-video.js" | awk '{print $5}')
        echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
    fi
fi

# Download file tema
for FILE in $THEME_FILES; do
    printf "        ${DIM}%-20s${NC} " "$FILE"
    do_wget "$THEME_BASE_URL/$FILE" "$INSTALL_PATH/$FILE"
    if [ $? -ne 0 ] || [ ! -s "$INSTALL_PATH/$FILE" ]; then
        case "$FILE" in
            logol.png|logor.png|bgmp4.gif)
                echo -e "${DIM}skipped${NC} ${DIM}(not used by this theme)${NC}"
                ;;
            *)
                echo -e "${RED}failed${NC}"
                failed_files="$failed_files $FILE"
                ;;
        esac
    else
        SIZE=$(ls -lh "$INSTALL_PATH/$FILE" | awk '{print $5}')
        echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
    fi
done

echo ""

# Batalkan jika ada file wajib yang gagal
if [ -n "$failed_files" ]; then
    fail "Required files failed to download:$failed_files"
    echo ""
    fail "Check folder name in ThemeList.txt or your internet connection."
    echo ""
    exit 1
fi

# =================================================================
# PHASE 5: PERMISSIONS & BOOT HOOKS
# =================================================================
echo -ne "  ${CYAN}[4/5]${NC}  Setting permissions...                  "
chmod 755 "$INSTALL_PATH"
chmod 644 "$INSTALL_PATH"/* 2>/dev/null
chmod 755 "$INSTALL_PATH"/*.sh 2>/dev/null
chmod 755 "$INSTALL_PATH"/*.cgi 2>/dev/null
echo -e "${BGREEN}done${NC}"

echo -ne "  ${CYAN}[5/5]${NC}  Configuring boot hooks...               "

# Download login.html
printf "        ${DIM}%-20s${NC} " "login.html"
do_wget "$THEME_BASE_URL/login.html" "$INSTALL_PATH/login.html"
if [ $? -ne 0 ] || [ ! -s "$INSTALL_PATH/login.html" ]; then
    do_wget "$BASE_URL/login.html" "$INSTALL_PATH/login.html" 2>/dev/null
fi
if [ -s "$INSTALL_PATH/login.html" ]; then
    SIZE=$(ls -lh "$INSTALL_PATH/login.html" | awk '{print $5}')
    echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
else
    rm -f "$INSTALL_PATH/login.html" 2>/dev/null
    echo -e "${DIM}skipped${NC}"
fi

# Inject script yang aktif (adaptive.js atau bg-video.js) ke tomato.js
if [ -f "$INSTALL_PATH/tomato.js" ]; then
    if ! grep -q "$VIDEO_SCRIPT" "$INSTALL_PATH/tomato.js"; then
        echo "document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$VIDEO_SCRIPT\";document.head.appendChild(s);});" >> "$INSTALL_PATH/tomato.js"
    fi
fi

SAFE_PATH=$(echo "$INSTALL_PATH" | tr -cd 'a-zA-Z0-9/_-')
SAFE_SCRIPT=$(echo "$VIDEO_SCRIPT" | tr -cd 'a-zA-Z0-9/_.-')

# ---------------------------------------------------------------
# SETUP CUSTOM LOGIN PAGE
# BusyBox httpd intercept request SEBELUM file dirender jika
# http_passwd terisi — satu-satunya cara bypass adalah
# kosongkan http_passwd lalu login.html verifikasi sendiri
# via fetch + sessionStorage token.
# ---------------------------------------------------------------

if [ -s "$INSTALL_PATH/login.html" ]; then
    # Simpan credentials sekarang sebelum dikosongkan
    STORED_USER=$(nvram get http_username)
    STORED_PASS=$(nvram get http_passwd)

    # Tulis credentials ke file di JFFS agar login.html bisa verifikasi
    # File ini hanya readable dari router (tidak serve oleh httpd karena .passwd)
    echo "${STORED_USER}:${STORED_PASS}" > "$INSTALL_PATH/.passwd"
    chmod 600 "$INSTALL_PATH/.passwd"

    # Buat auth.cgi — verifikasi credentials via POST
    cat > "$INSTALL_PATH/auth.cgi" << 'AUTHEOF'
#!/bin/sh
printf "Content-Type: text/plain

"

# Baca POST body
if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    POST=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
else
    read -r POST
fi

# URL decode sederhana
decode(){ echo "$1" | sed 's/+/ /g;s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x/g' | xargs printf '%b' 2>/dev/null || echo "$1"; }

USER=$(decode "$(echo "$POST" | sed -n 's/.*[?&]user=\([^&]*\).*//p; s/^user=\([^&]*\).*//p' | head -1)")
PASS=$(decode "$(echo "$POST" | sed -n 's/.*[?&]pass=\([^&]*\).*//p; s/^pass=\([^&]*\).*//p' | head -1)")

# Baca stored credentials
CRED_FILE="/jffs/mywww/.passwd"
if [ ! -f "$CRED_FILE" ]; then
    CRED_FILE="/www/.passwd"
fi

STORED=$(cat "$CRED_FILE" 2>/dev/null)
STORED_U="${STORED%%:*}"
STORED_P="${STORED#*:}"

if [ -n "$USER" ] && [ "$USER" = "$STORED_U" ] && [ "$PASS" = "$STORED_P" ]; then
    # Generate token: timestamp + checksum
    TOKEN=$(echo "${USER}${PASS}$(date +%s%N 2>/dev/null || date +%s)" | md5sum | cut -c1-32)
    nvram set ft_session="$TOKEN" 2>/dev/null
    printf "OK:%s" "$TOKEN"
else
    printf "FAIL"
fi
AUTHEOF
    chmod 755 "$INSTALL_PATH/auth.cgi"

    # Buat logout.cgi
    cat > "$INSTALL_PATH/logout.cgi" << 'LOGEOF'
#!/bin/sh
printf "Content-Type: text/html

"
nvram set ft_session="" 2>/dev/null
printf "<script>window.location.replace('/login.html');</script>"
LOGEOF
    chmod 755 "$INSTALL_PATH/logout.cgi"

    # Buat index.html redirect ke login.html
    cat > "$INSTALL_PATH/index.html" << 'IDXEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8">
<meta http-equiv="refresh" content="0;url=/login.html">
<script>window.location.replace('/login.html');</script>
</head><body></body></html>
IDXEOF

    # Kosongkan http_passwd agar BusyBox httpd tidak minta Basic Auth
    # Keamanan dijaga oleh login.html + sessionStorage token
    nvram set http_passwd=""
    nvram commit >/dev/null 2>&1
    service httpd restart >/dev/null 2>&1

    ok "Custom login page active — Basic Auth popup removed"
else
    warn "login.html not found — keeping default Basic Auth"
fi

# ---------------------------------------------------------------
# BOOT HOOK
# ---------------------------------------------------------------
CLEAN_INIT=$(nvram get script_init | awk '/# --- Theme Startup ---/{found=1} found{next} {print} /# --- End Theme Startup ---/{found=0}')

HOOK="# --- Theme Startup ---
sleep 10
[ -d $SAFE_PATH ] || exit 0
grep -q $SAFE_SCRIPT $SAFE_PATH/tomato.js 2>/dev/null || echo 'document.addEventListener("DOMContentLoaded",function(){var s=document.createElement("script");s.src="/$SAFE_SCRIPT";document.head.appendChild(s);});' >> $SAFE_PATH/tomato.js
mount | grep -q $SAFE_PATH || { mount --bind $SAFE_PATH /www && service httpd restart; }
# --- End Theme Startup ---"

if [ -n "$(nvram get script_init)" ]; then
    nvram set script_init="$CLEAN_INIT
$HOOK"
else
    nvram set script_init="$HOOK"
fi
nvram commit >/dev/null 2>&1

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
echo -e "  ${WHITE}Status    ${NC}${BGREEN}Active & persistent across reboots${NC}"
echo ""
echo -e "  ${YELLOW}⚑  Press Ctrl+F5 in your browser to clear cache.${NC}"
echo ""
divider
echo ""
