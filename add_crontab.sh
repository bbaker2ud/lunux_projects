#!/bin/bash
echo "Adding crontab..." &&
echo "0 0 1 * * /root/scripts/updates.sh" >> /var/spool/cron/crontabs/root &&
echo "Done."
