#!/bin/sh
printf "Content-Type: text/plain\r\n\r\n"

# Verifikasi Authorization header (Basic Auth)
# HTTP_AUTHORIZATION di-set oleh httpd dari header Authorization
AUTH="$HTTP_AUTHORIZATION"

# Jika tidak ada dari env, coba baca dari header lain
[ -z "$AUTH" ] && AUTH="$HTTP_X_LOGIN_AUTH"

# Decode base64 credentials
if [ -n "$AUTH" ]; then
    ENCODED=$(echo "$AUTH" | sed 's/^Basic //')
    DECODED=$(echo "$ENCODED" | base64 -d 2>/dev/null)
    INPUT_U="${DECODED%%:*}"
    INPUT_P="${DECODED#*:}"
else
    INPUT_U=""
    INPUT_P=""
fi

# Baca stored credentials
CRED=$(cat /jffs/mywww/.passwd 2>/dev/null || cat /www/.passwd 2>/dev/null)
STORED_U="${CRED%%:*}"
STORED_P="${CRED#*:}"

# Verifikasi
if [ -n "$INPUT_U" ] && [ "$INPUT_U" = "$STORED_U" ] && [ "$INPUT_P" = "$STORED_P" ]; then
    printf "OK"
    # Reboot setelah 1 detik (beri waktu response terkirim ke browser)
    (sleep 1 && reboot) &
else
    printf "FAIL"
fi
