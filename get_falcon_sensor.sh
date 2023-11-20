#!/bin/bash
echo "Installing pip..." &&
apt -y install python3-pip &&
echo "Installing gdown..." &&
pip install gdown &&
echo "Downloading Falcon Sensor..." &&
gdown 1YnvSQmCgUE0lRs5Fauvfub_KsUhcnbCw &&
echo "Installing Falcon Sensor..." &&
dpkg --install falcon-sensor_6.38.0-13501_amd64.deb &&
rm falcon-sensor_6.38.0-13501_amd64.deb
