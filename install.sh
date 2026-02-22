#!/bin/sh

# FreshTomato Theme Installer - Google Drive Final Fix
# Theme: BocchiTheRockTheme

echo "----------------------------------------"
echo "  Starting BocchiTheRockTheme Install   "
echo "----------------------------------------"

# --- CONFIGURATION ---
REPO_RAW_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/BocchiTheRockTheme"

# ID File bg.gif dari link drive.google.com/file/d/1qnB82rqI30VZtkSXqgkXSj4pP70FGj39/
GDRIVE_ID="1qnB82rqI30VZtkSXqgkXSj4pP70FGj39"

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
# Paksa unmount dulu jika masih menempel
umount -l /www 2>/dev/null
if [ -d "/jffs/mywww" ]; then
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

# Download bg.gif dari Google Drive (Logic Bypass Virus Scan Warning)
echo "      Downloading bg.gif from Google Drive..."
# Step 1: Ambil cookie konfirmasi untuk file besar
CONFIRM=$(wget --quiet --no-check-certificate --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "https://docs.google.com/uc?export=download&id=$GDRIVE_ID" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')

# Step 2: Download menggunakan cookie tersebut
wget --no-check-certificate -U "Mozilla/5.0" --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$CONFIRM&id=$GDRIVE_ID" -O bg.gif
rm -f /tmp/cookies.txt

# 4. VALIDATION
if [ -f "bg.gif" ]; then
    SIZE=$(du -k "bg.gif" | awk '{print $1}')
else
    SIZE=0
fi

if [ "$SIZE" -lt 10000 ]; then
    echo "ERROR: bg.gif download failed or file is too small ($SIZE KB)."
    echo "Make sure the file in Google Drive is Shared as 'Anyone with the link'."
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
echo "----------------------------------------"
