#!/bin/sh
# Loop: listen di port 8009, hanya reboot jika request mengandung secret token
SECRET="ft-do-reboot-$(cat /jffs/mywww/.passwd 2>/dev/null | md5sum | cut -c1-8)"

while true; do
    REQUEST=$(awk 'BEGIN{
        srv = "/inet/tcp/8009/0/0"
        while((srv |& getline line) > 0) {
            if(line == "\r" || line == "") break
            print line
        }
        print "HTTP/1.1 200 OK\r"              |& srv
        print "Content-Type: text/plain\r"     |& srv
        print "Content-Length: 2\r"            |& srv
        print "Connection: close\r"            |& srv
        print "\r"                             |& srv
        print "OK"                             |& srv
        close(srv)
    }' 2>/dev/null)

    # Hanya reboot jika URL mengandung secret token
    if echo "$REQUEST" | grep -q "$SECRET"; then
        sleep 1
        reboot
        exit 0
    fi
    # Request lain: loop lagi, listen koneksi berikutnya
done
