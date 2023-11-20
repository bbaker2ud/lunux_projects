#!/bin/bash 
echo "Running allow_ports.sh..." &&
/root/scripts/allow_ports.sh &&
echo "Running get_nixconfig.sh" &&
/root/scripts/get_nixconfig.sh &&
echo "Done."