#!/bin/bash
#Run as root

BASH_PROFILE="/root/.bash_profile"
PROFILE="./script.sh"
STATUS_LOG="/root/status.log"

# Determine whether the .bash_profile file exists ? get the profile : set the profile 
if [[ -f $BASH_PROFILE ]]
then
        CURRENT_PROFILE="$(cat "$PROFILE")"
else
        CURRENT_PROFILE="./script.sh"
        echo "$BASH_PROFILE : $(date)"
        echo "$CURRENT_PROFILE" > "$BASH_PROFILE"
fi

# Determine whether the log file exists ? get the status : set status0
if [[ -f $STATUS_LOG ]]
then
        CURRENT_STATUS="$(cat "$STATUS_LOG")"
else
        CURRENT_STATUS="stage0"
        echo "$CURRENT_STATUS : $(date)"
        echo "$CURRENT_STATUS" > "$STATUS_LOG"
fi

# Define your actions as functions

# This function is not currently in use
setupAutoLogin() 
{
        passwd -d root &&
        mkdir /etc/systemd/system/getty@tty1.service.d/ &&
        file="/etc/systemd/system/getty@tty1.service.d/override.conf"root
        touch $file &&
        echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --noissue --autologin root %I \$TERM" > $file
}

update()
{
        updates="/root/scripts/updates.sh" &&
        echo "Creating /root/scripts directory..." &&
        mkdir /root/scripts ||
        echo "Creating updates.sh..." &&
        touch $updates && 
        echo "Changing permissions..." &&
        chmod a+x $updates &&
        echo "Building script..." &&
        echo "#!/bin/bash" >> $updates &&
        echo "apt update && apt -y dist-upgrade && apt -y autoremove" >> $updates &&
        echo "Running updates.sh..." &&
        $updates &&
        CURRENT_STATUS="stage1"
        echo "$CURRENT_STATUS : $(date)"
        echo "$CURRENT_STATUS" > "$STATUS_LOG"
        echo "Updates finished. Rebooting now."
        sleep 3 &&
        reboot
}

installDisplayManagerComponents()
{
        autostart="/etc/xdg/openbox/autostart" &&
        apt install -y xorg xserver-xorg x11-xserver-utils xinit openbox &&
        echo -e "\nxset s off\n\nxset s noblank\n\nxset -dpms\n\nsetxkbmap -option terminate:ctrl_alt_bksp\n\n#setxkbmap -option srvrkeys:none" >> $autostart
        echo -e "\n\nvmware-view --serverURL=vdigateway.udayton.edu --fullscreen --nomenubar --allSessionsDisconnectedBehavior='Logoff' --usbAutoConnectOnInsert='TRUE'" >> $autostart
        CURRENT_STATUS="stage3"
        echo "$CURRENT_STATUS : $(date)"
        echo "$CURRENT_STATUS" > "$STATUS_LOG"
        echo "Display Manager Components installed."
        sleep 3
}

installVMwareHorizonClient()
{
        wget https://download3.vmware.com/software/CART24FQ2_LIN64_2306/VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle &&
        chmod +x VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle
        env TERM=dumb ./VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle --console --required &&
        echo "VMware Horizon Client installed."
        rm VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle &&
        sleep 3
}

installOpenSSH()
{
        apt install openssh-server -y &&
        ufw enable &&
        ufw allow ssh &&
        echo "SSH enabled and configured."
        sleep 3
}

reconfigureBashProfile()
{
        echo "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec startx" > $BASH_PROFILE
        echo ".bash_profile reconfigured."
        sleep 3 &&
        reboot
}
case "$CURRENT_STATUS" in
stage0)
  update
  ;;
stage1)
  installDisplayManagerComponents
  installVMwareHorizonClient
  reconfigureBashProfile
  ;;
stage2)
  ;;
stage3)
  echo "The script '$0' is finished."
  ;;
*)
  echo "Something went wrong!"
  ;;
esac
