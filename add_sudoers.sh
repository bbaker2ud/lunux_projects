#!/bin/bash
echo "Adding sudoers..." &&
echo "%cas.role.administrators.casit.workstations@adws.udayton.edu ALL=(ALL) ALL" >> /etc/sudoers.d/admins &&
echo "landesk ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers &&
echo "Defaults:landesk !requiretty" >> /etc/sudoers &&
echo "Done."

