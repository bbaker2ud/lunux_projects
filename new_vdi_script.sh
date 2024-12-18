#!/bin/bash
# Run as root

BASH_PROFILE="/root/.bash_profile"
STATUS_LOG="/root/status.log"
SCRIPT_DIR="/root/scripts"
UPDATES_SCRIPT="${SCRIPT_DIR}/updates.sh"

# Initialize .bash_profile
if [[ ! -f $BASH_PROFILE ]]; then
    echo "Initializing .bash_profile"
    echo ".bash_profile created on $(date)" > "$BASH_PROFILE"
fi

# Initialize status log
if [[ ! -f $STATUS_LOG ]]; then
    echo "Initializing status log"
    echo "stage0 : $(date)" > "$STATUS_LOG"
fi

# Load current status
CURRENT_STATUS=$(awk '{print $1}' "$STATUS_LOG")

# Define functions
setupAutoLogin() {
    passwd -d root
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    local file="/etc/systemd/system/getty@tty1.service.d/override.conf"
    echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --noissue --autologin root %I \$TERM" > "$file"
}

update() {
    echo "Updating system..."
    mkdir -p "$SCRIPT_DIR"
    cat <<EOF > "$UPDATES_SCRIPT"
#!/bin/bash
apt update && apt -y dist-upgrade && apt -y autoremove
EOF
    chmod +x "$UPDATES_SCRIPT"
    "$UPDATES_SCRIPT"
    CURRENT_STATUS="stage1"
    echo "$CURRENT_STATUS : $(date)" > "$STATUS_LOG"
    echo "Updates finished. Rebooting now."
    sync
    reboot
}

installDisplayManagerComponents() {
    echo "Installing display manager components..."
    apt install -y xorg xserver-xorg x11-xserver-utils xinit openbox
    mkdir -p /etc/xdg/openbox/
    local autostart="/etc/xdg/openbox/autostart"
    cat <<EOF >> "$autostart"
xrandr -s 1920x1080
xset s off
xset s noblank
xset -dpms
setxkbmap -option terminate:ctrl_alt_bksp
#setxkbmap -option srvrkeys:none
vmware-view --serverURL=vdigateway.udayton.edu --fullscreen --nomenubar --allSessionsDisconnectedBehavior='Logoff' --usbAutoConnectOnInsert='TRUE'
EOF
    CURRENT_STATUS="stage2"
    echo "$CURRENT_STATUS : $(date)" > "$STATUS_LOG"
    echo "Display Manager Components installed."
}

installVMwareHorizonClient() {
    echo "Installing VMware Horizon Client..."
    local client="VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle"
    wget -q https://download3.vmware.com/software/CART24FQ2_LIN64_2306/"$client"
    chmod +x "$client"
    env TERM=dumb ./"$client" --console --required
    rm -f "$client"
    echo "VMware Horizon Client installed."
}

installOpenSSH() {
    echo "Installing and configuring OpenSSH..."
    apt install openssh-server -y
    ufw enable
    ufw allow ssh
    echo "SSH enabled and configured."
}

reconfigureBashProfile() {
    echo "Reconfiguring .bash_profile..."
    echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$BASH_PROFILE"
    echo ".bash_profile reconfigured."
    sync
    reboot
}

# Main execution flow
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
        installOpenSSH
        ;;
    stage3)
        echo "The script '$0' has completed all stages."
        ;;
    *)
        echo "Unknown status. Exiting."
        ;;
esac
