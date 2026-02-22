# 9. PERSISTENCE CONFIGURATION (INIT SCRIPT)
echo "[5/8] Configuring Auto-mount in Init script..."
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
else
    echo "      Init script already exists. Skipping."
fi

# 10. ACTIVATION
echo "[6/8] Activating theme immediately..."
mount --bind /jffs/mywww /www
service httpd restart

echo "----------------------------------------"
echo " INSTALLATION COMPLETE!                 "
echo " Refresh your browser to see the theme. "
echo "----------------------------------------"
