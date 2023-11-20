#!/bin/bash/
echo "Fixing pam..." &&
pam-auth-update --enable mkhomedir &&
echo "Done."
