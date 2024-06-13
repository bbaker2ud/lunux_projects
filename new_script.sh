#!/bin/bash

# Update Package Lists
sudo apt-get update

# Upgrade Installed Packages
sudo apt-get dist-upgrade --yes

# Remove Unused Packages
sudo apt autoremove --yes

# Install Xorg and Openbox
sudo apt --yes install xorg xserver-xorg x11-xserver-utils xinit openbox

# Create Directory for getty Override
sudo mkdir /etc/systemd/system/getty@.service.d

# Download Override Configuration
sudo wget "https://raw.githubusercontent.com/bbaker2ud/lunux_projects/main/override.conf"

# Move Override Configuration into Place
sudo mv override.conf /etc/systemd/system/getty@.service.d/override.conf

# Disable Root Password Login
sudo passwd -d root

# Download Script
sudo wget "https://raw.githubusercontent.com/bbaker2ud/lunux_projects/main/script.sh"

# Make Script Executable
sudo chmod +x script.sh

# Move Script to Root Directory
sudo mv script.sh /root/script.sh

# Execute the Downloaded Script
sudo bash /root/script.sh 
