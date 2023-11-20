#!/bin/bash
/usr/bin/vmhgfs-fuse .host:/ /root/shared -o subtype=vmhgfs-fuse,allow_other
