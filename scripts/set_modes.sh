#!/bin/bash

# Set variables
. ~/config.inc.sh
export PGDATABASE

# user setup
sudo usermod -aG adm $PGDATABASE
sudo usermod -aG $PGDATABASE www-data
sudo mkdir -p ~$PGDATABASE/{public_html,domlogs}
sudo chown root:$PGDATABASE ~$PGDATABASE/domlogs
sudo chown $PGDATABASE:$PGDATABASE ~$PGDATABASE/public_html
sudo chmod 0750 ~$PGDATABASE/{public_html,domlogs}
sudo su $PGDATABASE -c "echo 'export PATH=\$PATH:/usr/local/pgsql/bin' >> /home/$PGDATABASE/.bashrc"

echo "modes setup finished"
