#!/bin/bash
echo "Checking for updates..." &&
apt-get update && 
echo "Upgrading..." &&
apt-get -y dist-upgrade && 
echo "Removing unnecessary modules..." &&
apt-get -y autoremove &&
echo "Done."
