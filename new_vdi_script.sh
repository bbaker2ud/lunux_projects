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

reconfigureBashProfile() {
    echo "Reconfiguring .bash_profile..."
    echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$BASH_PROFILE"
    echo ".bash_profile reconfigured."
    sync
    reboot
}

installOpenSSH() {
    echo "Installing and configuring OpenSSH..."
    apt install -y openssh-server
    ufw enable
    ufw allow ssh
    echo "SSH enabled and configured."
}

configureDomainAndSoftware() {
    # This function incorporates the additional code provided
    echo "Creating /root/scripts directory..."
    mkdir -p /root/scripts

    echo "Creating updates.sh..."
    touch /root/scripts/updates.sh

    echo "Changing permissions..."
    chmod a+x /root/scripts/updates.sh

    echo "Building script..."
    {
        echo "#!/bin/bash"
        echo "apt update &&"
        echo "apt -y dist-upgrade &&"
        echo "apt -y autoremove"
    } > /root/scripts/updates.sh

    echo "Running updates.sh..."
    /root/scripts/updates.sh
    echo "Done."

    echo "Adding crontab..."
    # Ensure the root crontab directory exists
    mkdir -p /var/spool/cron/crontabs
    echo "0 0 1 * * /root/scripts/updates.sh" >> /var/spool/cron/crontabs/root
    echo "Done."

    echo "Adding sudoers..."
    {
        echo "administrator ALL=(ALL) ALL"
        echo "landesk ALL=(ALL) NOPASSWD: ALL"
        echo "Defaults:landesk !requiretty"
        echo "%cas.role.administrators.casit.workstations@adws.udayton.edu ALL=(ALL) ALL"
    } >> /etc/sudoers
    echo "Done."

    echo "Installing realmd..."
    apt install -y realmd

    echo "Discovering realm..."
    realm discover adws.udayton.edu
    sleep 10

    success=0
    until [ $success -ge 1 ]; do
        echo "Please enter your UD username: "
        read -p 'Username: ' username
        echo "Please enter your UD password: "
        read -sp 'Password: ' password
        echo
        echo "Joining realm..."
        echo "$password" | realm join -U "$username" adws.udayton.edu
        if [ $? -eq 0 ]; then
            success=1
            echo "success=$success"
        else
            echo "Failed to join realm. Try again."
        fi
    done

    echo "Permitting domain user logins..."
    realm permit -g 'domain users@adws.udayton.edu'

    echo "Permitting admin logins..."
    realm permit -g cas.role.administrators.casit.workstations@adws.udayton.edu
    echo "Done."

    echo "Fixing pam..."
    pam-auth-update --enable mkhomedir
    echo "Done."

    echo "Installing pip..."
    apt -y install python3-pip

    echo "Installing gdown..."
    pip install gdown

    echo "Downloading Falcon Sensor..."
    gdown 1YnvSQmCgUE0lRs5Fauvfub_KsUhcnbCw

    echo "Installing Falcon Sensor..."
    dpkg --install falcon-sensor_6.38.0-13501_amd64.deb
    /opt/CrowdStrike/falconctl -s --cid=0FA34C2A8A4545FC9D85E072AFBABA4A-E7
    systemctl start falcon-sensor
    rm falcon-sensor_6.38.0-13501_amd64.deb

    echo "Installing cifs-utils..."
    apt install -y cifs-utils

    echo "Mounting network share..."
    mkdir -p /media/share
    good=0
    until [ $good -ge 1 ]; do
        mount -v -t cifs -o rw,vers=3.0,username=$username,password=$password //itsmldcs1.adws.udayton.edu/ldlogon/unix /media/share
        if [ $? -eq 0 ]; then
            good=1
            echo "success=$good"
        else
            echo "Failed to mount share. Try again."
        fi
    done

    echo "Creating temporary directory..."
    mkdir -p /tmp/ems
    echo "Navigating to temporary directory..."
    cd /tmp/ems

    echo "Downloading nixconfig.sh..."
    cp /media/share/nixconfig.sh /tmp/ems/nixconfig.sh
    echo "Making nixconfig.sh executable..."
    chmod a+x /tmp/ems/nixconfig.sh

    echo "Enabling firewall..."
    ufw enable
    echo "Opening ports..."
    ufw allow 22
    ufw allow 9593
    ufw allow 9594
    ufw allow 9595/tcp
    ufw allow 9595/udp
    echo "Done."

    echo "Installing Ivanti Agent..."
    /tmp/ems/nixconfig.sh -p -a itsmldcs1.adws.udayton.edu -i all -k ea67f4cd.0
    echo "Done."

    CURRENT_STATUS="stage3"
    echo "$CURRENT_STATUS : $(date)" > "$STATUS_LOG"
    echo "Rebooting now..."
    reboot now
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
        installOpenSSH
        configureDomainAndSoftware
        ;;
    stage3)
        echo "The script '$0' has completed all stages."
        ;;
    *)
        echo "Unknown status. Exiting."
        ;;
esac
