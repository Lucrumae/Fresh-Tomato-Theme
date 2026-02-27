#!/bin/sh
printf "Content-Type: text/plain\r\n\r\n"

POST=$(cat)

USER=$(echo "$POST" | sed 's/&/\n/g' | grep '^user=' | cut -d= -f2-)
PASS=$(echo "$POST" | sed 's/&/\n/g' | grep '^pass=' | cut -d= -f2-)

CRED=$(cat /jffs/mywww/.passwd 2>/dev/null || cat /www/.passwd 2>/dev/null)
STORED_U="${CRED%%:*}"
STORED_P="${CRED#*:}"

if [ -n "$USER" ] && [ "$USER" = "$STORED_U" ] && [ "$PASS" = "$STORED_P" ]; then
    TOKEN=$(date +%s)$$
    printf "OK:%s" "$TOKEN"
else
    printf "FAIL"
fi
