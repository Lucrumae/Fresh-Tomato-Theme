#!/bin/sh
printf "Content-Type: text/plain\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
printf "CGI_WORKS user=%s" "$HTTP_USER"
