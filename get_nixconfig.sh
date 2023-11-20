#!/bin/bash
echo "Installing cifs-utils..." &&
apt-get install cifs-utils &&
echo "Creating creds..." &&
echo "username=bbaker2" >> /root/.creds &&
echo "password=2632newJob!" >> /root/.creds &&
echo "Changing permissions..." &&
chmod 400 /root/.creds &&
echo "Mounting network share..." &&
mkdir /media/share &&
mount -t cifs -o rw,vers=3.0,credentials=/root/.creds //itsmldcs1.adws.udayton.edu/ldlogon/unix /media/share &&
echo "Creating temporary directory..." &&
mkdir -p /tmp/ems &&
echo "Downloading nixconfig.sh..." &&
cp /media/share/nixconfig.sh /tmp/ems/nixconfig.sh &&
echo "Making nixconfig.sh exectutable..." &&
chmod a+x /tmp/ems/nixconfig.sh &&
echo "Installing Ivanti Agent..." &&
/tmp/ems/nixconfig.sh -p -a itsmldcs1.adws.udayton.edu -i all -k ea67f4cd.0 &&
echo "Done."
