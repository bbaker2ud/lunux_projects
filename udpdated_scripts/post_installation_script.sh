#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ==============================================================================
# Script: Ubuntu 20.04/22.04 Post-Installation Setup
#
# Purpose:
#   - Create and configure an update script (and schedule it via cron).
#   - Update the sudoers file with specific user/group privileges.
#   - Install and configure realmd; join the machine to the AD domain.
#   - Permit domain and administrative logins.
#   - Update PAM configuration to automatically create home directories.
#   - Install python3-pip and gdown for downloading remote resources.
#   - Download and install the Falcon Sensor.
#   - Install CIFS utilities and mount a network share.
#   - Retrieve and configure an Ivanti Agent via a script from the share.
#   - Enable and configure the firewall.
#   - Reboot the machine upon completion.
#
# IMPORTANT: This script must be run as root.
# ==============================================================================

# -------------------------------------------------------------------------------
# Verify the script is run as root.
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root."
  exit 1
fi

# -------------------------------------------------------------------------------
# Function: setup_update_script
# -------------------------------------------------------------------------------
setup_update_script() {
  local script_dir="/root/scripts"
  local update_script="${script_dir}/updates.sh"

  echo "Creating ${script_dir} directory (if it doesn't exist)..."
  mkdir -p "$script_dir"

  echo "Building update script at ${update_script}..."
  cat <<'EOF' > "$update_script"
#!/bin/bash
apt-get update &&
apt-get -y dist-upgrade &&
apt-get -y autoremove
EOF

  echo "Setting execute permissions on ${update_script}..."
  chmod a+x "$update_script"

  echo "Running update script..."
  "$update_script"
  echo "Update script completed."
}

# -------------------------------------------------------------------------------
# Function: add_cronjob
# -------------------------------------------------------------------------------
add_cronjob() {
  local cron_entry="0 0 1 * * /root/scripts/updates.sh"
  echo "Adding cron job for update script..."
  # Use the crontab command to merge the new entry with existing cron jobs.
  if crontab -l 2>/dev/null | grep -qF "$cron_entry"; then
    echo "Cron job already exists."
  else
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    echo "Cron job added."
  fi
}

# -------------------------------------------------------------------------------
# Function: update_sudoers
# -------------------------------------------------------------------------------
update_sudoers() {
  echo "Updating /etc/sudoers with required entries..."
  {
    echo "administrator ALL=(ALL) ALL"
    echo "landesk ALL=(ALL) NOPASSWD: ALL"
    echo "Defaults:landesk !requiretty"
    echo "%cas.role.administrators.casit.workstations@adws.udayton.edu ALL=(ALL) ALL"
  } >> /etc/sudoers
  echo "Sudoers updated."
}

# -------------------------------------------------------------------------------
# Function: verify_and_update_hostname
# Purpose: Ensure the current hostname meets UD standards and that the same
#          hostname is configured in Active Directory.
# -------------------------------------------------------------------------------
verify_and_update_hostname() {
  local current_hostname
  current_hostname=$(hostname)
  echo "The current hostname is: $current_hostname"
  
  read -rp "Is this hostname in accordance with UD standards? (y/n): " hostname_confirm
  if [[ "$hostname_confirm" != "y" && "$hostname_confirm" != "Y" ]]; then
    read -rp "Enter the correct hostname as per UD standards: " new_hostname
    hostnamectl set-hostname "$new_hostname"
    echo "Hostname updated. New hostname is: $(hostname)"
  fi
  
  # Verify that the Active Directory has been updated with the hostname.
  read -rp "Please verify that the hostname '$(hostname)' is configured in Active Directory. Is it updated? (y/n): " ad_confirm
  while [[ "$ad_confirm" != "y" && "$ad_confirm" != "Y" ]]; do
    echo "Please update Active Directory accordingly."
    read -rp "Once updated, confirm that the hostname '$(hostname)' is configured in AD (y/n): " ad_confirm
  done
}

# -------------------------------------------------------------------------------
# Function: install_realmd_and_join
# -------------------------------------------------------------------------------
install_realmd_and_join() {
  # First, verify and (if necessary) update the hostname.
  verify_and_update_hostname

  echo "Installing realmd..."
  apt-get install -y realmd

  echo "Discovering realm for adws.udayton.edu..."
  realm discover adws.udayton.edu
  sleep 10

  local success=0
  # Continue prompting until realm join succeeds.
  while [[ $success -lt 1 ]]; do
    echo "Please enter your UD username: "
    read -r -p "Username: " username

    echo "Please enter your UD password: "
    read -r -s password
    echo

    echo "Attempting to join realm..."
    # Pipe the password to the realm join command.
    if echo "$password" | realm join -U "$username" adws.udayton.edu; then
      success=1
      echo "Realm join successful."
    else
      echo "Realm join failed. Please try again."
    fi
  done
}

# -------------------------------------------------------------------------------
# Function: configure_realm_permissions
# -------------------------------------------------------------------------------
configure_realm_permissions() {
  echo "Permitting domain user logins..."
  realm permit -g 'domain users@adws.udayton.edu'

  echo "Permitting administrative logins..."
  realm permit -g cas.role.administrators.casit.workstations@adws.udayton.edu
  echo "Realm permissions configured."
}

# -------------------------------------------------------------------------------
# Function: update_pam_configuration
# -------------------------------------------------------------------------------
update_pam_configuration() {
  echo "Updating PAM configuration to enable home directory creation..."
  pam-auth-update --enable mkhomedir
  echo "PAM configuration updated."
}

# -------------------------------------------------------------------------------
# Function: install_pip_and_gdown
# -------------------------------------------------------------------------------
install_pip_and_gdown() {
  echo "Installing python3-pip..."
  apt-get install -y python3-pip

  echo "Installing gdown via pip..."
  # Use python3 -m pip to ensure compatibility on both Ubuntu 20.04 and 22.04.
  python3 -m pip install gdown
}

# -------------------------------------------------------------------------------
# Function: download_and_install_falcon_sensor
# -------------------------------------------------------------------------------
download_and_install_falcon_sensor() {
  echo "Downloading Falcon Sensor..."
  # gdown downloads the file using its Google Drive file ID.
  gdown 1YnvSQmCgUE0lRs5Fauvfub_KsUhcnbCw

  echo "Installing Falcon Sensor..."
  dpkg --install falcon-sensor_6.38.0-13501_amd64.deb

  echo "Configuring Falcon Sensor..."
  /opt/CrowdStrike/falconctl -s --cid=0FA34C2A8A4545FC9D85E072AFBABA4A-E7

  echo "Starting Falcon Sensor service..."
  systemctl start falcon-sensor

  echo "Cleaning up installation file..."
  rm -f falcon-sensor_6.38.0-13501_amd64.deb
}

# -------------------------------------------------------------------------------
# Function: install_and_mount_cifs_share
# -------------------------------------------------------------------------------
install_and_mount_cifs_share() {
  echo "Installing cifs-utils..."
  apt-get install -y cifs-utils

  echo "Creating mount point /media/share..."
  mkdir -p /media/share

  local good=0
  while [[ $good -lt 1 ]]; do
    echo "Attempting to mount network share..."
    if mount -v -t cifs -o rw,vers=3.0,username="$username",password="$password" \
         //itsmldcs1.adws.udayton.edu/ldlogon/unix /media/share; then
      good=1
      echo "Network share mounted successfully."
    else
      echo "Mount failed; retrying in 5 seconds..."
      sleep 5
    fi
  done
}

# -------------------------------------------------------------------------------
# Function: download_and_configure_ivanti_agent
# -------------------------------------------------------------------------------
download_and_configure_ivanti_agent() {
  echo "Creating temporary directory /tmp/ems..."
  mkdir -p /tmp/ems

  echo "Navigating to /tmp/ems..."
  cd /tmp/ems

  echo "Copying nixconfig.sh from network share..."
  cp /media/share/nixconfig.sh /tmp/ems/nixconfig.sh

  echo "Setting execute permissions on nixconfig.sh..."
  chmod a+x /tmp/ems/nixconfig.sh

  echo "Enabling UFW firewall..."
  ufw enable

  echo "Opening required ports (22, 9593, 9594, 9595 TCP & UDP)..."
  ufw allow 22
  ufw allow 9593
  ufw allow 9594
  ufw allow 9595/tcp
  ufw allow 9595/udp
  echo "Firewall configuration complete."

  echo "Installing Ivanti Agent..."
  /tmp/ems/nixconfig.sh -p -a itsmldcs1.adws.udayton.edu -i all -k ea67f4cd.0
  echo "Ivanti Agent installation complete."
}

# -------------------------------------------------------------------------------
# Main function: Executes all steps in order.
# -------------------------------------------------------------------------------
main() {
  local FLAG_FILE="/root/.setup_complete"

  if [[ -f "$FLAG_FILE" ]]; then
    echo "Setup already completed. Exiting."
    exit 0
  fi

  setup_update_script
  add_cronjob
  update_sudoers
  install_realmd_and_join
  configure_realm_permissions
  update_pam_configuration
  install_pip_and_gdown
  download_and_install_falcon_sensor
  install_and_mount_cifs_share
  download_and_configure_ivanti_agent

  echo "All tasks completed successfully. Marking setup as complete."
  touch "$FLAG_FILE"

  echo "Rebooting now..."
  reboot now
}


# Execute the main routine.
main
