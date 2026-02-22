#!/bin/sh

# FreshTomato Theme Installer & Auto-Init Persistence
# Theme: BocchiTheRockTheme
# Repository: https://github.com/Lucrumae/Fresh-Tomato-Theme

echo "----------------------------------------"
echo "  Starting BocchiTheRockTheme Install   "
echo "----------------------------------------"

# --- CONFIGURATION ---
REPO_RAW_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/BocchiTheRockTheme"
TMP_DIR="/tmp/BocchiTheRockTheme"
REQUIRED_KB=25600 

# 1. FREE RAM CHECK
FREE_RAM=$(df -k /tmp | awk 'NR==2 {print $4}')
if [ "$FREE_RAM" -lt "$REQUIRED_KB" ]; then
    echo "ERROR: Not enough free space on /tmp!"
    exit 1
fi

# 2. JFFS MOUNT VERIFICATION
if ! mount | grep -q "/jffs"; then
    echo "ERROR: JFFS is not mounted!"
    exit 1
fi

# 3. CHECK FOR PREVIOUS INSTALLATION
if [ -d "/jffs/mywww" ]; then
    echo "Warning: /jffs/mywww directory already exists."
    printf "Do you want to reinstall? (y/n): "
    read choice
    if [ "$choice" != "y" ]; then
        echo "Installation aborted."
        exit 1
    fi
    umount -l /www 2>/dev/null
    rm -rf /jffs/mywww
fi

# 4. PREPARE DIRECTORY
echo "[1/8] Preparing /jffs/mywww..."
mkdir -p /jffs/mywww
cp -rn /www/* /jffs/mywww/

# 5. DOWNLOAD ASSETS (BusyBox Compatible)
rm -rf $TMP_DIR
mkdir -p $TMP_DIR
cd $TMP_DIR

echo "[2/8] Downloading assets from GitHub..."

FILES="default.css logol.png logor.png bg.gif"
MAX_RETRIES=5

for FILE in $FILES; do
    RETRY_COUNT=0
    SUCCESS=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        echo "      Downloading $FILE (Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)..."
        
        # Menggunakan opsi yang HANYA didukung oleh BusyBox wget Anda
        wget --no-check-certificate -c -U "Mozilla/5.0" "$REPO_RAW_URL/$FILE"
        
        if [ -f "$FILE" ]; then
            FILE_SIZE=$(du -k "$FILE" | awk '{print $1}')
        else
            FILE_SIZE=0
        fi

        # Validasi ukuran (bg.gif minimal 10MB)
        if [ "$FILE" = "bg.gif" ]; then
            MIN_SIZE=10240
        else
            MIN_SIZE=1
        fi

        if [ "$FILE_SIZE" -ge "$MIN_SIZE" ]; then
            SUCCESS=true
            echo "      $FILE verified ($((FILE_SIZE / 1024)) MB)."
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "      Error: $FILE too small ($FILE_SIZE KB). Retrying..."
            [ "$FILE_SIZE" -lt 10 ] && rm -f "$FILE"
            sleep 3
        fi
    done

    if [ "$SUCCESS" = false ]; then
        echo "ERROR: Failed to download $FILE."
        cd /
        rm -rf $TMP_DIR
        exit 1
    fi
done

# 6. JFFS STORAGE CHECK
THEME_TOTAL_KB=$(du -sk . | awk '{print $1}')
FREE_JFFS=$(df -k /jffs | awk 'NR==2 {print $4}')
if [ "$FREE_JFFS" -lt "$THEME_TOTAL_KB" ]; then
    echo "ERROR: Not enough space on JFFS!"
    exit 1
fi

# 7. APPLY ASSETS
echo "[3/8] Applying assets to JFFS..."
cp -f * /jffs/mywww/
cd /
rm -rf $TMP_DIR

# 8. PERSISTENCE CONFIGURATION
echo "[4/8] Configuring Auto-mount..."
EXISTING_INIT=$(nvram get script_init)
NEW_INIT_BLOCK="
# --- BocchiTheRockTheme Start ---
sleep 5
if [ -d /jffs/mywww ]; then
    mount --bind /jffs/mywww /www
    service httpd restart
fi
# --- BocchiTheRockTheme End ---"

if ! echo "$EXISTING_INIT" | grep -q "BocchiTheRockTheme"; then
    nvram set script_init="$EXISTING_INIT$NEW_INIT_BLOCK"
    nvram commit
fi

# 9. ACTIVATION
echo "[5/8] Activating theme immediately..."
mount --bind /jffs/mywww /www
service httpd restart

echo "----------------------------------------"
echo " INSTALLATION COMPLETE!                 "
echo "----------------------------------------"
