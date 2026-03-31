#!/bin/sh
# upload-bg.cgi — FreshTomato Theme background uploader
# Receives multipart/form-data POST, saves file as bgmp4.gif
# Returns JSON: {"ok":true} or {"ok":false,"error":"..."}

# Paths
WWW_PATH="/jffs/Theme/www"
NGINX_STATIC="/jffs/Theme/nginx/static"
TMP_UPLOAD="/tmp/ft_bg_upload"
TARGET="bgmp4.gif"

json_ok()    { printf 'Content-Type: application/json\r\n\r\n{"ok":true}'; }
json_fail()  { printf 'Content-Type: application/json\r\n\r\n{"ok":false,"error":"%s"}' "$1"; }

# Only POST allowed
[ "$REQUEST_METHOD" != "POST" ] && { json_fail "Method not allowed"; exit 0; }

# Check content type is multipart
case "$CONTENT_TYPE" in
    multipart/form-data*) ;;
    *) json_fail "Invalid content type"; exit 0 ;;
esac

# Extract boundary from Content-Type
BOUNDARY=$(printf '%s' "$CONTENT_TYPE" | sed -n 's/.*boundary=//p' | tr -d '\r\n ')
[ -z "$BOUNDARY" ] && { json_fail "No boundary found"; exit 0; }

# Read POST body to temp file
mkdir -p /tmp
cat > "$TMP_UPLOAD.raw"

# Extract file content: skip headers (everything before first blank line after boundary)
# Use awk to find the file data between multipart boundaries
awk -v bnd="$BOUNDARY" '
BEGIN { found=0; skip_headers=0; RS="\r\n" }
{
    if (index($0, bnd) > 0) {
        if (found) exit
        found=1; skip_headers=1; next
    }
    if (found && skip_headers) {
        if ($0 == "" || $0 == "\r") { skip_headers=0; next }
        next
    }
    if (found && !skip_headers) { print }
}
' "$TMP_UPLOAD.raw" > "$TMP_UPLOAD.tmp"

# Remove trailing boundary line (last 2 bytes \r\n before boundary)
FSIZE=$(wc -c < "$TMP_UPLOAD.tmp")
[ "$FSIZE" -lt 8 ] && { rm -f "$TMP_UPLOAD.raw" "$TMP_UPLOAD.tmp"; json_fail "Empty or invalid file"; exit 0; }

# Trim trailing \r\n--boundary--\r\n from binary
# Use dd to cut the last few bytes that contain the boundary marker
# The trailing data is: \r\n--BOUNDARY--\r\n (length = 4 + boundary_len + 4)
BLEN=${#BOUNDARY}
TAIL_LEN=$((BLEN + 8))
CLEAN_SIZE=$((FSIZE - TAIL_LEN))
[ "$CLEAN_SIZE" -lt 4 ] && CLEAN_SIZE=$FSIZE
dd if="$TMP_UPLOAD.tmp" of="$TMP_UPLOAD.file" bs=1 count="$CLEAN_SIZE" 2>/dev/null

# Validate magic bytes: MP4 (ftyp at offset 4) or GIF (GIF8 at offset 0)
MAGIC4=$(dd if="$TMP_UPLOAD.file" bs=1 skip=4 count=4 2>/dev/null)
MAGIC_GIF=$(dd if="$TMP_UPLOAD.file" bs=1 count=4 2>/dev/null)

VALID=0
case "$MAGIC4" in ftyp) VALID=1 ;; esac
case "$MAGIC_GIF" in GIF8) VALID=1 ;; esac

if [ "$VALID" -eq 0 ]; then
    rm -f "$TMP_UPLOAD.raw" "$TMP_UPLOAD.tmp" "$TMP_UPLOAD.file"
    json_fail "Invalid file format (only MP4 or GIF allowed)"
    exit 0
fi

# Check file size (max 50MB = 52428800 bytes)
ACTUAL_SIZE=$(wc -c < "$TMP_UPLOAD.file")
[ "$ACTUAL_SIZE" -gt 52428800 ] && {
    rm -f "$TMP_UPLOAD.raw" "$TMP_UPLOAD.tmp" "$TMP_UPLOAD.file"
    json_fail "File too large (max 50MB)"
    exit 0
}

# Save to both locations
cp "$TMP_UPLOAD.file" "$WWW_PATH/$TARGET" 2>/dev/null
cp "$TMP_UPLOAD.file" "$NGINX_STATIC/$TARGET" 2>/dev/null

# Set permissions
chmod 644 "$WWW_PATH/$TARGET" 2>/dev/null
chmod 644 "$NGINX_STATIC/$TARGET" 2>/dev/null

# Cleanup
rm -f "$TMP_UPLOAD.raw" "$TMP_UPLOAD.tmp" "$TMP_UPLOAD.file"

# Verify at least one copy succeeded
if [ -f "$WWW_PATH/$TARGET" ] || [ -f "$NGINX_STATIC/$TARGET" ]; then
    json_ok
else
    json_fail "Failed to save file"
fi
