#!/bin/bash

# this script is using one during installation to create /public_html and /domlogs folders and set access modes

# Set variables
. ~/config.inc.sh
export USER_NAME

# 1. user setup
sudo usermod -aG adm $USER_NAME
sudo usermod -aG $USER_NAME www-data
sudo mkdir -p ~/public_html
sudo mkdir -p ~/domlogs
sudo chown root:$USER_NAME ~/domlogs
sudo chown $USER_NAME:$USER_NAME ~/public_html
sudo chmod 0750 ~/public_html
sudo chmod 0750 ~/domlogs
sudo su $USER_NAME -c "echo 'export PATH=\$PATH:/usr/local/pgsql/bin' >> /home/$USER_NAME/.bashrc"

echo "modes setup finished"

# 2. turn off and remove apache
sudo systemctl stop apache2
sudo systemctl disable apache2

# 3. install nginx
sudo apt update
sudo apt install nginx
sudo ufw allow "Nginx Full"

#4. turn nginx on
sudo systemctl start nginx
sudo systemctl restart nginx

#5. init front-end of make profiler
profile_make_init_viewer -o=/home/$USER_NAME/public_html 

# create symbolic links for necessary files which should be exposed to web.
ln -s ~/geocint/report.json  ~/public_html/report.json
ln -s ~/geocint/make.svg  ~/public_html/make.svg
ln -s ~/geocint/logs  ~/public_html/logs

