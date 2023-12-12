#!/bin/bash
echo "Installing pip..." &&
apt -y install python3-pip &&
echo "Installing gdown..." &&
pip install gdown &&
echo "Downloading Falcon Sensor..." &&
gdown 1YnvSQmCgUE0lRs5Fauvfub_KsUhcnbCw &&
echo "Installing Falcon Sensor..." &&
dpkg --install falcon-sensor_6.38.0-13501_amd64.deb &&
rm falcon-sensor_6.38.0-13501_amd64.deb &&
/opt/CrowdStrike/falconctl -s --cid=0FA34C2A8A4545FC9D85E072AFBABA4A-E7 &&
systemctl start falcon-sensor
