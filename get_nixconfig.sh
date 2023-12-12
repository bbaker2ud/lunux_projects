#!/bin/bash
echo "Installing cifs-utils..." &&
apt -y install cifs-utils &&
echo "Changing permissions..." &&
echo "Mounting network share..." &&
mkdir /media/share ||
good=0 &&
until [ $good -ge 1 ]; do
  mount -v -t cifs -o rw,vers=3.0,credentials=/etc/cifs-credentials //itsmldcs1.adws.udayton.edu/ldlogon/unix /media/share
	if [ $? -eq 0 ]; then
		good=1
		echo "success=$good"
	else
		echo "success=$good"
	fi
done
echo "Creating temporary directory..." &&
mkdir -p /tmp/ems &&
echo "Downloading nixconfig.sh..." &&
cp /media/share/nixconfig.sh /tmp/ems/nixconfig.sh &&
echo "Making nixconfig.sh exectutable..." &&
chmod a+x /tmp/ems/nixconfig.sh &&
echo "Installing Ivanti Agent..." &&
/tmp/ems/nixconfig.sh -p -a itsmldcs1.adws.udayton.edu -i all -k ea67f4cd.0 &&
echo "Done."
