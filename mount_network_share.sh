#!/bin/bash
echo "Creating /media/share directory..." &&
mkdir /media/share ||
echo "Mounting network share..." &&
mkdir /media/share ||
mount -t cifs -o rw,vers=3.0,username=$username,password=$password //itsmldcs1.adws.udayton.edu/ldlogon/unix /media/share &&
echo "Done."
