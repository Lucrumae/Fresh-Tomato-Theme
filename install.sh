#!/bin/sh

# FreshTomato Theme Installer & Auto-Init Persistence
# Theme: BocchiTheRockTheme
# Repository: https://github.com/Lucrumae/Fresh-Tomato-Theme

echo "----------------------------------------"
echo "  Starting BocchiTheRockTheme Install   "
echo "----------------------------------------"

# --- CONFIGURATION & ESTIMATIONS ---
# URL pointing to the folder inside the main branch
REPO_RAW_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/BocchiTheRockTheme"
TMP_DIR="/tmp/BocchiTheRockTheme"
ESTIMATED_THEME_KB=46080 # ~45MB
MIN_TOTAL_RAM_KB=126000 # Requirement for 128MB RAM

# 1. TOTAL RAM REQUIREMENT CHECK
TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')

if [ "$TOTAL_RAM" -lt "$MIN_TOTAL_RAM_KB" ]; then
    echo "ERROR: Your router does not meet the RAM requirement."
    echo "This theme requires at least 128MB of RAM to handle large assets (40MB+)."
    echo "Your Total RAM: $(echo $TOTAL_RAM | awk '{print $1/1024}')MB"
    echo "Installation aborted."
    exit 1
fi

# 2. PRE-INSTALL RAM SPACE CHECK (/tmp)
FREE_RAM=$(df -k /tmp | awk 'NR==2 {print $4}')

if [ "$FREE_RAM" -lt "$ESTIMATED_THEME_KB" ]; then
    echo "ERROR: Not enough free space on /tmp!"
    echo "Looks like your RAM needs to be cleaned or is too full."
    echo "Available RAM space: $(echo $FREE_RAM | awk '{print $1/1024}')MB"
    echo "Required space: ~45MB"
    echo "----------------------------------------"
    exit 1
fi

# 3. JFFS MOUNT VERIFICATION
if ! mount | grep -q "/jffs"; then
    echo "ERROR: JFFS is not mounted!"
    echo "Please enable and format JFFS in 'Administration > JFFS' first."
    echo "Installation aborted."
    exit 1
fi

# 4. CHECK FOR PREVIOUS INSTALLATION
if [ -d "/jffs/mywww" ]; then
    echo "Warning: /jffs/mywww directory already exists."
    printf "Do you want to reinstall? (y/n): "
    read choice
    if [ "$choice" != "y" ]; then
        echo "Installation aborted by user."
        exit 1
    fi
    echo "Cleaning up old installation..."
    umount -l /www 2>/dev/null
    rm -rf /jffs/mywww
fi

# 5. DIRECTORY PREPARATION & SYSTEM COPY
echo "[1/6] Preparing /jffs/mywww..."
mkdir -p /jffs/mywww
echo "[2/6] Copying original system files (this may take a moment)..."
cp -rn /www/* /jffs/mywww/

# 6. DOWNLOAD ASSETS FROM GITHUB
rm -rf $TMP_DIR
mkdir -p $TMP_DIR
echo "[3/6] Downloading assets from BocchiTheRockTheme folder..."
wget -qO $TMP_DIR/default.css "$REPO_RAW_URL/default.css"
wget -qO $TMP_DIR/logol.png "$REPO_RAW_URL/logol.png"
wget -qO $TMP_DIR/logor.png "$REPO_RAW_URL/logor.png"
wget -qO $TMP_DIR/bg.gif "$REPO_RAW_URL/bg.gif"

# 7. FINAL STORAGE CHECK (JFFS)
THEME_SIZE=$(du -sk $TMP_DIR | awk '{print $1}')
FREE_JFFS=$(df -k /jffs | awk 'NR==2 {print $4}')

if [ "$FREE_JFFS" -lt "$THEME_SIZE" ]; then
    REQ_MB=$(echo $THEME_SIZE | awk '{printf "%.2f", $1/1024}')
    echo "ERROR: Not enough space on JFFS!"
    echo "This theme needs approximately ${REQ_MB}MB space."
    echo "Installation aborted."
    exit 1
else
    echo "[4/6] Space check passed. Applying assets to JFFS..."
    cp -f $TMP_DIR/* /jffs/mywww/
    rm -rf $TMP_DIR
fi

# 8. PERSISTENCE CONFIGURATION
echo "[5/6] Configuring Auto-mount in Init script..."
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
    echo "      Init script updated."
fi

# 9. ACTIVATION
echo "[6/6] Activating theme immediately..."
mount --bind /jffs/mywww /www
service httpd restart
echo "----------------------------------------"
echo " INSTALLATION COMPLETE!                 "
echo " Refresh your browser to see the theme. "
echo "----------------------------------------"
