#!/bin/bash

# Set variables
. ~/config.inc.sh
export USER_NAME

# user setup
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
