#!/bin/bash

BASH_PROFILE=".bash_profile"
PROFILE="./script.sh"
STATUS_LOG="status.log"

# Determinate whether the .bash_profile file exists ? get the profile : set the profile 
if [[ -f $BASH_PROFILE ]]
then
        CURRENT_PROFILE="$(cat "$PROFILE")"
else
        CURRENT_PROFILE="./script.sh"
        echo "$BASH_PROFILE : $(date)"
        echo "$CURRENT_PROFILE" > "$BASH_PROFILE"
fi

# Determinate whether the log file exists ? get the status : set status0
if [[ -f $STATUS_LOG ]]
then
        CURRENT_STATUS="$(cat "$STATUS_LOG")"
else
        CURRENT_STATUS="stage0"
        echo "$CURRENT_STATUS : $(date)"
        echo "$CURRENT_STATUS" > "$STATUS_LOG"
fi

# Define your actions as functions
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
        reboot &&
        exit
}

installPython2()
{
        echo "apt install -y python2" &&
        CURRENT_STATUS="stage2"
        echo "$CURRENT_STATUS : $(date)"
        echo "$CURRENT_STATUS" > "$STATUS_LOG"
        echo "Python 2 installed. Rebooting now."
        sleep 3 &&
        reboot &&
        exit
}

installDisplayManagerComponents()
{
        autostart="/etc/xdg/openbox/autostart" &&
        apt install -y xorg xserver-xorg x11-xserver-utils xinit openbox &&
        ##touch $autostart &&
        echo -e "\nxset s off\n\nxset s noblank\n\nxset -dpms\n\nsetxkbmap -option terminate:ctrl_alt_bksp\n\nsetxkbmap -option srvrkeys:none" >> $autostart
        echo -e "\n\nvmware-view --serverURL=vdigateway.udayton.edu --fullscreen --nomenubar --allSessionsDisconnectedBehavior='Logoff' --usbAutoConnectOnInsert='TRUE'"
        CURRENT_STATUS="stage3"
        echo "$CURRENT_STATUS : $(date)"
        echo "$CURRENT_STATUS" > "$STATUS_LOG"
        echo "Display Manager Components installed."
        sleep 3 &&
        exit
}

installVMwareHorizonClient()
{
        echo "wget https://download3.vmware.com/software/CART24FQ2_LIN64_2306/VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle" &&
        echo "env TERM=dumb \ " &&
        echo "sh ./VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle --console --required" &&
        echo "VMware Horizon Client installed."
        sleep 3 &&
        exit
}

installOpenSSH()
{
        echo "apt-get install openssh-server -y" &&
        ufw enable &&
        ufw allow ssh &&
        echo "SSH enabled and configured."
        sleep 3 &&
        exit
}

removeBashProfile()
{
        rm .bash_profile &&
        echo ".bash_profile removed."
        sleep 3 &&
        exit
}
case "$CURRENT_STATUS" in
stage0)
  update
  ;;
stage1)
  installPython2
  ;;
stage2)
  installDisplayManagerComponents
  installVMwareHorizonClient
  installOpenSSH
  removeBashProfile
  ;;
stage3)
  echo "The script '$0' is finished."
  ;;
*)
  echo "Something went wrong!"
  ;;
esac