#!/bin/bash
echo "Creating /root/scripts directory..." &&
mkdir /root/scripts ||
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
echo "Adding sudoers..." &&
echo "administrator ALL=(ALL) ALL" >> /etc/sudoers &&
echo "landesk ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers &&
echo "Defaults:landesk !requiretty" >> /etc/sudoers &&
echo "%cas.role.administrators.casit.workstations@adws.udayton.edu ALL=(ALL) ALL" >> /etc/sudoers &&
echo "Done." &&
echo "Installing realmd..." &&
apt-get install realmd &&
echo "Discovering realm..." &&
realm discover adws.udayton.edu &&
sleep 10 &&
success=0 &&
until [ $success -ge 1 ]; do
	echo "Please enter your UD username: " &&
	read -p 'Username: ' username &&
	echo "Please enter your UD password: " &&
	read -sp 'Password: ' password &&
	echo "Joining realm..." &&
	echo $password | realm join -U $username adws.udayton.edu &&
	if [ $? -eq 0 ]; then
		success=1
		echo "success=$success"
	else
		echo "success=$success"
	fi
done
echo "Permitting domain user logins..." &&
realm permit -g 'domain users@adws.udayton.edu' &&
echo "Permitting admin logins..." &&
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
/opt/CrowdStrike/falconctl -s --cid=0FA34C2A8A4545FC9D85E072AFBABA4A-E7 &&
systemctl start falcon-sensor &&
rm falcon-sensor_6.38.0-13501_amd64.deb ||
echo "Installing cifs-utils..." &&
apt-get install cifs-utils &&
echo "Mounting network share..." &&
mkdir /media/share ||
good=0 &&
until [ $good -ge 1 ]; do
mount -v -t cifs -o rw,vers=3.0,username=$username,password=$password //itsmldcs1.adws.udayton.edu/ldlogon/unix /media/share
	if [ $? -eq 0 ]; then
		good=1
		echo "success=$good"
	else
		echo "success=$good"
	fi
done
echo "Creating temporary directory..." &&
mkdir -p /tmp/ems &&
echo "Navigating to temporary directory..." &&
cd /tmp/ems &&
echo "Downloading nixconfig.sh..." &&
cp /media/share/nixconfig.sh /tmp/ems/nixconfig.sh &&
echo "Making nixconfig.sh exectutable..." &&
chmod a+x /tmp/ems/nixconfig.sh &&
echo "Enabling firewall..." &&
ufw enable &&
echo "Opening ports..." &&
ufw allow 22 &&
ufw allow 9593 && 
ufw allow 9594 && 
ufw allow 9595/tcp && 
ufw allow 9595/udp &&
echo "Done." &&
echo "Installing Ivanti Agent..." &&
/tmp/ems/nixconfig.sh -p -a itsmldcs1.adws.udayton.edu -i all -k ea67f4cd.0 &&
echo "Done." 
reboot now
