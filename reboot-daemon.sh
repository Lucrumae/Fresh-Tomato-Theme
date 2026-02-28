#!/bin/sh
printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nAccess-Control-Allow-Origin: *\r\n\r\nOK"
sleep 1
reboot
