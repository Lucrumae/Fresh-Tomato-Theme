#!/bin/sh
printf "Content-Type: text/plain\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
printf "OK"
echo "1" > /tmp/ft_reboot_flag
