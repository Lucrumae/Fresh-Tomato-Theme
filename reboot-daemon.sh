#!/bin/sh
# Poll /tmp/ft_reboot_now setiap detik, reboot jika ada
rm -f /tmp/ft_reboot_now
while true; do
    [ -f /tmp/ft_reboot_now ] && rm -f /tmp/ft_reboot_now && sleep 1 && reboot && exit
    sleep 1
done
