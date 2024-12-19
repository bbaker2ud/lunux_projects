#!/bin/bash
# Run as root on Ubuntu 24.04 LTS

#############################################
# Variables and Paths
#############################################
BASH_PROFILE="/root/.bash_profile"
STATUS_LOG="/root/status.log"
SCRIPT_DIR="/root/scripts"
MAIN_SCRIPT="${SCRIPT_DIR}/main.sh"
UPDATES_SCRIPT="${SCRIPT_DIR}/updates.sh"
AUTOLOGIN_OVERRIDE="/etc/systemd/system/getty@tty1.service.d/override.conf"
OPENBOX_AUTOSTART="/etc/xdg/openbox/autostart"
HORIZON_CLIENT_URL="https://download3.vmware.com/software/CART24FQ2_LIN64_2306/VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle"
HORIZON_CLIENT_BUNDLE="VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle"
CROWDSTRIKE_CID="0FA34C2A8A4545FC9D85E072AFBABA4A-E7"
AD_DOMAIN="adws.udayton.edu"
SHARE_PATH="//itsmldcs1.adws.udayton.edu/ldlogon/unix"
MOUNT_DIR="/media/share"

#############################################
# Functions
#############################################

configure_auto_login() {
    echo "Configuring root auto-login..."
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    cat <<EOF > "$AUTOLOGIN_OVERRIDE"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF
    systemctl daemon-reload
    echo "Root auto-login configured."
}

initialize_bash_profile() {
    # Only write if .bash_profile doesn't exist
    if [[ ! -f $BASH_PROFILE ]]; then
        echo "Initializing .bash_profile..."
        cat <<EOF > "$BASH_PROFILE"
# .bash_profile created on $(date)

# Debug: Log that we are in .bash_profile
echo "\$(date) : .bash_profile executed" >> /root/login.log

# Start X session if on the main console and no DISPLAY
[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec startx

# If main script and status log exist, continue the main script
if [[ -f "$MAIN_SCRIPT" && -f "$STATUS_LOG" ]]; then
    bash "$MAIN_SCRIPT"
fi
EOF
    fi

    # Ensure no .profile or .bash_login that might interfere
    rm -f /root/.profile /root/.bash_login
}

initialize_status_log() {
    if [[ ! -f $STATUS_LOG ]]; then
        echo "Initializing status log..."
        echo "stage0 : $(date)" > "$STATUS_LOG"
    fi
}

get_current_status() {
    awk '{print $1}' "$STATUS_LOG"
}

set_status() {
    local status="$1"
    echo "$status : $(date)" > "$STATUS_LOG"
    sync
}

update_system() {
    echo "Updating system..."
    mkdir -p "$SCRIPT_DIR"
    cat <<EOF > "$UPDATES_SCRIPT"
#!/bin/bash
apt update && apt -y dist-upgrade && apt -y autoremove
EOF
    chmod +x "$UPDATES_SCRIPT"
    "$UPDATES_SCRIPT"
    echo "Updates finished."
}

install_dependencies() {
    echo "Installing all required packages..."
    apt update
    apt install -y \
        xorg xserver-xorg x11-xserver-utils xinit openbox \
        openssh-server ufw wget realmd cifs-utils python3-pip curl \
        unzip net-tools software-properties-common

    # Enable and configure firewall
    ufw enable
    ufw allow ssh
    echo "All dependencies installed."
}

configure_ssh() {
    echo "Configuring SSH..."
    systemctl enable ssh
    ufw allow ssh
    echo "SSH configured."
}

configure_sudoers() {
    echo "Configuring sudoers..."
    {
        echo "administrator ALL=(ALL) ALL"
        echo "landesk ALL=(ALL) NOPASSWD: ALL"
        echo "Defaults:landesk !requiretty"
        echo "%cas.role.administrators.casit.workstations@adws.udayton.edu ALL=(ALL) ALL"
    } >> /etc/sudoers
    echo "Sudoers configured."
}

configure_updates_cron() {
    echo "Setting up updates cron job..."
    mkdir -p /var/spool/cron/crontabs
    echo "0 0 1 * * /root/scripts/updates.sh" >> /var/spool/cron/crontabs/root
    echo "Cron job for monthly updates set."
}

join_realm() {
    echo "Joining AD Domain..."
    realm discover "$AD_DOMAIN"
    sleep 10
    success=0
    until [ $success -eq 1 ]; do
        read -p "Enter your UD username: " username
        read -sp "Enter your UD password: " password
        echo
        echo "$password" | realm join -U "$username" "$AD_DOMAIN"
        if [ $? -eq 0 ]; then
            success=1
            echo "Successfully joined realm."
        else
            echo "Failed to join realm. Try again."
        fi
    done

    echo "Permitting domain user logins..."
    realm permit -g "domain users@$AD_DOMAIN"
    realm permit -g "cas.role.administrators.casit.workstations@$AD_DOMAIN"

    # Enable home directory creation
    pam-auth-update --enable mkhomedir
    echo "Realm joined and PAM configured."
}

install_falcon_sensor() {
    echo "Installing Falcon Sensor..."
    pip install gdown
    gdown 1YnvSQmCgUE0lRs5Fauvfub_KsUhcnbCw -O falcon-sensor.deb
    dpkg --install falcon-sensor.deb
    /opt/CrowdStrike/falconctl -s --cid="$CROWDSTRIKE_CID"
    systemctl start falcon-sensor
    rm falcon-sensor.deb
    echo "Falcon Sensor installed and configured."
}

mount_network_share() {
    echo "Mounting network share..."
    mkdir -p "$MOUNT_DIR"
    good=0
    until [ $good -eq 1 ]; do
        echo "Mounting $SHARE_PATH..."
        mount -v -t cifs -o rw,vers=3.0,username=$username,password=$password "$SHARE_PATH" "$MOUNT_DIR"
        if [ $? -eq 0 ]; then
            good=1
            echo "Share mounted successfully."
        else
            echo "Failed to mount share. Try again."
        fi
    done
}

install_ivanti_agent() {
    echo "Installing Ivanti Agent..."
    mkdir -p /tmp/ems
    cp "$MOUNT_DIR/nixconfig.sh" /tmp/ems/nixconfig.sh
    chmod a+x /tmp/ems/nixconfig.sh

    # Enable firewall ports for Ivanti
    ufw allow 9593
    ufw allow 9594
    ufw allow 9595/tcp
    ufw allow 9595/udp

    /tmp/ems/nixconfig.sh -p -a itsmldcs1.adws.udayton.edu -i all -k ea67f4cd.0
    echo "Ivanti Agent installed."
}

configure_openbox_autostart() {
    echo "Configuring Openbox autostart..."
    mkdir -p /etc/xdg/openbox/
    cat <<EOF > "$OPENBOX_AUTOSTART"
xrandr -s 1920x1080
xset s off
xset s noblank
xset -dpms
setxkbmap -option terminate:ctrl_alt_bksp
vmware-view --serverURL=vdigateway.udayton.edu --fullscreen --nomenubar \
    --allSessionsDisconnectedBehavior='Logoff' --usbAutoConnectOnInsert='TRUE'
EOF
    echo "Openbox autostart configured."
}

install_vmware_horizon() {
    echo "Installing VMware Horizon Client..."
    wget -q "$HORIZON_CLIENT_URL" -O "$HORIZON_CLIENT_BUNDLE"
    chmod +x "$HORIZON_CLIENT_BUNDLE"
    env TERM=dumb ./"$HORIZON_CLIENT_BUNDLE" --console --required
    rm -f "$HORIZON_CLIENT_BUNDLE"
    echo "VMware Horizon Client installed."
}

create_xinitrc() {
    echo "Creating .xinitrc..."
    echo "exec openbox-session" > /root/.xinitrc
    chown root:root /root/.xinitrc
    chmod 644 /root/.xinitrc
    echo ".xinitrc created."
}

#############################################
# Main Execution Flow
#############################################

# Ensure main script and directories
mkdir -p "$SCRIPT_DIR"
if [[ "$0" != "$MAIN_SCRIPT" ]]; then
    cp "$0" "$MAIN_SCRIPT"
    chmod +x "$MAIN_SCRIPT"
fi

initialize_bash_profile
initialize_status_log
CURRENT_STATUS=$(get_current_status)

case "$CURRENT_STATUS" in
    stage0)
        configure_auto_login
        update_system
        set_status "stage1"
        echo "Rebooting now..."
        reboot
        ;;

    stage1)
        install_dependencies
        configure_ssh
        configure_sudoers
        configure_updates_cron
        join_realm
        install_falcon_sensor
        mount_network_share
        install_ivanti_agent
        set_status "stage2"
        echo "Rebooting now..."
        reboot
        ;;

    stage2)
        configure_openbox_autostart
        install_vmware_horizon
        create_xinitrc
        set_status "stage3"
        echo "Rebooting now..."
        reboot
        ;;

    stage3)
        echo "The script '$0' has completed all stages."
        echo "On this final boot, root will auto-login, .bash_profile will run startx,"
        echo ".xinitrc will launch openbox-session, and VMware Horizon will autostart."
        ;;
    *)
        echo "Unknown status. Exiting."
        ;;
esac
