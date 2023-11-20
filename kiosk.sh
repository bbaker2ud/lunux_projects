#!/bin/bash

updates="/root/scripts/updates.sh" &&
autostart="/etc/xdg/openbox/autostart" &&
echo "Creating /root/scripts directory..." &&
mkdir /root/scripts ||
echo "Creating updates.sh..." &&
touch $updates &&
echo "Changing permissions..." &&
chmod a+x $updates &&
echo "Building script..." &&
echo "#!/bin/bash" >> $updates &&
echo "apt-get update && apt-get -y dist-upgrade && apt-get -y autoremove" >> $updates && 
echo "Running updates.sh..." &&
$updates &&
echo "apt-get install python2 -y" &&

echo "apt-get install -y xorg xserver-xorg x11-xserver-utils xinit openbox" &&
echo "useradd -m kiosk-user" &&
echo "passwd -d kiosk-user" &&


echo "xfce-mcs-manager &" >> $autostart &&
echo "# Disable any form of screen saver / screen blanking / power management" >> $autostart &&
echo "xset s off" >> $autostart &&
echo "xset s noblank" >> $autostart &&
echo "xset -dpms" >> $autostart &&
echo "# Allow quitting the X server with CTRL-ATL-Backspace" >> $autostart &&
echo "setxkbmap -option terminate:ctrl_alt_bksp" >> $autostart &&
echo "# Disable switching to a virtual terminal" >> $autostart &&
echo "setxkbmap -option srvrkeys:none" >> $autostart &&
echo "vmware-view --serverURL=vdigateway.udayton.edu --fullscreen --usbAutoConnectOnInsert="TRUE" --allSessionsDisconnectedBehavior="Logoff" --nomenubar" >> $autostart &&

echo "mkdir Downloads" &&
echo "cd Downloads" &&
echo 'wget "https://download3.vmware.com/software/CART24FQ2_LIN64_2306/VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle"' &&
echo "env TERM=dumb \ " &&
echo "sh ./VMware-Horizon-Client-YYMM-x.x.x-yyyyyyy.arch.bundle --console --required" &&
echo "ufw enable" &&
echo "ufw allow ssh" &&


update & upgrade - 
install python2
reboot
install xorg as well as others
use sudo sh ./.......... for installer
