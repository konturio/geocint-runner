# Installing make-profiler
sudo apt install -y python3-pip graphviz gawk
sudo pip3 install slack slackclient
sudo pip3 install https://github.com/konturio/make-profiler/archive/master.zip
sudo pip3 install pandas
sudo apt-get -y install python3-boto3 python3-botocore # amazon.aws.aws_s3

# instaling GIS Utilities
sudo apt install osmium-tool
sudo apt-get install parallel pigz jq zip pbzip2
sudo apt-get install cmake
sudo apt-get install sqlite3 libsqlite3-dev libtiff-dev libcurl4-openssl-dev
sudo apt install golang-go

sudo apt-get install pspg

# Installing aria2 pyosmium (osm dump downloader)
sudo apt install aria2
sudo apt install pyosmium

# Installing pgrouting
sudo apt install unzip

# installing proj
sudo apt-get install proj-bin

# Install gdal
sudo apt-get install liblcms2-dev libtiff-dev libpng-dev libz-dev libjson-c-dev libpq-dev libgdal30 python3-gdal libgeotiff-dev liblz4-dev liblcms2-dev 
sudo apt-get install gdal-bin

# Installing Postgres
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql.service

## Create postgres user/group
groupadd -r postgres
useradd -r -g postgres --home-dir=/var/lib/postgresql --shell=/bin/bash postgres

# Installing PostGIS 3.2
sudo apt install -y autoconf libtool libpcre3-dev libxml2-dev libgeos-dev libprotobuf-c-dev protobuf-c-compiler xsltproc docbook-xsl libgdal-dev
pg_version="$(psql -V | cut -d " " -f 3 | cut -d "." -f 1)"
sudo apt install postgis postgresql-$pg_version-postgis-3
sudo apt-get install postgresql-$pg_version-postgis-3-scripts

# Installing pgxnclient
sudo apt install -y pgxnclient
## pgxn has to call pg_config, add PG pinaries to PATH
echo 'export PATH=$PATH:/usr/local/pgsql/bin' >> /root/.bashrc

# Installing H3
pgxn install h3

# gis user setup
usermod -aG adm gis
usermod -aG gis www-data
mkdir -p ~gis/{public_html,domlogs}
chown root:gis ~gis/domlogs
chown gis:gis ~gis/public_html
chmod 0750 ~gis/{public_html,domlogs}
su gis -c "echo 'export PATH=\$PATH:/usr/local/pgsql/bin' >> /home/gis/.bashrc"

psql -c "create extension postgis;"
psql -c "create extension postgis_raster;"
psql -c "create extension postgis_sfcgal;"
psql -c "create extension postgis_topology;"
psql -c "create extension h3;"
psql -c "create extension h3_postgis;"


# Ubuntu Postgres stuff
sudo apt install -y postgresql-common

## Reset locale variables in case they were modified
. /usr/share/postgresql-common/maintscripts-functions
set_system_locale

## Create cluster and systemd service
pg_createcluster $pg_version main 
# }}
## Comment out "states_temp_directory" parameter from config (not recognized by PG15)
sudo sed -i 's/stats_temp_directory/#stats_temp_directory/g' /etc/postgresql/$pg_version/main/postgresql.conf


