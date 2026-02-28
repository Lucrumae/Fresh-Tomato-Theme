#!/bin/sh
# HTTP server via awk /inet/tcp — return valid HTTP response lalu reboot
awk 'BEGIN{
    srv = "/inet/tcp/8009/0/0"
    while((srv |& getline line) > 0) {
        if(line == "\r" || line == "") break
    }
    print "HTTP/1.1 200 OK\r"              |& srv
    print "Content-Type: text/plain\r"     |& srv
    print "Content-Length: 2\r"            |& srv
    print "Access-Control-Allow-Origin: *\r" |& srv
    print "Connection: close\r"            |& srv
    print "\r"                             |& srv
    print "OK"                             |& srv
    close(srv)
}' 2>/dev/null
sleep 1
reboot
