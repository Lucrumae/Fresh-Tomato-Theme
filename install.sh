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
    printf "  Uninstall and reinstall? (y/n): "; read confirm < /dev/tty; echo ""
    case "$confirm" in
        y|Y)
            echo -e "  ${CYAN}[1/5]${NC}  Uninstalling previous..."; echo ""

            # 1. Stop reboot-daemon jika ada
            printf "        ${DIM}%-30s${NC} " "stopping reboot-daemon"
            kill $(ps 2>/dev/null | grep reboot-daemon | grep -v grep | awk '{print $1}') 2>/dev/null
            kill $(netstat -tlnp 2>/dev/null | grep ':8009 ' | awk '{print $7}' | cut -d/ -f1) 2>/dev/null
            echo -e "${BGREEN}done${NC}"

            # 2. Stop nginx
            printf "        ${DIM}%-30s${NC} " "stopping nginx"
            pkill -9 nginx 2>/dev/null
            kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
            rm -f /tmp/nginx.pid 2>/dev/null
            sleep 1
            echo -e "${BGREEN}done${NC}"

            # 3. Unmount /www bind mount
            printf "        ${DIM}%-30s${NC} " "unmounting /www"
            umount -l /www 2>/dev/null
            sleep 1
            echo -e "${BGREEN}done${NC}"

            # 4. Restore httpd ke port 80
            printf "        ${DIM}%-30s${NC} " "restoring httpd port 80"
            nvram set http_lanport=80
            nvram commit >/dev/null 2>&1
            service httpd restart >/dev/null 2>&1
            echo -e "${BGREEN}done${NC}"

            # 5. Hapus boot entry dari script_init
            printf "        ${DIM}%-30s${NC} " "cleaning script_init"
            CURRENT=$(nvram get script_init 2>/dev/null)
            STRIPPED=$(printf '%s
' "$CURRENT" | awk '
                /^# --- FreshTomato Theme ---$/ { skip=1; next }
                /^# --- End FreshTomato Theme ---$/ { skip=0; next }
                /^# --- Theme Startup ---$/ { skip=1; next }
                /^# --- End Theme Startup ---$/ { skip=0; next }
                skip { next }
                { print }
            ')
            STRIPPED=$(printf '%s' "$STRIPPED" | sed '/^[[:space:]]*$/d')
            nvram set script_init="$STRIPPED"
            nvram commit >/dev/null 2>&1
            echo -e "${BGREEN}done${NC}"

            # 6. Hapus semua file instalasi
            printf "        ${DIM}%-30s${NC} " "removing install files"
            rm -rf "$INSTALL_PATH"
            rm -rf "$NGINX_PATH"
            rm -f /tmp/ft_reboot_now /tmp/ft_reboot_log 2>/dev/null
            echo -e "${BGREEN}done${NC}"

            echo ""
            echo -e "  ${BGREEN}✔  Uninstall complete. Proceeding with fresh install...${NC}"; echo ""
            # Reinstall: _FORCE_CREDS tetap 0 — user yang sudah punya credentials
            # tidak perlu dipaksa ganti. Mereka bisa ganti via prompt biasa.
            ;;
        *) echo -e "  ${CYAN}→${NC}  Cancelled."; exit 0 ;;
    esac
else
    echo -e "${BGREEN}clean${NC}"
    _FORCE_CREDS=1  # Clean install — wajib set credentials baru
    # Bersihkan sisa nginx/flag jika ada
    pkill -9 nginx 2>/dev/null
    kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
    rm -f /tmp/nginx.pid 2>/dev/null
    sleep 1
    umount -l /www 2>/dev/null; sleep 1
    [ -d "$NGINX_PATH" ] && rm -rf "$NGINX_PATH"
    rm -f /tmp/ft_reboot_now /tmp/ft_reboot_log 2>/dev/null
fi
[ -z "${_FORCE_CREDS:-}" ] && _FORCE_CREDS=0

echo -ne "  ${CYAN}[2/5]${NC}  Mirroring /www to JFFS...               "
mkdir -p "$INSTALL_PATH"
cp -a /www/. "$INSTALL_PATH/"
# Hapus file berbahaya yang ikut di-copy dari /www
rm -f  "$INSTALL_PATH/default.css"        # diganti theme
rm -f  "$INSTALL_PATH/adminer.php"         # MySQL admin — berbahaya
rm -f  "$INSTALL_PATH/phpinfo.php"         # PHP info leak — berbahaya
rm -rf "$INSTALL_PATH/apcupsd"             # Binary ELF — tidak diperlukan
rm -f  "$INSTALL_PATH/index.html"          # Nginx testpage — diganti kita
# ext/cgi-bin dan user/cgi-bin kosong tapi copy tetap aman

# Patch status-log.asp — default refresh 10s + async DOM rendering
# Root cause lag: logGrid.populate() insert 500+ DOM rows satu-satu
#   = main thread freeze 4 detik setiap refresh
# Fix: override function via <script> injection — NO python3 needed
# Teknik: tulis JS override ke temp file, inject sebelum </body> via awk
if [ -f "$INSTALL_PATH/status-log.asp" ]; then

    # A. Default refresh 5 → 10 detik (via sed, interval cookie masih bisa override)
    sed -i "s/TomatoRefresh('update.cgi', 'exec=showlog', 5,/TomatoRefresh('update.cgi', 'exec=showlog', 10,/" \
        "$INSTALL_PATH/status-log.asp" 2>/dev/null

    # B. Tulis JS override ke temp file (single-quoted heredoc: no expansion, no escaping)
    cat > /tmp/ft_log_patch.js << 'JSEOF'
/* FreshTomato Theme — async log renderer
 * Override logGrid.populate() dari sync DOM loop → rAF batch swap
 * Versi asli: 500+ DOM mutations sync = freeze 4 detik
 * Versi ini: build tbody off-screen → replaceChild 1x via requestAnimationFrame
 */
logGrid.populate = function() {
if (messages == null) return;
var self = this;
var messagesToAdd = messages.concat();
time = messagesToAdd.shift();
if (entriesMode != 0)
messagesToAdd = messagesToAdd.slice(-1 * entriesMode - 1);
var localSearch;
if (currentSearch) {
localSearch = currentSearch;
if (localSearch.substr(0, 1) == '-') {
localSearch = localSearch.substr(1);
negativeSearch = 1;
} else {
negativeSearch = 0;
}
}
var rowsToRender = [];
var count = 0;
for (var index = 0; index < messagesToAdd.length; ++index) {
if (messagesToAdd[index]) {
var logLineMap = getLogLineParsedMap(messagesToAdd[index]);
if ((currentFilterValue == 0) || (E('maxlevel').checked ?
    (currentFilterValue >= logLineMap[LINE_PARSE_MAP_LEVEL_ATTR_POS][1]) :
    (currentFilterValue == logLineMap[LINE_PARSE_MAP_LEVEL_ATTR_POS][1]))) {
if (!localSearch || containsSearch(logLineMap, localSearch)) {
rowsToRender.push(createHighlightedRow(logLineMap));
count++;
}
}
}
}
E('log-occurence-span').style.display = (currentSearch ? 'inline' : 'none');
elem.setInnerHTML('log-occurence-value', count);
if (time.indexOf('Not Available') === -1)
elem.setInnerHTML('log-refresh-time', time.match(/(\d+\:\d+\:\d+)\s(.*)/i)[1]+' - Last Refreshed');
var tableDiv = E('log-table');
var wasAtBottom = (tableDiv.offsetHeight + tableDiv.scrollTop >= tableDiv.scrollHeight - 5);
var tb = self.tb;
var oldBody = tb.tBodies[0];
var newBody = document.createElement('tbody');
for (var r = 0; r < rowsToRender.length; ++r) {
var cells = rowsToRender[r];
var tr = newBody.insertRow(-1);
tr.className = (1 & r) ? 'odd' : 'even';
for (var ci = 0; ci < cells.length; ++ci) {
tr.appendChild(cells[ci]);
}
}
requestAnimationFrame(function() {
if (oldBody) tb.replaceChild(newBody, oldBody);
else tb.appendChild(newBody);
var e = E('log-table').children[0].children[0].children[0];
if (e) {
var d = E('log-table-header').children[0].children[0].children[0];
d.children[0].style.width = getComputedStyle(e.children[0]).width;
d.children[1].style.width = getComputedStyle(e.children[1]).width;
d.children[2].style.width = getComputedStyle(e.children[2]).width;
d.children[3].style.width = getComputedStyle(e.children[3]).width;
}
if (wasAtBottom) scrollToBottom();
});
};
JSEOF

    # C. Inject JS override sebelum </body> via awk (busybox-compatible)
    #    NR==FNR: baca file pertama (patch JS) ke variable patch
    #    Ketemu </body>: print tag <script> + patch + </script> dulu, baru </body>
    awk 'NR==FNR{patch=patch $0 "\n"; next} /^<\/body>$/{print "<script>"; printf "%s",patch; print "</script>"} {print}' \
        /tmp/ft_log_patch.js "$INSTALL_PATH/status-log.asp" > /tmp/ft_log_patched.asp \
        && mv /tmp/ft_log_patched.asp "$INSTALL_PATH/status-log.asp"

    rm -f /tmp/ft_log_patch.js /tmp/ft_log_patched.asp 2>/dev/null
fi

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

# halt-wait.html — custom halt waiting page dengan video background
printf "        ${DIM}%-22s${NC} " "halt-wait.html"
do_wget "$BASE_URL/halt-wait.html" "$INSTALL_PATH/halt-wait.html"
if [ $? -eq 0 ] && [ -s "$INSTALL_PATH/halt-wait.html" ]; then
    SIZE=$(ls -lh "$INSTALL_PATH/halt-wait.html" | awk '{print $5}')
    echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
else
    echo -e "${RED}failed${NC}"; fail "Cannot download halt-wait.html."; exit 1
fi

# reboot-wait.html — custom reboot waiting page dengan video background
printf "        ${DIM}%-22s${NC} " "reboot-wait.html"
do_wget "$BASE_URL/reboot-wait.html" "$INSTALL_PATH/reboot-wait.html"
if [ $? -eq 0 ] && [ -s "$INSTALL_PATH/reboot-wait.html" ]; then
    SIZE=$(ls -lh "$INSTALL_PATH/reboot-wait.html" | awk '{print $5}')
    echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
    # Inject http_id ke reboot-wait.html
    FT_HTTP_ID=$(nvram get http_id 2>/dev/null)
    sed -i "s/FT_HTTP_ID/${FT_HTTP_ID}/g" "$INSTALL_PATH/reboot-wait.html"
else
    echo -e "${RED}failed${NC}"; fail "Cannot download reboot-wait.html."; exit 1
fi


echo ""

[ -n "$failed_files" ] && fail "Required files failed:$failed_files" && exit 1

# =================================================================
# PHASE 5: PERMISSIONS
# =================================================================
echo -ne "  ${CYAN}[4/5]${NC}  Setting permissions...                  "
chmod 755 "$INSTALL_PATH"
chmod 644 "$INSTALL_PATH"/* 2>/dev/null
chmod 750 "$INSTALL_PATH"/*.cgi 2>/dev/null
chown root:root "$INSTALL_PATH"/*.cgi 2>/dev/null
chmod o-w "$INSTALL_PATH"/* 2>/dev/null
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

# Ambil credentials dari nvram
HTTP_USER=$(nvram get http_username 2>/dev/null)
HTTP_PASS=$(nvram get http_passwd 2>/dev/null)

echo ""
echo ""
echo -e "  ${WHITE}Login Credentials${NC}"
divider
echo -e "  ${DIM}Configure credentials for the web login page, SSH, and router admin.${NC}"
echo -e "  ${DIM}All three will be kept in sync automatically.${NC}"
echo ""

if [ "${_FORCE_CREDS:-0}" -eq 1 ]; then
    # ── FORCE MODE: clean install atau reinstall ─────────────────────────
    # User WAJIB isi credentials — tidak peduli apakah sudah ada atau tidak
    echo -e "  ${YELLOW}⚑  Fresh install detected — you must set new credentials.${NC}"
    echo -e "  ${DIM}  These will be used for web login, SSH, and router admin.${NC}"
    echo ""

    # ── Username ─────────────────────────────────────────────────────────
    while true; do
        printf "  ${WHITE}Username${NC}: "; read new_user < /dev/tty
        new_user=$(printf '%s' "$new_user" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -z "$new_user" ]; then
            warn "Username cannot be empty."
        elif [ "${#new_user}" -lt 2 ]; then
            warn "Username too short (minimum 2 characters)."
        elif printf '%s' "$new_user" | grep -q '[^a-zA-Z0-9_@.-]'; then
            warn "Username may only contain letters, numbers, and: _ @ . -"
        else
            break
        fi
    done

    # ── Password ─────────────────────────────────────────────────────────
    while true; do
        printf "  ${WHITE}Password${NC}: "; read new_pass < /dev/tty; echo ""
        new_pass=$(printf '%s' "$new_pass" | tr -d '\r\n')
        if [ -z "$new_pass" ]; then
            warn "Password cannot be empty."
        elif [ "${#new_pass}" -lt 4 ]; then
            warn "Password too short (minimum 4 characters)."
        elif [ "$new_pass" = "admin" ] || [ "$new_pass" = "password" ] || \
             [ "$new_pass" = "1234" ] || [ "$new_pass" = "123456" ]; then
            warn "Password too weak. Please choose a stronger password."
        else
            # Konfirmasi password
            printf "  ${WHITE}Confirm password${NC}: "; read new_pass2 < /dev/tty; echo ""
            new_pass2=$(printf '%s' "$new_pass2" | tr -d '\r\n')
            if [ "$new_pass" != "$new_pass2" ]; then
                warn "Passwords do not match. Please try again."
            else
                break
            fi
        fi
    done

    HTTP_USER="$new_user"
    HTTP_PASS="$new_pass"
    unset new_pass2

else
    # ── OPTIONAL MODE: sudah ada credentials sebelumnya ──────────────────
    echo -e "  Detected credentials  ${DIM}→${NC}  ${WHITE}${HTTP_USER}${NC} / ${DIM}${HTTP_PASS}${NC}"
    echo ""
    printf "  Keep current credentials? [y/n]: "; read use_current < /dev/tty; echo ""

    case "$use_current" in
        n|N)
            # User ingin ganti — sama seperti force mode tapi boleh blank untuk keep
            echo -e "  ${CYAN}Set new credentials${NC}"; divider
            echo -e "  ${DIM}Leave blank to keep current value.${NC}"; echo ""

            printf "  ${WHITE}Username${NC} ${DIM}[${HTTP_USER}]${NC}: "; read new_user < /dev/tty
            new_user=$(printf '%s' "$new_user" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -z "$new_user" ] && new_user="$HTTP_USER"

            printf "  ${WHITE}Password${NC} ${DIM}[keep current]${NC}: "; read new_pass < /dev/tty; echo ""
            new_pass=$(printf '%s' "$new_pass" | tr -d '\r\n')
            [ -z "$new_pass" ] && new_pass="$HTTP_PASS"

            # Validasi jika user mengisi password baru
            if [ "$new_pass" != "$HTTP_PASS" ]; then
                while [ "${#new_pass}" -lt 4 ] || \
                      [ "$new_pass" = "admin" ] || [ "$new_pass" = "password" ] || \
                      [ "$new_pass" = "1234" ] || [ "$new_pass" = "123456" ]; do
                    warn "Password too weak or too short (minimum 4 characters)."
                    printf "  ${WHITE}Password${NC}: "; read new_pass < /dev/tty; echo ""
                    new_pass=$(printf '%s' "$new_pass" | tr -d '\r\n')
                    [ -z "$new_pass" ] && new_pass="$HTTP_PASS" && break
                done
            fi

            HTTP_USER="$new_user"
            HTTP_PASS="$new_pass"
            ;;
    esac
fi

# ── Dari sini HTTP_USER dan HTTP_PASS sudah final ───────────────────────
# Terapkan ke nvram, SSH, dan setup SSH user
nvram set http_username="$HTTP_USER"
nvram set http_passwd="$HTTP_PASS"
nvram commit >/dev/null 2>&1

# ── Definisi fungsi SSH helper ─────────────────────────────────────────
make_hash() {
    local pass="$1"
    local hash=""
    # MD5-crypt: satu-satunya format yang didukung dropbear FreshTomato
    hash=$(printf '%s' "$pass" | openssl passwd -1 -stdin 2>/dev/null)
    [ -z "$hash" ] && hash=$(echo "$pass" | md5sum 2>/dev/null | awk "{print \$1}")
    echo "$hash"
}

set_shadow_pass() {
    local uname="$1" upass="$2" hash
    hash=$(make_hash "$upass")
    [ -z "$hash" ] && return 1
    grep -v "^${uname}:" /etc/shadow > /tmp/shadow.tmp 2>/dev/null || true
    echo "${uname}:${hash}:18000:0:99999:7:::" >> /tmp/shadow.tmp
    cp /tmp/shadow.tmp /etc/shadow
    rm -f /tmp/shadow.tmp
}

setup_ssh_user() {
    local uname="$1" upass="$2"
    nvram set sshd_enable=1
    nvram set sshd_pass=1
    SSHD_NEEDS_RESTART=1
    set_shadow_pass "root" "$upass"
    if [ "$uname" = "root" ]; then
        awk 'BEGIN{FS=OFS=":"} /^root:/{$7="/bin/sh"} {print}' \
            /etc/passwd > /tmp/passwd.tmp && cp /tmp/passwd.tmp /etc/passwd
        ok "SSH password updated for '${WHITE}root${NC}'"
        SSH_CUSTOM_USER=""
        return
    fi
    if ! touch /etc/passwd 2>/dev/null; then
        warn "/etc/passwd is read-only — SSH custom user cannot be created."
        warn "Web login will use '${uname}', SSH falls back to 'root'."
        SSH_CUSTOM_USER=""
        return
    fi
    grep -v "^${uname}:" /etc/passwd > /tmp/passwd.tmp && cp /tmp/passwd.tmp /etc/passwd
    echo "${uname}:x:0:0::/root:/bin/sh" >> /etc/passwd
    set_shadow_pass "$uname" "$upass"
    awk 'BEGIN{FS=OFS=":"} /^root:/{$7="/bin/false"} {print}' \
        /etc/passwd > /tmp/passwd.tmp && cp /tmp/passwd.tmp /etc/passwd
    ok "SSH user '${WHITE}${uname}${NC}' created → UID 0 (runs as root)"
    ok "SSH login for 'root' blocked → shell set to /bin/false"
    SSH_CUSTOM_USER="$uname"
}

setup_ssh_user "$HTTP_USER" "$HTTP_PASS"
SSH_CUSTOM_USER="${SSH_CUSTOM_USER:-}"

echo ""
ok "Credentials applied  →  ${WHITE}${HTTP_USER}${NC}"
echo -e "  ${DIM}  Web login ✔   SSH ✔   Router admin ✔${NC}"
echo ""



echo ""

# Simpan SHA-512 hash — password tidak pernah disimpan plaintext di disk
_HASH=$(printf '%s' "${HTTP_PASS}" | openssl passwd -6 -stdin 2>/dev/null)
[ -z "$_HASH" ] && _HASH=$(printf '%s' "${HTTP_PASS}" | openssl passwd -1 -stdin 2>/dev/null)
[ -z "$_HASH" ] && { fail "Cannot hash password — openssl unavailable"; exit 1; }
printf '%s:%s\n' "${HTTP_USER}" "$_HASH" > "$INSTALL_PATH/.passwd"
unset _HASH
chmod 600 "$INSTALL_PATH/.passwd"
chown root:root "$INSTALL_PATH/.passwd" 2>/dev/null
# Sync nvram http_passwd — dipakai FreshTomato preinit restore shadow saat boot
nvram set http_passwd="${HTTP_PASS}"
nvram set http_username="${HTTP_USER}"
nvram commit >/dev/null 2>&1

# Buat auth.cgi — di-generate langsung (tidak di-pull GitHub)
cat > "$INSTALL_PATH/auth.cgi" << 'AUTHEOF'
#!/bin/sh
printf "Content-Type: text/plain\r\n\r\n"

# ── Rate limiting per-IP: max 10 req / 60 detik ──────────────────
LOCK_DIR="/tmp/ft_auth_rl"
mkdir -p "$LOCK_DIR"
CLIENT_IP="${REMOTE_ADDR:-unknown}"
SAFE_IP=$(printf '%s' "$CLIENT_IP" | tr -cd 'a-fA-F0-9.:_-' | cut -c1-45)
[ -z "$SAFE_IP" ] && SAFE_IP="unknown"
RL_FILE="$LOCK_DIR/$SAFE_IP"
NOW=$(date +%s)
if [ -f "$RL_FILE" ]; then
    FIRST=$(head -1 "$RL_FILE" 2>/dev/null)
    COUNT=$(wc -l < "$RL_FILE" 2>/dev/null); COUNT=${COUNT:-0}
    if [ -n "$FIRST" ] && [ $((NOW - FIRST)) -gt 60 ]; then
        rm -f "$RL_FILE"; COUNT=0
    elif [ "$COUNT" -gt 10 ]; then
        printf "FAIL"; exit 0
    fi
fi
[ ! -f "$RL_FILE" ] && printf '%s\n' "$NOW" > "$RL_FILE" || printf '%s\n' "$NOW" >> "$RL_FILE"

# ── URL decode ────────────────────────────────────────────────────
url_decode() {
    printf '%s' "$1" | sed 's/+/ /g' | awk '
    BEGIN { for(i=0;i<256;i++) hex[sprintf("%02x",i)]=sprintf("%c",i) }
    { while(match($0,/%[0-9A-Fa-f][0-9A-Fa-f]/)) {
        code=tolower(substr($0,RSTART+1,2))
        $0=substr($0,1,RSTART-1) hex[code] substr($0,RSTART+RLENGTH) }
      print }'
}

POST=$(cat)
USER_RAW=$(printf '%s' "$POST" | sed 's/&/\n/g' | grep '^user=' | head -1 | cut -d= -f2-)
PASS_RAW=$(printf '%s' "$POST" | sed 's/&/\n/g' | grep '^pass=' | head -1 | cut -d= -f2-)
USER=$(url_decode "$USER_RAW")
PASS=$(url_decode "$PASS_RAW")

# ── Validasi input ────────────────────────────────────────────────
SAFE_USER=$(printf '%s' "$USER" | tr -cd 'a-zA-Z0-9_@.-' | cut -c1-64)
[ -z "$USER" ] || [ -z "$PASS" ] || [ "$SAFE_USER" != "$USER" ] && { printf "FAIL"; exit 0; }
PASS_LEN=$(printf '%s' "$PASS" | wc -c)
[ "$PASS_LEN" -eq 0 ] || [ "$PASS_LEN" -gt 128 ] && { printf "FAIL"; exit 0; }

# ── Baca stored credentials ───────────────────────────────────────
# .passwd berisi hash ($6$ atau $1$), bukan plaintext
CRED=$(cat /jffs/mywww/.passwd 2>/dev/null || cat /www/.passwd 2>/dev/null)
STORED_U="${CRED%%:*}"
STORED_HASH="${CRED#*:}"

# ── Verifikasi username ───────────────────────────────────────────
U_OK=0
[ "${#USER}" -eq "${#STORED_U}" ] && [ "$USER" = "$STORED_U" ] && U_OK=1

# ── Verifikasi password via hash ──────────────────────────────────
# Support $6$ (SHA-512) dan $1$ (MD5-crypt)
P_OK=0
if [ "$U_OK" -eq 1 ] && [ -n "$STORED_HASH" ]; then
    ALGO=$(printf '%s' "$STORED_HASH" | cut -d'$' -f2)
    SALT=$(printf '%s' "$STORED_HASH" | cut -d'$' -f3)
    case "$ALGO" in 6) OPT="-6" ;; 1) OPT="-1" ;; *) OPT="" ;; esac
    if [ -n "$OPT" ] && [ -n "$SALT" ]; then
        COMPUTED=$(printf '%s' "$PASS" | openssl passwd "$OPT" -salt "$SALT" -stdin 2>/dev/null)
        [ -n "$COMPUTED" ] && [ "${#COMPUTED}" -eq "${#STORED_HASH}" ] && \
            [ "$COMPUTED" = "$STORED_HASH" ] && P_OK=1
    fi
fi

if [ "$U_OK" -eq 1 ] && [ "$P_OK" -eq 1 ]; then
    # Token 32-byte hex dari /dev/urandom
    TOKEN=$(cat /dev/urandom 2>/dev/null | head -c 32 | od -An -tx1 | tr -d ' \n')
    [ -z "$TOKEN" ] && TOKEN="$(date +%s)$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null)$$"
    rm -f "$RL_FILE"
    printf "OK:%s" "$TOKEN"
else
    sleep 1
    printf "FAIL"
fi
AUTHEOF
chmod 750 "$INSTALL_PATH/auth.cgi"
chown root:root "$INSTALL_PATH/auth.cgi" 2>/dev/null

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
    [ -f "$INSTALL_PATH/halt-wait.html" ] && cp "$INSTALL_PATH/halt-wait.html" "$NGINX_PATH/static/"

    # mime.types
    cat > "$NGINX_PATH/mime.types" << 'MIMEEOF'
types {
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

    # nginx.conf — security hardened + performance tuned untuk router
    # Kompatibel dengan semua 96 .asp dan 5 .jsx dari /www FreshTomato
    cat > "$NGINX_PATH/nginx.conf" << NGINXEOF
user nobody;
worker_processes 1;
pid /tmp/nginx.pid;
error_log /tmp/nginx_error.log warn;

events {
    worker_connections 64;
    use epoll;
    multi_accept on;
}

http {
    server_tokens off;
    access_log off;
    default_type text/html;
    include $NGINX_PATH/mime.types;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 15s;
    keepalive_requests 100;

    # Upstream keepalive ke httpd:8008
    upstream httpd_upstream {
        server $LAN_IP:8008 max_fails=3 fail_timeout=10s;
        keepalive 2;
        keepalive_timeout 10s;
        keepalive_requests 50;
    }

    # Proxy settings — buffer kecil untuk router dengan RAM terbatas
    proxy_connect_timeout  5s;
    proxy_send_timeout     15s;
    proxy_read_timeout     30s;
    proxy_buffer_size      4k;
    proxy_buffers          4 8k;
    proxy_busy_buffers_size 16k;
    proxy_temp_path        /tmp/nginx_proxy 1 2;
    proxy_next_upstream    error timeout http_502 http_503;
    proxy_next_upstream_tries 2;
    proxy_next_upstream_timeout 8s;

    # Gzip — hemat bandwidth
    gzip on;
    gzip_min_length 512;
    gzip_comp_level 2;
    # text/plain penting untuk update.cgi (log data bisa ratusan KB, kompres 80-90%)
    gzip_types text/css text/plain application/javascript application/json image/svg+xml;
    gzip_vary on;
    # KRITIS: aktifkan gzip untuk response dari upstream (httpd:8008)
    # Tanpa ini gzip TIDAK aktif untuk .asp, update.cgi, dll — hanya file statis
    gzip_proxied any;

    # Rate limit zones
    limit_req_zone \$binary_remote_addr zone=login:512k rate=5r/m;
    limit_req_zone \$binary_remote_addr zone=api:512k   rate=30r/s;

    # Cache zone untuk update.cgi polling (log, bandwidth, dll)
    # FreshTomato default refresh = 1 detik, log bisa ratusan KB per poll
    # Cache 2 detik: browser poll 1x/detik tapi httpd hanya dipanggil 1x/2detik
    # max_size=2m: cukup untuk beberapa exec= types, inactive=3s: auto-evict
    proxy_cache_path /tmp/nginx_log_cache levels=1 keys_zone=log_cache:512k max_size=2m inactive=3s use_temp_path=off;

    # Map X-Login-Auth header dari login.html → Authorization ke httpd
    # login.html kirim X-Login-Auth: Basic base64(user:pass)
    # nginx teruskan sebagai Authorization: Basic base64(user:pass)
    # Semua .asp FreshTomato butuh header ini untuk autentikasi httpd
    map \$http_x_login_auth \$auth_header {
        default       "Basic $B64";
        "~^Basic .+"  \$http_x_login_auth;
    }

    server {
        listen 80;
        root $NGINX_PATH/static;

        # Security headers untuk semua response
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Block dotfiles (.passwd, dll)
        location ~ /\. { deny all; return 404; }

        # Block PHP — adminer.php dan phpinfo.php ada di /www, berbahaya jika diakses
        location ~* \.php$ { deny all; return 404; }

        # Logout — intercept semua URL yang mengandung /logout
        # logout.asp di /www tetap ada tapi nginx clear cookie dulu
        location ~* ^.*/logout(\.asp)?$ {
            add_header Set-Cookie "ft_auth=; Path=/; Max-Age=0; SameSite=Lax" always;
            return 302 /login.html?logout=1;
        }

        # Login page — rate limited, no cache
        location = /login.html {
            limit_req zone=login burst=10 nodelay;
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
            add_header Pragma "no-cache" always;
            try_files \$uri =404;
        }

        # Root "/" — cek cookie, proxy atau redirect ke login
        location = / {
            set \$do_login "1";
            if (\$cookie_ft_auth) { set \$do_login "0"; }
            if (\$do_login = "1") { rewrite ^ /login.html last; }
            proxy_pass http://httpd_upstream;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        # bgmp4.gif — serve sebagai video/mp4 dengan cache panjang
        location = /bgmp4.gif {
            default_type video/mp4;
            add_header Cache-Control "public, max-age=86400, immutable" always;
            add_header Accept-Ranges bytes always;
            try_files \$uri =404;
        }

        # reboot-wait.html & halt-wait.html — HARUS sebelum *.html generic
        # Hanya bisa diakses jika sudah ada cookie ft_auth
        location ~ ^/(reboot|halt)-wait\.html$ {
            set \$rw_auth "0";
            if (\$cookie_ft_auth) { set \$rw_auth "1"; }
            if (\$rw_auth = "0") { return 302 /login.html; }
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
            try_files \$uri =404;
        }

        # status-log.asp — optimized untuk log polling
        # Masalah: user set refresh 1 detik, tiap poll bisa kirim ratusan KB log
        # proxy_buffering off (sebelumnya) = nginx block sampai semua data diterima
        # Fix: buffering ON + buffer besar (32k) + gzip text/plain + timeout wajar
        # Ini juga berlaku untuk update.cgi (exec=showlog) yang dipakai TomatoRefresh
        location = /status-log.asp {
            limit_req zone=api burst=50 nodelay;
            proxy_pass http://httpd_upstream;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_read_timeout     60s;
            proxy_send_timeout     60s;
            # Buffer log response di nginx dulu, baru kirim ke client sekaligus
            proxy_buffering        on;
            proxy_buffer_size      8k;
            proxy_buffers          8 32k;
            proxy_busy_buffers_size 64k;
            proxy_cache            off;
        }

        # update.cgi — endpoint polling SEMUA halaman realtime FreshTomato
        # POST body berisi exec= parameter: showlog, netdev, bandwidth, dll
        # Default FreshTomato: 1 detik refresh → ratusan KB per detik
        # Fix: cache response 2 detik per-user per-exec-type
        #   → browser boleh poll 1x/detik tapi httpd hanya dipanggil 1x/2detik
        #   → beban httpd turun 50%, response terasa lebih cepat (dari cache)
        location = /update.cgi {
            # Baca request body SEBELUM proxy — butuh untuk cache key
            proxy_pass_request_body on;

            # Cache POST response — key = user identity + exec type
            proxy_cache            log_cache;
            proxy_cache_methods    POST;
            proxy_cache_key        "\$http_authorization:\$request_body";
            proxy_cache_valid      200 2s;
            proxy_cache_valid      any 0s;
            # Abaikan Cache-Control dari httpd yang mungkin set no-cache
            proxy_ignore_headers   Cache-Control Expires Set-Cookie;
            # Lock: jika cache miss, hanya 1 request ke httpd — sisanya tunggu
            proxy_cache_lock       on;
            proxy_cache_lock_timeout 3s;
            # Header cache status (untuk debug: HIT/MISS/BYPASS)
            add_header X-Cache-Status \$upstream_cache_status always;

            proxy_pass http://httpd_upstream;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_read_timeout     30s;
            proxy_send_timeout     15s;
            proxy_buffering        on;
            proxy_buffer_size      8k;
            proxy_buffers          8 32k;
            proxy_busy_buffers_size 64k;
        }

        # Static assets — cache 10 menit
        location ~* \.(css|js|png|jpg|jpeg|ico|svg|woff|woff2|gif)$ {
            add_header Cache-Control "public, max-age=600" always;
            try_files \$uri @proxy;
        }

        # HTML statis — no cache
        location ~* \.html$ {
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
            try_files \$uri @proxy;
        }

        # .asp, .jsx, dan .cgi — semua dari /www lewat httpd
        # .cgi bisa ada di ext/cgi-bin atau user/cgi-bin
        location ~* \.(asp|jsx|cgi)$ {
            limit_req zone=api burst=50 nodelay;
            proxy_pass http://httpd_upstream;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        # Semua lain → proxy ke httpd:8008
        location / {
            proxy_pass http://httpd_upstream;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        location @proxy {
            proxy_pass http://httpd_upstream;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        error_page 401 403 404 /login.html;
    }
}
NGINXEOF

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

# 4. NGINX: start ulang dengan config dari JFFS
mkdir -p /var/log/nginx /var/lib/nginx/client /var/lib/nginx/proxy
mkdir -p /tmp/nginx_log_cache  # cache zone untuk update.cgi polling
mkdir -p /tmp/nginx_log_cache  # cache zone untuk update.cgi polling
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
if [ -f "$SAFE_PATH/reboot-wait.html" ]; then
    cp "$SAFE_PATH/reboot-wait.html" "$SAFE_NGINX/static/reboot-wait.html" 2>/dev/null
    # Inject http_id yang fresh setiap boot
    _ID=$(nvram get http_id 2>/dev/null)
    sed -i "s/FT_HTTP_ID/$_ID/g" "$SAFE_NGINX/static/reboot-wait.html" 2>/dev/null
fi
[ -f "$SAFE_PATH/halt-wait.html" ] && cp "$SAFE_PATH/halt-wait.html" "$SAFE_NGINX/static/halt-wait.html" 2>/dev/null

# 6. SSH CREDENTIALS: /etc/passwd + /etc/shadow di-reset tiap boot dari tmpfs
#    restore dari .passwd yang tersimpan permanen di /jffs/mywww
_F="$SAFE_PATH/.passwd"
_U=$(cut -d: -f1 "$_F" 2>/dev/null)
_P=$(cut -d: -f2- "$_F" 2>/dev/null)

if [ -n "$_P" ]; then
    # MD5-crypt: satu-satunya format yang didukung dropbear FreshTomato
    _H=$(printf '%s' "$_P" | openssl passwd -1 -stdin 2>/dev/null)
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

# 8. FINAL SHADOW RESTORE
# FreshTomato preinit kadang override /etc/shadow dari nvram http_passwd
# setelah boot.sh kita selesai. Baca nvram → hash MD5-crypt → tulis shadow
# lagi untuk memastikan dropbear bisa login dengan password yang benar.
_PLAIN=$(nvram get http_passwd 2>/dev/null)
if [ -n "$_PLAIN" ]; then
    _H2=$(printf '%s' "$_PLAIN" | openssl passwd -1 -stdin 2>/dev/null)
    if [ -n "$_H2" ]; then
        grep -v "^root:" /etc/shadow > /tmp/shadow.tmp 2>/dev/null || true
        echo "root:${_H2}:18000:0:99999:7:::" >> /tmp/shadow.tmp
        cp /tmp/shadow.tmp /etc/shadow
        rm -f /tmp/shadow.tmp
        killall -9 dropbear 2>/dev/null
        sleep 1
        service sshd start >/dev/null 2>&1
    fi
fi
unset _PLAIN _H2
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
# sleep 25: tunggu FreshTomato preinit selesai (~15-20s) sebelum boot.sh jalan
BOOT_BLOCK="$MARKER_START
sleep 25
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
