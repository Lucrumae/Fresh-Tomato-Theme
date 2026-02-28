#!/bin/sh
printf "Content-Type: text/plain\r\n\r\n"
printf "OK"
# Tulis flag file — reboot-listener.sh akan baca dan eksekusi reboot
echo "1" > /tmp/ft_reboot_flag
