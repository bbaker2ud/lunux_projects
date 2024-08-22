#!/bin/bash
autostart="/etc/xdg/openbox/autostart" &&
apt install -y xorg xserver-xorg x11-xserver-utils xinit openbox &&
echo -e "\nxset s off\n\nxset s noblank\n\nxset -dpms\n\nsetxkbmap -option terminate:ctrl_alt_bksp\n\n#setxkbmap -option srvrkeys:none" >> $autostart
echo -e "\n\nvmware-view --serverURL=vdigateway.udayton.edu --fullscreen --nomenubar --allSessionsDisconnectedBehavior='Logoff' --usbAutoConnectOnInsert='TRUE'" >> $autostart
env TERM=dumb ./VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle --console --required &&
rm VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle 
