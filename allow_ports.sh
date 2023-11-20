#!/bin/bash 
echo "Enabling firewall..." &&
ufw enable &&
echo "Opening ports..." &&
ufw allow 22 &&
ufw allow 9593 && 
ufw allow 9594 && 
ufw allow 9595/tcp && 
ufw allow 9595/udp &&
echo "Done."
