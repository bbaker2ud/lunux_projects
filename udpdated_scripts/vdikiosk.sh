#!/bin/bash
# =============================================================================
# Multi-Stage VDI-Kiosk Setup Script for a clean installation Ubuntu 20.04 LTS Server
#
# This script performs a staged system configuration that:
#   - Updates the system packages.
#   - Configures auto-login for the root user.
#   - Installs display manager components (Xorg, Openbox, etc.).
#   - Downloads and installs the VMware Horizon Client (if not already installed).
#   - Installs and configures the OpenSSH server (with UFW) for remote management.
#   - Reconfigures /root/.bash_profile to automatically start X if needed.
#
# The script tracks progress through a status log (/root/status.log) so that if
# a reboot occurs, it continues where it left off.
#
# NOTE: This script must be run as root, from the /root directory.
# =============================================================================

# ---------------------------------------------------------------------------
# Bash safety settings: exit on error, unset variable, or pipeline failure.
# ---------------------------------------------------------------------------
set -euo pipefail

# -------------------------------
# Global Constants and Variables
# -------------------------------
BASH_PROFILE="/root/.bash_profile"      # Root user’s bash profile
SCRIPT_PROFILE="$(readlink -f "$0")"    # Absolute path to this script file
STATUS_LOG="/root/status.log"           # File to store the current stage

# Allowed status values
ALLOWED_STAGES=("stage0" "stage1" "stage2" "stage3")

# ----------------------------------------
# Ensure the script is run with root privileges
# ----------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root!"
  exit 1
fi

# ----------------------------------------
# Ensure the script is run from the /root directory
# ----------------------------------------
if [[ "$(pwd)" != "/root" ]]; then
  echo "Please run this script from the /root directory."
  exit 1
fi

# ----------------------------------------
# Initialize /root/.bash_profile if it does not exist.
# (We strictly enforce configuration by writing a marker line later.)
# ----------------------------------------
if [[ ! -f "$BASH_PROFILE" ]]; then
  echo "$SCRIPT_PROFILE" > "$BASH_PROFILE"
  echo "$BASH_PROFILE created with default content at $(date)."
fi

# ----------------------------------------
# Initialize or load the current status from STATUS_LOG.
# Validate the status; if unexpected, back it up and default to stage0.
# ----------------------------------------
if [[ -f "$STATUS_LOG" ]]; then
  CURRENT_STATUS=$(cat "$STATUS_LOG")
  if [[ ! " ${ALLOWED_STAGES[*]} " =~ " ${CURRENT_STATUS} " ]]; then
    mv "$STATUS_LOG" "${STATUS_LOG}.backup_$(date +%s)"
    echo "Unexpected status in log. Backing up and resetting to stage0."
    CURRENT_STATUS="stage0"
    echo "$CURRENT_STATUS" > "$STATUS_LOG"
  fi
else
  CURRENT_STATUS="stage0"
  echo "$CURRENT_STATUS" > "$STATUS_LOG"
  echo "Status log initialized to $CURRENT_STATUS at $(date)."
fi

# =============================================================================
# Function: setupAutoLogin
# Purpose: Configure systemd to auto-login the root user on tty1.
#
# Checks if the root password is already disabled (using 'passwd -S root') and
# then enforces a configuration file marked with BEGIN/END markers.
# =============================================================================
setupAutoLogin() {
  echo "Configuring auto-login for root on tty1..."

  # Check if root password is already disabled.
  if passwd -S root | grep -q "NP"; then
    echo "Root password is already disabled."
  else
    echo "Disabling root password..."
    passwd -d root || { echo "Failed to remove root password."; return 1; }
  fi

  local override_dir="/etc/systemd/system/getty@tty1.service.d"
  local override_file="${override_dir}/override.conf"

  mkdir -p "$override_dir" || { echo "Failed to create $override_dir"; return 1; }

  # Use marker comments to strictly enforce configuration.
  cat <<'EOF' > "$override_file"
# BEGIN VDI-Kiosk AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root %I $TERM
# END VDI-Kiosk AUTOLOGIN
EOF

  echo "Auto-login configured in $override_file."
}

# =============================================================================
# Function: update
# Purpose: Create and run an update script to update, upgrade, and clean the system.
# =============================================================================
update() {
  local updates_dir="/root/scripts"
  local updates_script="${updates_dir}/updates.sh"

  echo "Creating directory $updates_dir (if it doesn't exist)..."
  mkdir -p "$updates_dir" || { echo "Failed to create $updates_dir"; return 1; }

  # Strictly enforce the update script (overwrite if exists).
  cat <<'EOF' > "$updates_script"
#!/bin/bash
apt update && apt -y dist-upgrade && apt -y autoremove
EOF

  chmod a+x "$updates_script" || { echo "Failed to set execute permissions on $updates_script"; return 1; }

  echo "Running system update script..."
  "$updates_script"

  # Advance to stage1 only after successful update.
  CURRENT_STATUS="stage1"
  echo "$CURRENT_STATUS : $(date)" | tee "$STATUS_LOG"
  echo "System updates completed."
}

# =============================================================================
# Function: installDisplayManagerComponents
# Purpose: Install Xorg, Openbox, and related components, and configure Openbox.
# =============================================================================
installDisplayManagerComponents() {
  local autostart_file="/etc/xdg/openbox/autostart"

  echo "Installing display manager components (Xorg, Openbox, etc.)..."
  # Check if packages are installed; if so, log and skip installation.
  if dpkg -l xorg openbox xserver-xorg x11-xserver-utils xinit 2>/dev/null | grep -q '^ii'; then
    echo "Display manager packages appear to be already installed."
  else
    apt install -y xorg xserver-xorg x11-xserver-utils xinit openbox || {
      echo "Failed to install display manager components."
      return 1
    }
  fi

  # Use marker comments to ensure our configuration is added only once.
  if ! grep -q "BEGIN VDI-Kiosk DISPLAY CONFIG" "$autostart_file" 2>/dev/null; then
    cat <<'EOF' >> "$autostart_file"

# BEGIN VDI-Kiosk DISPLAY CONFIG
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
# END VDI-Kiosk DISPLAY CONFIG
EOF
  else
    echo "Display configuration already present in $autostart_file."
  fi

  # Advance the status to stage3 (for use on reboot).
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
  # Check if VMware Horizon Client is already installed.
  if command -v vmware-view &>/dev/null; then
    echo "VMware Horizon Client is already installed; skipping installation."
    return 0
  fi

  local bundle_url="https://download3.vmware.com/software/CART24FQ2_LIN64_2306/VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle"
  local bundle_file="VMware-Horizon-Client-2306-8.10.0-21964631.x64.bundle"
  local venv_dir="/tmp/vmware-horizon-venv"

  echo "Downloading VMware Horizon Client bundle..."
  wget "$bundle_url" -O "$bundle_file" || { echo "Failed to download VMware Horizon Client bundle"; return 1; }

  chmod +x "$bundle_file" || { echo "Failed to set executable permission on $bundle_file"; return 1; }

  echo "Ensuring Python 3.10, venv module, and pip are installed..."
  sudo apt update
  sudo apt install -y python3.10 python3.10-venv python3.10-distutils python3-pip || { echo "Failed to install required Python 3.10 packages"; return 1; }

  echo "Creating a Python 3.10 virtual environment..."
  python3.10 -m venv "$venv_dir" || { echo "Failed to create Python 3.10 virtual environment"; return 1; }

  echo "Activating the virtual environment..."
  source "$venv_dir/bin/activate"

  echo "Upgrading pip inside the virtual environment..."
  python -m ensurepip --default-pip || { echo "Failed to bootstrap pip"; deactivate; return 1; }
  python -m pip install --upgrade pip || { echo "Failed to upgrade pip"; deactivate; return 1; }

  echo "Installing VMware Horizon Client using Python 3.10 virtual environment..."
  PYTHON="$venv_dir/bin/python" "$bundle_file" --console --required || { echo "VMware Horizon Client installation failed"; deactivate; return 1; }

  echo "Deactivating and removing virtual environment..."
  deactivate
  rm -rf "$venv_dir"

  echo "Cleaning up installation files..."
  rm -f "$bundle_file"

  echo "VMware Horizon Client installed successfully."
  sleep 3
}




# =============================================================================
# Function: installOpenSSH
# Purpose: Install and configure the OpenSSH server along with UFW for remote access.
# =============================================================================
installOpenSSH() {
  # Check if OpenSSH is already installed.
  if dpkg -l openssh-server &>/dev/null && command -v sshd &>/dev/null; then
    echo "OpenSSH server appears to be already installed."
  else
    echo "Installing OpenSSH server..."
    apt install -y openssh-server || { echo "Failed to install OpenSSH server"; return 1; }
  fi

  echo "Verifying UFW status..."
  # Check if UFW is active and if SSH is allowed.
  if ufw status | grep -q "Status: active"; then
    if ufw status | grep -q "22/tcp"; then
      echo "UFW is active and SSH is already allowed."
    else
      echo "UFW is active but SSH is not allowed. Allowing SSH..."
      ufw allow ssh || { echo "Failed to configure UFW for SSH"; return 1; }
    fi
  else
    echo "UFW is not active. Enabling UFW and allowing SSH..."
    ufw allow ssh || { echo "Failed to configure UFW for SSH"; return 1; }
    ufw --force enable || { echo "Failed to enable UFW"; return 1; }
  fi

  echo "OpenSSH server installed and firewall configured for SSH."
  sleep 3
}

# =============================================================================
# Function: reconfigureBashProfile
# Purpose: Modify /root/.bash_profile to auto-start the X server on login if:
#          - $DISPLAY is not set, and
#          - The login is on VT1.
#
# After reconfiguring, this function issues a reboot after a short countdown.
# =============================================================================
reconfigureBashProfile() {
  echo "Reconfiguring $BASH_PROFILE to auto-start X on VT1 if no DISPLAY is set..."

  # Overwrite the bash profile with a strict configuration using markers.
  cat <<'EOF' > "$BASH_PROFILE"
# BEGIN VDI-Kiosk BASH PROFILE CONFIG
[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx
# END VDI-Kiosk BASH PROFILE CONFIG
EOF

  echo "$BASH_PROFILE has been reconfigured."
  sleep 3
  echo "Rebooting to apply changes in 10 seconds. Press Ctrl+C to cancel."
  for i in {10..1}; do
    echo "$i..."
    sleep 1
  done
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

    # Correctly advance to the next stage before rebooting
    CURRENT_STATUS="stage1"
    echo "$CURRENT_STATUS" > "$STATUS_LOG"

    echo "Stage 0 complete. Advancing to Stage 1 on next boot. Rebooting in 10 seconds..."
    for i in {10..1}; do
      echo "$i..."
      sleep 1
    done

    reboot

    ;;
  stage1)
    echo "Starting Stage 1: Installing display manager components, VMware Horizon Client, and OpenSSH."
    installDisplayManagerComponents
    installVMwareHorizonClient
    installOpenSSH
    # This function reconfigures the bash profile and reboots.
    reconfigureBashProfile
    ;;
  stage2)
    echo "Stage2 functionality is not implemented."
    ;;
  stage3)
    echo "The script '$SCRIPT_PROFILE' has finished its configuration."
    ;;
  *)
    echo "Unexpected status '$CURRENT_STATUS'. Exiting."
    exit 1
    ;;
esac
