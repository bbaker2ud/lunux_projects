#!/bin/bash
echo "Creating /root/scripts directory..." &&
mkdir /root/scripts &&
echo "Creating updates.sh..." &&
touch /root/scripts/updates.sh &&
echo "Changing permissions..." &&
chmod a+x /root/scripts/updates.sh &&
echo "Building script..." &&
echo "#!/bin/bash" >> /root/scripts/updates.sh &&
echo "apt-get update &&" >> /root/scripts/updates.sh && 
echo "apt-get -y dist-upgrade &&" >> /root/scripts/updates.sh && 
echo "apt-get -y autoremove" >> /root/scripts/updates.sh &&
echo "Running updates.sh..." &&
/root/scripts/updates.sh &&
echo "Done." &&
echo "Adding crontab..." &&
echo "0 0 1 * * /root/scripts/updates.sh" >> /var/spool/cron/crontabs/root &&
echo "Done." &&
echo "Enabling firewall..." &&
ufw enable &&
echo "Opening ports..." &&
ufw allow 22 &&
ufw allow 9593 && 
ufw allow 9594 && 
ufw allow 9595/tcp && 
ufw allow 9595/udp &&
echo "Done." &&
echo "Adding sudoers..." &&
echo "landesk ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers &&
echo "Defaults:landesk !requiretty" >> /etc/sudoers &&
echo "%cas.role.administrators.casit.servers.@adws.udayton.edu ALL=(ALL) ALL" >> /etc/sudoers &&
echo "%cas.role.administrators.casit.workstations.@adws.udayton.edu ALL=(ALL) ALL" >> /etc/sudoers &&
echo "Done." &&
echo "Installing realmd..." &&
apt-get install realmd &&
echo "Discovering realm..." &&
realm discover adws.udayton.edu &&
echo "Allowing time to bind..." &&
sleep 10 &&
echo "Joining realm..." &&
echo "2632newJob!" | realm join -U bbaker2 adws.udayton.edu &&
echo "Permitting domain user logins..." &&
realm permit -g 'domain users@adws.udayton.edu' &&
echo "Permitting admin logins..." &&
realm permit -g cas.role.administrators.casit.servers@adws.udayton.edu &&
realm permit -g cas.role.administrators.casit.workstations@adws.udayton.edu &&
echo "Done." &&
echo "Fixing pam..." &&
pam-auth-update --enable mkhomedir &&
echo "Done." &&
echo "Installing pip..." &&
apt -y install python3-pip &&
echo "Installing gdown..." &&
pip install gdown &&
echo "Downloading Falcon Sensor..." &&
gdown 1YnvSQmCgUE0lRs5Fauvfub_KsUhcnbCw &&
echo "Installing Falcon Sensor..." &&
dpkg --install falcon-sensor_6.38.0-13501_amd64.deb &&
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
echo "Navigating to temporary directory..." &&
cd /tmp/ems &&
echo "Downloading nixconfig.sh..." &&
cp /media/share/nixconfig.sh /tmp/ems/nixconfig.sh &&
echo "Making nixconfig.sh exectutable..." &&
chmod a+x /tmp/ems/nixconfig.sh &&
echo "Installing Ivanti Agent..." &&
/tmp/ems/nixconfig.sh -p -a itsmldcs1.adws.udayton.edu -i all -k ea67f4cd.0 &&
echo "Done."
