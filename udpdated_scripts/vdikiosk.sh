#!/bin/bash
# =============================================================================
# Multi-Stage System Setup Script for a Fresh Ubuntu 20.04 LTS Server
#
# This script performs a staged system configuration that:
#   - Updates the system packages.
#   - Configures auto-login for the root user.
#   - Installs display manager components (Xorg, Openbox, etc.).
#   - Downloads and installs the VMware Horizon Client.
#   - Installs and configures the OpenSSH server (with UFW) for remote management.
#   - Reconfigures /root/.bash_profile to automatically start X if needed.
#
# The script tracks progress through a status log (/root/status.log) so that if
# a reboot occurs, it continues where it left off.
#
# NOTE: This script must be run as root.
# =============================================================================

# ---------------------------------------------------------------------------
# Bash safety settings: exit on error, unset variable, or pipeline failure.
# ---------------------------------------------------------------------------
set -euo pipefail

# -------------------------------
# Global Constants and Variables
# -------------------------------
BASH_PROFILE="/root/.bash_profile"      # Root user’s bash profile
SCRIPT_PROFILE="./script.sh"            # Reference to this script file
STATUS_LOG="/root/status.log"           # File to store the current stage

# ----------------------------------------
# Ensure the script is run with root privileges
# ----------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root!"
  exit 1
fi

# ----------------------------------------
# Initialize /root/.bash_profile if it does not exist.
# (Here we simply store a reference to the script; this file will later be
# reconfigured to auto-start X on login if conditions are met.)
# ----------------------------------------
if [[ ! -f "$BASH_PROFILE" ]]; then
  echo "$SCRIPT_PROFILE" > "$BASH_PROFILE"
  echo "$BASH_PROFILE created with default content at $(date)."
fi

# ----------------------------------------
# Initialize or load the current status from STATUS_LOG.
# If the file does not exist, we begin at "stage0".
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
# Purpose: Configure systemd to auto-login the root user on tty1.
#
# This function:
#   - Removes the root password (if desired).
#   - Creates an override file for the getty@tty1 service so that it launches
#     a login session for root automatically.
#
# NOTE: Use this only in a controlled environment.
# =============================================================================
setupAutoLogin() {
  echo "Configuring auto-login for root on tty1..."
  # Remove the root password (this may have security implications)
  passwd -d root || { echo "Failed to remove root password."; return 1; }
  
  local override_dir="/etc/systemd/system/getty@tty1.service.d"
  local override_file="${override_dir}/override.conf"
  
  mkdir -p "$override_dir" || { echo "Failed to create $override_dir"; return 1; }
  
  # Write the override file for auto-login on tty1
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
#
# This function:
#   - Creates /root/scripts (if needed) and writes a short update script.
#   - Executes the update script.
#   - Sets the current stage to "stage1" in the status log.
#
# NOTE: The reboot is now controlled by the main execution flow.
# =============================================================================
update() {
  local updates_dir="/root/scripts"
  local updates_script="${updates_dir}/updates.sh"
  
  echo "Creating directory $updates_dir (if it doesn't exist)..."
  mkdir -p "$updates_dir" || { echo "Failed to create $updates_dir"; return 1; }
  
  # Write the update script using a heredoc.
  cat <<'EOF' > "$updates_script"
#!/bin/bash
apt update && apt -y dist-upgrade && apt -y autoremove
EOF
  
  chmod a+x "$updates_script" || { echo "Failed to set execute permissions on $updates_script"; return 1; }
  
  echo "Running system update script..."
  "$updates_script"
  
  # Advance to stage1 after successful update.
  CURRENT_STATUS="stage1"
  echo "$CURRENT_STATUS : $(date)" | tee "$STATUS_LOG"
  echo "System updates completed."
}

# =============================================================================
# Function: installDisplayManagerComponents
# Purpose: Install Xorg, Openbox, and related components, and configure Openbox.
#
# This function:
#   - Installs packages required for a graphical environment.
#   - Appends configuration settings to the Openbox autostart file that:
#       * Set the screen resolution.
#       * Disable screen blanking and power management.
#       * Allow terminating X with Ctrl+Alt+Backspace.
#       * Launch the VMware Horizon Client.
#
# NOTE: The current stage is advanced to "stage3" to indicate completion of this
#       section (though further configuration is still performed in stage1).
# =============================================================================
installDisplayManagerComponents() {
  local autostart_file="/etc/xdg/openbox/autostart"
  
  echo "Installing display manager components (Xorg, Openbox, etc.)..."
  apt install -y xorg xserver-xorg x11-xserver-utils xinit openbox || {
    echo "Failed to install display manager components."
    return 1
  }
  
  # Append configuration to the Openbox autostart file.
  # This ensures that when Openbox starts, it sets the screen resolution,
  # disables screen blanking/power management, and launches the VMware Horizon Client.
  cat <<'EOF' >> "$autostart_file"

# --- Openbox Autostart Configuration ---

# Set screen resolution to 1920x1080
xrandr -s 1920x1080

# Disable screen saver and power management features
xset s off
xset s noblank
xset -dpms

# Allow Ctrl+Alt+Backspace to terminate the X server
setxkbmap -option terminate:ctrl_alt_bksp

# Launch VMware Horizon Client with specified options
vmware-view --serverURL=vdigateway.udayton.edu --fullscreen --nomenubar --allSessionsDisconnectedBehavior='Logoff' --usbAutoConnectOnInsert='TRUE'
EOF

  # Advance the status to stage3 (final stage) for use after reboots.
  CURRENT_STATUS="stage3"
  echo "$CURRENT_STATUS : $(date)" | tee "$STATUS_LOG"
  
  echo "Display manager components installed and configured."
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
  
  chmod +x "$bundle_file" || { echo "Failed to set executable permission on $bundle_file"; return 1; }
  
  echo "Installing VMware Horizon Client..."
  env TERM=dumb ./"$bundle_file" --console --required || { echo "VMware Horizon Client installation failed"; return 1; }
  
  echo "VMware Horizon Client installed successfully."
  rm -f "$bundle_file"
  sleep 3
}

# =============================================================================
# Function: installOpenSSH
# Purpose: Install and configure the OpenSSH server along with UFW for remote access.
#
# This function:
#   - Installs the openssh-server package.
#   - Configures UFW (Uncomplicated Firewall) to allow SSH connections.
# =============================================================================
installOpenSSH() {
  echo "Installing OpenSSH server..."
  apt install -y openssh-server || { echo "Failed to install OpenSSH server"; return 1; }
  
  echo "Configuring UFW to allow SSH connections..."
  ufw allow ssh || { echo "Failed to configure UFW for SSH"; return 1; }
  ufw --force enable || { echo "Failed to enable UFW"; return 1; }
  
  echo "OpenSSH server installed and firewall configured for SSH."
  sleep 3
}

# =============================================================================
# Function: reconfigureBashProfile
# Purpose: Modify /root/.bash_profile to auto-start the X server on login if:
#          - $DISPLAY is not set, and
#          - The login is on VT1.
#
# After reconfiguring, this function issues a reboot.
# =============================================================================
reconfigureBashProfile() {
  echo "Reconfiguring $BASH_PROFILE to auto-start X on VT1 if no DISPLAY is set..."
  
  # Overwrite the bash profile with a condition to auto-launch X.
  cat <<'EOF' > "$BASH_PROFILE"
[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx
EOF
  
  echo "$BASH_PROFILE has been reconfigured."
  sleep 3
  echo "Rebooting to apply changes..."
  reboot
}

# =============================================================================
# Main Execution Flow: Stage Management
#
# The script uses the status stored in /root/status.log to determine which
# stage to execute:
#
#   - stage0: Update system packages and configure auto-login.
#             (After both functions complete, the system reboots.)
#
#   - stage1: Install display manager components, VMware Horizon Client,
#             and OpenSSH, then reconfigure bash profile to auto-start X.
#             (The reconfiguration function issues a reboot.)
#
#   - stage2: Reserved for future functionality.
#
#   - stage3: Indicates that the script has finished its configuration.
# =============================================================================
case "$CURRENT_STATUS" in
  stage0)
    echo "Starting Stage 0: System update and auto-login configuration."
    update
    setupAutoLogin
    echo "Stage 0 complete. Rebooting now..."
    sleep 3
    reboot
    ;;
  stage1)
    echo "Starting Stage 1: Installing display manager components, VMware Horizon Client, and OpenSSH."
    installDisplayManagerComponents
    installVMwareHorizonClient
    installOpenSSH
    # The following function reconfigures bash_profile and reboots.
    reconfigureBashProfile
    ;;
  stage2)
    # Reserved for future functionality
    echo "Stage2 functionality is not implemented."
    ;;
  stage3)
    echo "The script '$0' has finished its configuration."
    ;;
  *)
    echo "Unexpected status '$CURRENT_STATUS'. Something went wrong!"
    ;;
esac
