#!/bin/sh
# Loop sederhana: cek flag file setiap detik, jika ada → reboot
while true; do
    if [ -f /tmp/ft_reboot_flag ]; then
        rm -f /tmp/ft_reboot_flag
        sleep 1
        reboot
        exit 0
    fi
    sleep 1
done
