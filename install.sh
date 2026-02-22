#!/bin/sh

# FreshTomato Theme Installer - Google Drive Edition
# Theme: BocchiTheRockTheme

echo "----------------------------------------"
echo "  Starting BocchiTheRockTheme Install   "
echo "----------------------------------------"

# --- CONFIGURATION ---
REPO_RAW_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/BocchiTheRockTheme"

# ID File bg.gif dari link Google Drive kamu
# Ganti ID di bawah ini jika file di drive kamu berubah
GDRIVE_ID="1vHERv-Dj8qauzwSS1sPrq9Vflhl6A2ue" 
BG_DIRECT_URL="https://docs.google.com/uc?export=download&id=$GDRIVE_ID&confirm=t"

TMP_DIR="/tmp/BocchiTheRockTheme"

# 1. STORAGE & RAM CHECK
FREE_RAM=$(df -k /tmp | awk 'NR==2 {print $4}')
if [ "$FREE_RAM" -lt 25600 ]; then
    echo "ERROR: RAM space too low (Min 25MB free required)."
    exit 1
fi

# 2. JFFS PREPARATION
if ! mount | grep -q "/jffs"; then
    echo "ERROR: JFFS not mounted."
    exit 1
fi

echo "[1/8] Preparing /jffs/mywww..."
if [ -d "/jffs/mywww" ]; then
    umount -l /www 2>/dev/null
    rm -rf /jffs/mywww
fi

mkdir -p /jffs/mywww
cp -rn /www/* /jffs/mywww/

# 3. DOWNLOAD ASSETS
rm -rf $TMP_DIR
mkdir -p $TMP_DIR
cd $TMP_DIR

echo "[2/8] Downloading assets..."

# Download file kecil dari GitHub
for FILE in default.css logol.png logor.png; do
    echo "      Downloading $FILE..."
    wget --no-check-certificate -U "Mozilla/5.0" "$REPO_RAW_URL/$FILE"
done

# Download bg.gif dari Google Drive
echo "      Downloading bg.gif from Google Drive..."
# Menggunakan --no-check-certificate karena BusyBox sering bermasalah dengan SSL Google
wget --no-check-certificate -U "Mozilla/5.0" -O bg.gif "$BG_DIRECT_URL"

# 4. VALIDATION
SIZE=$(du -k "bg.gif" | awk '{print $1}')
if [ "$SIZE" -lt 10000 ]; then
    echo "ERROR: bg.gif download failed or file is too small ($SIZE KB)."
    echo "Please make sure the Google Drive link is set to 'Anyone with the link' (Public)."
    cd /
    exit 1
fi
echo "      bg.gif verified ($((SIZE / 1024)) MB)."

# 5. APPLY TO JFFS
echo "[3/8] Copying files to JFFS..."
cp -f * /jffs/mywww/
cd /
rm -rf $TMP_DIR

# 6. PERSISTENCE (INIT SCRIPT)
echo "[4/8] Setting up NVRAM..."
EXISTING_INIT=$(nvram get script_init)
if ! echo "$EXISTING_INIT" | grep -q "BocchiTheRockTheme"; then
    nvram set script_init="$EXISTING_INIT
sleep 5
mount --bind /jffs/mywww /www
service httpd restart"
    nvram commit
fi

# 7. ACTIVATION
echo "[5/8] Activating Theme..."
mount --bind /jffs/mywww /www
service httpd restart

echo "----------------------------------------"
echo " INSTALLATION COMPLETE!                 "
echo " Refresh your browser (Clear Cache).    "
echo "----------------------------------------"
