#!/bin/bash
echo "Installing realmd..." &&
apt-get install realmd &&
echo "Discovering realm..." &&
realm discover adws.udayton.edu &&
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
echo "Done." 
