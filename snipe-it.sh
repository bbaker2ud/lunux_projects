#!/bin/bash
#permissions
sudo chown -R bbaker2@adws.udayton.edu:www-data /var/www/html/snipeit
sudo usermod -a -G www-data bbaker2@adws.udayton.edu
sudo find /var/www/html/snipeit -type f -exec chmod 664 {} \;
sudo chmod -R 775 /var/www/html/snipeit/storage
sudo chmod -R 775 /var/www/html/snipeit/public/uploads
sudo chmod -R 775 /var/www/html/snipeit/bootstrap/cache