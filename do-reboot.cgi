#!/bin/sh
printf "Content-Type: text/plain\r\n\r\n"
printf "OK"
(sleep 1 && reboot) &
