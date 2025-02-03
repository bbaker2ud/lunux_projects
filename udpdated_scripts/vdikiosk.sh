#!/bin/bash
# =============================================================================
# Multi-Stage System Setup Script
#
# This script performs a staged system configuration that:
#   - Updates the system packages.
#   - Installs display manager components (Xorg, Openbox, etc.).
#   - Downloads and installs the VMware Horizon Client.
#   - Reconfigures /root/.bash_profile to automatically start X (if needed).
#
# The script tracks progress through a status log (/root/status.log) so that
# if a reboot occurs, it will continue where it left off.
#
#
# Run this script as root.
# =============================================================================

# -------------------------------
# Global Constants and Variables
# -------------------------------
BASH_PROFILE="/root/.bash_profile"      # The bash profile for the root user
SCRIPT_PROFILE="./script.sh"              # Reference to this script's file
STATUS_LOG="/root/status.log"             # File to store the current stage

# ----------------------------------------
# Ensure the script is run with root privileges
# ----------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root!"
  exit 1
fi

# ----------------------------------------
# Initialize .bash_profile if it does not exist
# ----------------------------------------
if [[ ! -f "$BASH_PROFILE" ]]; then
  echo "$SCRIPT_PROFILE" > "$BASH_PROFILE"
  echo "$BASH_PROFILE created with default content at $(date)."
fi

# ----------------------------------------
# Initialize or load the current status from STATUS_LOG
# ----------------------------------------
if [[ -f "$STATUS_LOG" ]]; then
  CURRENT_STATUS=$(cat "$STATUS_LOG")
else
  CURRENT_STATUS="stage0"
  echo "$CURRENT_STATUS" > "$STATUS_LOG"
  echo "Status log initialized to $CURRENT_STATUS at $(date)."
fi

# =============================================================================
# Function: setupAutoLogin
# Purpose: Configure systemd for auto-login as root on tty1.
# =============================================================================
setupAutoLogin() {
  # Remove root password (if desired) and configure auto-login for tty1.
  passwd -d root || return 1
  
  local override_dir="/etc/systemd/system/getty@tty1.service.d"
  local override_file="${override_dir}/override.conf"
  
  mkdir -p "$override_dir" || return 1
  cat <<EOF > "$override_file"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root %I \$TERM
EOF
  echo "Auto-login configured in $override_file."
}

# =============================================================================
# Function: update
# Purpose: Create and run an update script to update, upgrade, and clean the system.
#          Then, set the status to 'stage1' and reboot.
# =============================================================================
update() {
  local updates_dir="/root/scripts"
  local updates_script="${updates_dir}/updates.sh"
  
  echo "Creating directory $updates_dir (if it doesn't exist)..."
  mkdir -p "$updates_dir" || { echo "Failed to create $updates_dir"; return 1; }
  
  # Build the update script using a heredoc for clarity
  cat <<'EOF' > "$updates_script"
#!/bin/bash
apt update && apt -y dist-upgrade && apt -y autoremove
EOF
  
  chmod a+x "$updates_script" || { echo "Failed to set execute permissions on $updates_script"; return 1; }
  
  echo "Running updates script..."
  "$updates_script"
  
  # Advance to stage1
  CURRENT_STATUS="stage1"
  echo "$CURRENT_STATUS : $(date)" | tee "$STATUS_LOG"
  
  echo "Updates finished. Rebooting now."
  sleep 3
  reboot
}

# =============================================================================
# Function: installDisplayManagerComponents
# Purpose: Install Xorg, Openbox, and related components, and configure the 
#          Openbox autostart file with screen settings and VMware Horizon launch.
# =============================================================================
installDisplayManagerComponents() {
  local autostart_file="/etc/xdg/openbox/autostart"
  
  echo "Installing display manager components..."
  apt install -y xorg xserver-xorg x11-xserver-utils xinit openbox || {
    echo "Failed to install display manager components"
    return 1
  }
  
  # Append configuration settings to the Openbox autostart file using a heredoc.
  cat <<'EOF' >> "$autostart_file"

# --- Openbox Autostart Configuration ---

# Set screen resolution
xrandr -s 1920x1080

# Disable screen saver and power management
xset s off
xset s noblank
xset -dpms

# Allow Ctrl+Alt+Backspace to terminate the X server
setxkbmap -option terminate:ctrl_alt_bksp

# Launch VMware Horizon Client with specified options
vmware-view --serverURL=vdigateway.udayton.edu --fullscreen --nomenubar --allSessionsDisconnectedBehavior='Logoff' --usbAutoConnectOnInsert='TRUE'
EOF

  # Advance to stage3 (Note: stage2 is reserved for future use)
  CURRENT_STATUS="stage3"
  echo "$CURRENT_STATUS : $(date)" | tee "$STATUS_LOG"
  
  echo "Display Manager Components installed."
  sleep 3
}

# =============================================================================
# Function: installVMwareHorizonClient
# Purpose: Download and install the VMware Horizon Client.
# =============================================================================
installVMwareHorizonClient() {
  local bundle_url="https://download3.vmware.com/software/CART24FQ2_LIN64_2306/VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle"
  local bundle_file="VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle"
  
  echo "Downloading VMware Horizon Client bundle..."
  wget "$bundle_url" -O "$bundle_file" || { echo "Failed to download VMware Horizon Client bundle"; return 1; }
  
  chmod +x "$bundle_file" || { echo "Failed to make $bundle_file executable"; return 1; }
  
  echo "Installing VMware Horizon Client..."
  env TERM=dumb ./"$bundle_file" --console --required || { echo "Installation of VMware Horizon Client failed"; return 1; }
  
  echo "VMware Horizon Client installed."
  rm -f "$bundle_file"
  sleep 3
}

# =============================================================================
# Function: installOpenSSH
# Purpose: Install and configure the OpenSSH server along with UFW.
# Note: This function is defined but not invoked in the current workflow.
# =============================================================================
installOpenSSH() {
  echo "Installing OpenSSH server..."
  apt install -y openssh-server || { echo "Failed to install OpenSSH server"; return 1; }
  
  echo "Configuring UFW for SSH..."
  ufw allow ssh || { echo "Failed to configure UFW for SSH"; return 1; }
  ufw enable || { echo "Failed to enable UFW"; return 1; }
  
  echo "SSH enabled and configured."
  sleep 3
}

# =============================================================================
# Function: reconfigureBashProfile
# Purpose: Modify /root/.bash_profile to auto-start the X server on login if:
#          - $DISPLAY is not set, and
#          - The login is on VT1.
#          Then, reboot the system.
# =============================================================================
reconfigureBashProfile() {
  echo "Reconfiguring $BASH_PROFILE to auto-start X (if needed)..."
  
  cat <<'EOF' > "$BASH_PROFILE"
[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx
EOF
  
  echo ".bash_profile reconfigured."
  sleep 3
  reboot
}

# =============================================================================
# Main Execution Flow: Stage Management
#
# The script operates in multiple stages:
#   - stage0: Perform system updates.
#   - stage1: Install display manager components, VMware Horizon Client, and
#             reconfigure the bash profile.
#   - stage2: (Reserved for future functionality)
#   - stage3: Indicate that the script has finished.
# =============================================================================
case "$CURRENT_STATUS" in
  stage0)
    update
    setupAutoLogin
    ;;
  stage1)
    installDisplayManagerComponents
    installVMwareHorizonClient
    installOpenSSH
    reconfigureBashProfile
    ;;
  stage2)
    # Reserved for future functionality
    echo "Stage2 functionality is not implemented."
    ;;
  stage3)
    echo "The script '$0' is finished."
    ;;
  *)
    echo "Unexpected status '$CURRENT_STATUS'. Something went wrong!"
    ;;
esac
