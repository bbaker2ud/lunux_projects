#!/bin/bash
# Run as root

BASH_PROFILE="/root/.bash_profile"
STATUS_LOG="/root/status.log"
SCRIPT_DIR="/root/scripts"
UPDATES_SCRIPT="${SCRIPT_DIR}/updates.sh"

# Enable root auto-login
configure_auto_login() {
    echo "Configuring root auto-login..."
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF
    systemctl daemon-reload
    echo "Root auto-login configured."
}

# Initialize .bash_profile
if [[ ! -f $BASH_PROFILE ]]; then
    echo "Initializing .bash_profile"
    echo "# .bash_profile created on $(date)" > "$BASH_PROFILE"
    echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec bash /root/scripts/main.sh' >> "$BASH_PROFILE"
fi

# Initialize status log
if [[ ! -f $STATUS_LOG ]]; then
    echo "Initializing status log"
    echo "stage0 : $(date)" > "$STATUS_LOG"
fi

# Load current status
CURRENT_STATUS=$(awk '{print $1}' "$STATUS_LOG")

# Ensure main script is executable and placed in the correct location
MAIN_SCRIPT="/root/scripts/main.sh"
if [[ ! -f $MAIN_SCRIPT ]]; then
    mkdir -p "$SCRIPT_DIR"
    cp "$0" "$MAIN_SCRIPT"
    chmod +x "$MAIN_SCRIPT"
fi

# Define functions
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
    apt install -y openssh-server
    ufw enable
    ufw allow ssh
    echo "SSH enabled and configured."
}

configureDomainAndSoftware() {
    # Configuration tasks
    echo "Configuring domain and software..."
    # Add your domain and software configuration code here
    CURRENT_STATUS="stage3"
    echo "$CURRENT_STATUS : $(date)" > "$STATUS_LOG"
    echo "Rebooting now..."
    reboot now
}

# Main script execution based on status
case "$CURRENT_STATUS" in
    stage0)
        configure_auto_login
        update
        ;;
    stage1)
        installOpenSSH
        configureDomainAndSoftware
        ;;
    stage2)
        installDisplayManagerComponents
        installVMwareHorizonClient
        ;;
    stage3)
        echo "The script '$0' has completed all stages."
        ;;
    *)
        echo "Unknown status. Exiting."
        ;;
esac
