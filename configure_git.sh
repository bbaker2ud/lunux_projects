#!/bin/bash
echo "Please enter your UD username (USERNAME@adws.udayton.edu): " &&
read -p 'Username: ' username &&
echo "Please enter your UD email (USERNAME@udayton.edu): " &&
read -p 'email: ' email &&
sudo git config --global user.name "$username" &&
sudo git config --global user.email "$useremail" &&
sudo git config --list
