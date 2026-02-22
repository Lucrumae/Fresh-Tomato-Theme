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
echo "[1/7] Preparing /jffs/mywww..."
mkdir -p /jffs/mywww
cp -rn /www/* /jffs/mywww/

# 5. DOWNLOAD ASSETS WITH AUTO-RETRY
rm -rf $TMP_DIR
mkdir -p $TMP_DIR
echo "[2/7] Downloading assets from GitHub..."

FILES="default.css logol.png logor.png bg.gif"
MAX_RETRIES=3

for FILE in $FILES; do
    RETRY_COUNT=0
    SUCCESS=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        echo "      Downloading $FILE (Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)..."
        wget -qO $TMP_DIR/$FILE "$REPO_RAW_URL/$FILE"
        
        # Cek apakah file ada dan tidak kosong
        if [ -s "$TMP_DIR/$FILE" ]; then
            SUCCESS=true
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "      Failed to download $FILE. Retrying in 5 seconds..."
            rm -f $TMP_DIR/$FILE
            sleep 5
        fi
    done

    if [ "$SUCCESS" = false ]; then
        echo "ERROR: Failed to download $FILE after $MAX_RETRIES attempts."
        echo "Installation aborted. Please check your internet connection."
        rm -rf $TMP_DIR
        exit 1
    fi
done

# 6. VALIDATION CHECK (Final Double-Check)
echo "[3/7] Validating all files..."
for FILE in $FILES; do
    if [ ! -s "$TMP_DIR/$FILE" ]; then
        echo "ERROR: Validation failed for $FILE."
        exit 1
    fi
done

# 7. APPLY ASSETS
echo "[4/7] Applying assets to JFFS..."
cp -f $TMP_DIR/* /jffs/mywww/
rm -rf $TMP_DIR

# 8. PERSISTENCE CONFIGURATION
echo "[5/7] Configuring Auto-mount in Init script..."
EXISTING_INIT=$(nvram get script_init)
NEW_INIT_BLOCK="
# --- BocchiTheRockTheme Start ---
sleep 2
attempt=0
max_attempts=24
while [ ! -d /jffs/mywww ] && [ \$attempt -lt \$max_attempts ]; do
    sleep 5
    attempt=\$((attempt + 1))
done
if [ -d /jffs/mywww ]; then
    mount --bind /jffs/mywww /www
    logger \"Custom WWW: /jffs/mywww successfully mounted.\"
    service httpd restart
else
    logger \"Custom WWW: Mount failed, /jffs/mywww not found.\"
fi
# --- BocchiTheRockTheme End ---"

if ! echo "$EXISTING_INIT" | grep -q "BocchiTheRockTheme"; then
    nvram set script_init="$EXISTING_INIT$NEW_INIT_BLOCK"
    nvram commit
fi

# 9. ACTIVATION
echo "[6/7] Activating theme immediately..."
mount --bind /jffs/mywww /www
service httpd restart

echo "----------------------------------------"
echo " INSTALLATION COMPLETE!                 "
echo " Refresh your browser to see the theme. "
echo "----------------------------------------"
